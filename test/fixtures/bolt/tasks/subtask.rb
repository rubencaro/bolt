
module Bolt::Tasks
  module Subtask
    def self.run(args)
      raise "failing from #{args[:task]['data']}!" if args[:task]['fail']
      args[:task]['results'] = { :everything => "fine from #{args[:task]['data']}" }
    end
  end
end
