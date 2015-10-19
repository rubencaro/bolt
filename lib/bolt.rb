#!/usr/bin/env ruby
CURRENT_ENV = ENV['CURRENT_ENV'] || 'development' if not defined? CURRENT_ENV

$:.unshift '.','lib'
require 'rubygems'
require 'bundler/setup'

require 'config/bolt' # bolt config for the app

require 'helpers/log'
require 'helpers/process'
require 'helpers/string'
require 'helpers/path'
require 'helpers/system'
require 'json'
require 'thread'

require_relative 'bolt/helpers'
require_relative 'bolt/email'

=begin

Bolt is a modern runner. Bye Forrest, we'll miss you.

It looks for a task waiting on a local mongo queue.

Tasks dispatching status is controlled via a boolean `dispatched` field.

A timeout in seconds is configurable for each task by putting an integer
`timeout` field in the task itself. By default is 300.

To run an actual number of tasks you should set `tasks_count` > 0. That expects
to actually have that number of tasks in the queue, and exits when they are
processed.

When `tasks_count` is set, the piper process has a timeout of 5 secs,
configurable with `piper_timeout`.

The folder that contains the actual tasks code can be configured in
`tasks_folder`. Bolt will execute `require "#{tasks_folder}/#{task}"`, where
`task` is the task field in the task itself. By default is 'bolt/tasks'.

=end

module Bolt

  @@db = "bolt_#{CURRENT_ENV}"
  @@queue = 'task_queue'
  @@throttle = 5

  def self.db; @@db; end
  def self.queue; @@queue; end
  def self.throttle; @@throttle; end
  def self.throttle=(value); @@throttle = value; end

  module Tasks # placeholder
  end

  class NotExpectedNumberOfTasks < StandardError; end
  class PeriodZero < StandardError; end

  # Wait for tasks on queue and dispatch them to processes
  #
  # If you pass a `tasks_count` Bolt will run only that many tasks. Also it will
  # raise NotExpectedNumberOfTasks if there are less than `tasks_count` runnable
  # tasks on queue in less than `tasks_wait` seconds. After running
  # `tasks_count` tasks, it will exit. Default is -1 (disabled).
  #
  # If you pass a `rounds` then it will perform that number of rounds starting
  # `tasks_count` tasks on each loop. Default is 1. `round_sleep` sleep is done
  # between rounds. It will wait for tasks to end only after dispatching all
  # rounds.
  #
  # If you pass a `throttle` then it will try not to have more than `throttle`
  # alive tasks at any given time. Default is 5.
  #
  def self.dispatch_loop(db: @@db,
                         queue: @@queue,
                         tasks_count: -1,
                         tasks_wait: 0,
                         rounds: 1,
                         round_sleep: 0.01,
                         tasks_folder: 'bolt/tasks',
                         piper_timeout: 5,
                         throttle: @@throttle)

    @@db = db
    @@queue = queue
    @@throttle = throttle
    total_tasks_count = tasks_count * rounds

    coll = Bolt::Helpers.get_mongo_collection
    # ensure expiration TTL index is there
    coll.ensure_index 'expire', :expireAfterSeconds => 0
    pids = []

    # party stoppers
    m = Module.new do
      def self.file_modified(file, opts = {})
        H.log "Suiciding now (from #{File.basename file})..."
        H.killall opts[:pids]
        exit 0
      end
    end

    H.watch_file(Dir.pwd + "/tmp/kill.flagella", m)
    H.watch_file(Dir.pwd + "/tmp/kill.bolt", m)

    H.exec "touch ~/flagella/bolt/pids/#{Process.pid}"

    # load recycled_tasks
    recycled_tasks = coll.find({ '$and' => [
                                  {'dispatched' => { '$exists' => true }},
                                  {'finished' => { '$exists' => false }}
                                ] }).sort('_id').to_a

    # main pipe to communicate with children
    main_read, main_write = IO.pipe

    # main thread to read from pipe
    piper = Thread.new do
      piper_coll = Bolt::Helpers.get_mongo_collection # not thread-safe
      start_time = Time.now
      i = 0
      loop do
        # perform gets inside a timeout, break if times out
        ended_task = JSON.parse(main_read.gets)
        ended_task['_id'] = BSON::ObjectId.from_string ended_task['_id']['$oid']

        # save task if asked, all metadata is there
        Bolt::Helpers.tasks << ended_task if Bolt::Helpers.tasks

        Bolt::Helpers.notify :task => ended_task

        # remove only if not asked to persist
        if ended_task['persist'] or ended_task['period'] then
          piper_coll.update({'_id' => ended_task['_id']}, ended_task )
        else
          H.log "Removing #{ended_task}"
          # BSON::ObjectId through JSON gets into ['$oid']
          piper_coll.remove '_id' => ended_task['_id']
        end

        i += 1
        break if tasks_count > 0 and
                  ( i >= total_tasks_count or
                    (Time.now - start_time) > piper_timeout )
      end
    end

    # main loop dispatching tasks
    r = 0
    loop do
      dispatch_tasks :coll => coll,
                     :pids => pids,
                     :main_write => main_write,
                     :recycled_tasks => recycled_tasks,
                     :tasks_count => tasks_count,
                     :tasks_folder => tasks_folder,
                     :timeline => Time.now + tasks_wait

      recycled_tasks = [] # clean recycled_tasks

      r += 1
      if tasks_count > 0 then
        if r >= rounds then # wait and end
          pids.each{|pid| Process.wait pid}
          piper.join
          break # out of the loop
        end
        sleep round_sleep
        H.log "Going for the next round !"
        next # next round
      end

      # infinite loop
      sleep 5

      H.exec "touch ~/flagella/timestamps/bolt__60__300"
      H.check_watched_files :pids => pids
    end

  rescue => ex
    H.log_ex ex
    raise ex # everything is broken already, no problem on making further noise
  ensure
    H.killall pids
    piper.kill if piper
    main_read.close if main_read
    main_write.close if main_write
  end

  def self.get_tasks(opts)

    # limiting the number of tasks using configured throttle
    slice = Bolt.throttle - opts[:pids].count - opts[:recycled_tasks].count

    tasks = []
    if slice > 0 then
      # uf que horror los queries de mongodb
      query = { '$and' => [ { 'dispatched' => { '$exists' => false } },
                            { '$or'  => [ { 'run_at' => { '$exists' => false } },
                                          { '$and' => [ { 'run_at' => { '$exists' => true } },
                                                        { 'run_at' => { '$lte' => Time.now.to_i } } ] } ] } ] }
      tasks = opts[:coll].find(query).limit(slice).sort('_id').to_a
    end

    # add recycled_tasks to task list
    tasks += opts[:recycled_tasks]

    tasks
  end

  def self.dispatch_tasks(opts)
    defaults = {}
    opts = defaults.merge(opts)

    tasks = get_tasks opts

    if opts[:tasks_count] > 0 then
      # wait for all expected tasks to be ready to start
      H.log "Waiting for tasks to be ready..."
      while tasks.count < opts[:tasks_count] and Time.now <= opts[:timeline]
        sleep 0.1
        tasks = get_tasks opts
      end

      tasks = tasks[0..opts[:tasks_count]-1] # take only tasks_count

      if tasks.count < opts[:tasks_count] then # exactly that number
        raise Bolt::NotExpectedNumberOfTasks.new("Not enough tasks on the queue."+
                                                " There should be #{opts[:tasks_count]}."+
                                                " There are #{tasks.count}.")
      end
    end

    new_pids = H.dispatch_in_processes(tasks) do |task|
      if task['period'] then
        dispatch_periodic_task task, opts
      else
        dispatch_regular_task task, opts
      end
    end

    # add to the existing one, do not create a new one
    opts[:pids].concat new_pids

    # mark all tasks as dispatched
    tids = tasks.map{|t| t['_id']}
    opts[:coll].update({'_id' => { '$in' => tids }},
                       { '$set' => {'dispatched' => true} },
                       { :multi => true })

    # clean not-alive threads
    opts[:pids].reject!{|pid| not H.is_alive?(pid)}
  end

  def self.dispatch_regular_task(task, opts)
    begin
      H.log "Starting race for '#{task['task']}'... On your marks, ready, go!"

      default_timeout = 300.0
      default_timeout = 2.0 if CURRENT_ENV == 'test'
      task['timeout'] ||= default_timeout
      task['dispatched'] = true # in case someone writes the entire doc
      Timeout.timeout( task['timeout'].to_f ) do
        begin
          task['_id'] = BSON::ObjectId.from_string task['_id']['$oid']

          # the task must be a ruby script in `bolt/tasks/#{task['task']}`
          # it must define a global `run` method that will receive the task
          # hash as argument

          require "#{opts[:tasks_folder]}/#{task['task']}"
          # run is defined in the task file
          Bolt::Tasks.const_get(task['task'].camelize).run :task => task

          task['success'] = true

          H.log "Bolt wins the race for '#{task['task']}'!"
        rescue Exception => ex
          H.log_ex ex, :msg => "False start for '#{task['task']}'"
          task['success'] = false
          task['ex'] = ex
          task['backtrace'] = ex.backtrace
        end
      end

    rescue Timeout::Error => ex # only timeout errors, right?
      H.log_ex ex, :msg => "Too slow for Bolt '#{task['task']}'"
      task['success'] = false
      task['ex'] = ex
      task['backtrace'] = ex.backtrace
      Bolt::Helpers.notify :task => task
    ensure
      task['finished'] = true
      task[:test_metadata] = H::Test.get_metadata if CURRENT_ENV == 'test'
      opts[:main_write].puts task.to_json
      exit! true # avoid fire at_exit hooks inherited from parent!
    end
  end


  def self.dispatch_periodic_task(task, opts)
    begin
      H.log "Processing periodic task '#{task['task']}'..."+
          " Placing it in season calendar."

      default_timeout = 300.0
      default_timeout = 2.0 if CURRENT_ENV == 'test'
      task['timeout'] ||= default_timeout
      Timeout.timeout( task['timeout'].to_f ) do
        begin
          task['_id'] = BSON::ObjectId.from_string task['_id']['$oid']

          # a periodic task simply schedules a regular task using its data
          unwanted = ['_id','period','dispatched']
          regular = task.reject{|k,v| unwanted.include?(k)}
          Bolt::Helpers.schedule regular

          # and updates its own `run_at` using its `period` and `period_type`
          apply_period(task)

          task['success'] = true

          H.log "Periodic '#{task['task']}(#{task['period']})'"+
              " got its place in season calendar."
        rescue Exception => ex
          H.log_ex ex, :msg => "False start for periodic '#{task['task']}'"
          task['success'] = false
          task['ex'] = ex
          task['backtrace'] = ex.backtrace
        end
      end

    rescue Timeout::Error => ex # only timeout errors, right?
      H.log_ex ex, :msg => "Too slow for Bolt periodic '#{task['task']}'"
      task['success'] = false
      task['ex'] = ex
      task['backtrace'] = ex.backtrace
      Bolt::Helpers.notify :task => task
    ensure
      task['finished'] = false # periodic!
      task[:test_metadata] = H::Test.get_metadata if CURRENT_ENV == 'test'
      opts[:main_write].puts task.to_json
      exit! true # avoid fire at_exit hooks inherited from parent!
    end
  end

  # Apply configured period to a given periodic task
  #
  # Raises `PeriodZero` if period.to_i is not applicable
  # If `run_at` is not set, `Time.now` is used
  #
  def self.apply_period(task)

    task['run_at'] ||= Time.now.to_i
    dt = Time.at(task['run_at']).to_datetime

    case task['period']
    when 'every_given_hour' then
      task['run_at'] = (dt + 1).to_time.to_i
    when 'every_given_day' then
      task['run_at'] = (dt >> 1).to_time.to_i
    else # default seconds' type
      period = task['period'].to_i
      raise Bolt::PeriodZero if period <= 0
      task['run_at'] += period
    end
  end

end

if __FILE__ == $0 then
  Bolt.dispatch_loop
end
