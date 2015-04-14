require 'timeout'

module Helpers
  module System

    @@calls = nil

    def self.count_calls!
      @@calls = []
    end

    def self.calls
      @@calls
    end

    @@mock = false
    @@mock_data = {}
    def self.mock!
      @@mock = true
    end
    def self.mock_data; @@mock_data; end

    def exec(cmd)
      @@calls << cmd if @@calls
      if @@mock then
        key = @@mock_data.keys.find do |k|
          if k.is_a?(Regexp) then
            cmd =~ k
          else
            cmd.include?(k.to_s)
          end
        end
        return [@@mock_data[key].pop,0]  if @@mock_data[key].is_a?(Array) and @@mock_data[key].any?
        return [@@mock_data[key],0]  if @@mock_data[key] # simple mock_data
        return ['',0]
      end
      res = `#{cmd}`
      [res, $?.exitstatus]
    end

    # Wait for the given block to return something evaluable to true.
    # Returns whatever the block returned
    #
    #  wait_for :timeout => 2, :step => 0.1 do
    #    is_my_service_up?
    #  end
    #
    def wait_for(opts = {})
      timeout = opts[:timeout] || 30
      step_secs = opts[:step] || 1
      expire = Time.now + timeout

      while not res = yield
        raise Timeout::Error if Time.now > expire
        sleep step_secs
      end
      res
    end

  end

  extend System
end

H = Helpers if not defined? H
