MYTASK = 'Task 2'
NUMBER = 2
module Bolt::Tasks
  module Task2
    def self.run(task)
      puts "task: task_#{NUMBER}, MYCONST = #{MYTASK}"
    end
  end
end
