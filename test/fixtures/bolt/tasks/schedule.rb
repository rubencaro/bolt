module Bolt::Tasks
  module Schedule
    def self.run(args)
      time_at = args[:task]['run_at']
      time = Time.at(args[:task]['run_at'])
      H.log "Task scheduled for #{time_at} (#{time}) running!"
    end
  end
end
