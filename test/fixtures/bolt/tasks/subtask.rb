
module Bolt::Tasks
  module Subtask
    def self.run(task)
      task['results'] = { :everything => "fine from #{task['data']}" }
    end
  end
end
