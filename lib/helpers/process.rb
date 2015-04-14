require 'json'
require_relative 'system'

module Helpers
  module Processing

    # Pass each item of the array to given block on separate processes.
    # Return the pids array.
    # Items in the array must be JSON serializable !
    #
    def dispatch_in_processes(array, &block)
      pids = []
      array.each do |i|
        r,w=IO.pipe # open pipe
        pids << fork do
          args = JSON.parse(r.gets) # get from pipe
          block.call args
        end
        w.puts i.to_json # send through pipe
      end
      return pids
    end

    # Pass each item of the array to given block on separate processes.
    # Then wait for them to finish a maximum of `timeout_secs` (default 30).
    # If waited `timeout_secs` or more, then raise `Timeout::Error`
    #
    def in_processes(array, opts={}, &block)
      timeout_secs = opts[:timeout_secs] || 30
      expires = Time.now + timeout_secs

      pids = dispatch_in_processes array, &block

      while pids.any?{|pid| File.exist? "/proc/#{pid}"}
        raise(Timeout::Error, "Timeout in_processes, waited #{timeout_secs}secs. #{opts[:msg].to_s}") if timeout_secs > 0 and Time.now > expires
        sleep 1
      end
    ensure # kill any remaining processes
      killall pids
    end

    # Pass opts to given block on separate processes.
    # Then wait for it to finish a maximum of `timeout_secs` (default 30).
    # If waited `timeout_secs` or more, then raise `Timeout::Error`
    #
    def in_process(opts={}, &block)
      timeout_secs = opts[:timeout_secs] || 30
      expires = Time.now + timeout_secs

      pid = fork do
        block.call opts
      end

      while File.exist?("/proc/#{pid}")
        raise(Timeout::Error, "Timeout in_process, waited #{timeout_secs}secs. #{opts[:msg].to_s}") if timeout_secs > 0 and Time.now > expires
        sleep 1
      end
    ensure
      killall [pid]
    end

    # a process watching a process
    # set :rescue_lambda to a lambda if you want to manage exceptions from child process
    #
    def supervise_process(opts = {}, &block)
      fork do
        begin
          in_process opts, &block
        rescue => ex
          H.log_ex ex, :msg => "opts:#{opts}"
          if opts[:rescue_lambda] then
            ex2 = StandardError.new("Supervising process. opts:#{opts} \n\n ex: #{ex}")
            ex2.set_backtrace(ex.backtrace)
            opts[:rescue_lambda].call ex2
          end
        end
      end
    end

    def killall(pids)
      pids.each do |pid|
        begin
          Process.kill('KILL',pid)
        rescue
        end
      end
    end

    # Not the same as is_alive !!
    #
    def is_not_dead?(pid)
      File.exist?("/proc/#{pid}")
    end

    # A pure not-dead
    #
    def is_zombie?(pid)
      return false unless is_not_dead?(pid)
      H.exec("cat /proc/#{pid}/status | grep State").to_s =~ /zombie/
    end

    # Really alive is not only not-dead
    #
    def is_alive?(pid)
      is_not_dead?(pid) and not is_zombie?(pid)
    end

  end

  extend Processing
end

H = Helpers if not defined? H
