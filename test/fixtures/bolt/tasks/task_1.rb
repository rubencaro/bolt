MYTASK = 'Task 1'
NUMBER = 1
module Bolt::Tasks
  module Task1
    def self.run(task)
      puts "task: task_#{NUMBER}, MYCONST = #{MYTASK}"
    end
  end
end
