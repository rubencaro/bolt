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

  def self.db; @@db; end
  def self.queue; @@queue; end

  module Tasks # placeholder
  end

  class NotEnoughTasks < StandardError; end

  # Wait for tasks on queue and dispatch them to processes
  #
  # If you pass a `tasks_count` Bolt will run only that many tasks. Also it will
  # raise NotEnoughTasks if there are less than `tasks_count` runnable tasks on
  # queue. After running `tasks_count` tasks, it will exit.
  #
  #
  def self.dispatch_loop(db: @@db,
                         queue: @@queue,
                         tasks_count: -1,
                         tasks_folder: 'bolt/tasks',
                         piper_timeout: 5)

    @@db = db
    @@queue = queue

    coll = Bolt::Helpers.get_mongo_collection
    pids = []

    # party stoppers
    m = Module.new do
      def self.file_modified(file)
        H.log "Suiciding now (from #{File.basename file})..."
        exit 0
      end
    end

    H.watch_file(Dir.pwd + "/tmp/kill.flagella", m)
    H.watch_file(Dir.pwd + "/tmp/kill.bolt", m)

    H.exec "touch ~/flagella/bolt/pids/#{Process.pid}"

    # load recycled_tasks
    recycled_tasks = coll.find({ 'dispatched' => { '$exists' => true } }).to_a

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

        # save task if asked, all metadata is there
        Bolt::Helpers.tasks << ended_task if Bolt::Helpers.tasks

        if ended_task['success'] then
          Bolt::Email.success :task => ended_task
        else
          Bolt::Email.failure :task => ended_task
        end

        # by now, only clean the queue

        # BSON::ObjectId through JSON gets into ['$oid']
        removed = piper_coll.remove(
                        '_id' => BSON::ObjectId(ended_task['_id']['$oid']) )
        i += 1
        break if tasks_count > 0 and
                  ( i >= tasks_count or
                    (Time.now - start_time) > piper_timeout )
      end
    end

    # main loop dispatching tasks
    loop do
      dispatch_tasks :coll => coll,
                     :pids => pids,
                     :main_write => main_write,
                     :recycled_tasks => recycled_tasks,
                     :tasks_count => tasks_count,
                     :tasks_folder => tasks_folder

      recycled_tasks = [] # clean recycled_tasks

      if tasks_count > 0 then # wait and end
        pids.each{|pid| Process.wait pid}
        piper.join
        break
      else # infinite loop
        sleep 5
      end

      H.exec "touch ~/flagella/timestamps/bolt__60__300"
      H.check_watched_files
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

  def self.dispatch_tasks(opts)
    defaults = {}
    opts = defaults.merge(opts)

    # uf que horror los queries de mongodb
    query = { '$and' => [ { 'dispatched' => { '$exists' => false } },
                          { '$or'  => [ { 'run_at' => { '$exists' => false } },
                                        { '$and' => [ { 'run_at' => { '$exists' => true } },
                                                      { 'run_at' => { '$lte' => Time.now.to_i } } ] } ] } ] }
    tasks = opts[:coll].find(query).to_a
    # add recycled_tasks to task list
    tasks += opts[:recycled_tasks]

    if opts[:tasks_count] > 0 then
      tasks = tasks[0..opts[:tasks_count]-1] # take only tasks_count
      if tasks.count < opts[:tasks_count] then # exactly that number
        raise Bolt::NotEnoughTasks.new("Not enough tasks on the queue. There should be #{opts[:tasks_count]}. There are #{tasks.count}.")
      end
    end

    opts[:pids] += H.dispatch_in_processes(tasks) do |task|
      begin
        H.log "Starting race for '#{task['task']}'... On your marks, ready, go!"

        default_timeout = 300.0
        default_timeout = 2.0 if CURRENT_ENV == 'test'
        task['timeout'] ||= default_timeout
        Timeout.timeout( task['timeout'].to_f ) do
          begin

            # the task must be a ruby script in `bolt/tasks/#{task['task']}`
            # it must define a global `run` method that will receive the task
            # hash as argument

            require "#{opts[:tasks_folder]}/#{task['task']}"
            # run is defined in the task file
            task['_id'] = BSON::ObjectId.from_string task['_id']['$oid']
            Bolt::Tasks.const_get(task['task'].camelize).run :task => task

            task[:success] = true

            H.log "Bolt wins the race for '#{task['task']}'!"
          rescue Exception => ex
            H.log_ex ex, :msg => "False start for '#{task['task']}'"
            task[:success] = false
            task[:ex] = ex
            task[:backtrace] = ex.backtrace
          end
        end

      rescue Timeout::Error => ex # only timeout errors, right?
        H.log_ex ex, :msg => "Too slow for Bolt '#{task['task']}'"
        task[:success] = false
        task[:ex] = ex
        task[:backtrace] = ex.backtrace
        Bolt::Email.failure :task => task, :ex => ex
      ensure
        task[:test_metadata] = H::Test.get_metadata if CURRENT_ENV == 'test'
        opts[:main_write].puts task.to_json
        exit! true # avoid fire at_exit hooks inherited from parent!
      end
    end

    # mark all tasks as dispatched
    tids = tasks.map{|t| t['_id']}
    opts[:coll].update({'_id' => { '$in' => tids }},
                       { '$set' => {'dispatched' => true} },
                       { 'multi' => true })

    # clean already dead threads
    opts[:pids].reject!{|pid| not File.exist?("/proc/#{pid}")}
  end



end

if __FILE__ == $0 then
  Bolt.dispatch_loop
end
