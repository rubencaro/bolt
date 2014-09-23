module Bolt::Tasks
  module Timeout
    def self.run(args)
      sleep(args[:task]['timeout'].to_f + 0.01)
    end
  end
end
