MYTASK = 'Task 3'
NUMBER = 3
module Bolt::Tasks
  module Task3
    def self.run(task)
      puts "task: task_#{NUMBER}, MYCONST = #{MYTASK}"
    end
  end
end
