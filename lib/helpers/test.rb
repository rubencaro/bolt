require_relative 'log'

module Helpers
  module Test

    # Collect interesting metadata from helpers
    #
    # Don't worry about having everything here.
    # When you miss some, then you'll add it.
    #
    def self.get_metadata
      m = {}
      m[:system] = { :calls => H::System.calls } if defined?(H::System)
      m[:net] = { :calls => H::Net.calls } if defined?(H::Net)
      m[:email] = { :calls => Bolt::Helpers::Email.calls } if defined?(Bolt::Helpers::Email)
      m
    rescue => ex
      H.log_ex ex
      nil
    end

  end
end
