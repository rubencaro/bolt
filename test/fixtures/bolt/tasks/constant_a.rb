MYCONST = 'A'
module Bolt::Tasks
  module ConstantA
    def self.run(task)
      puts "task: ConstantA, MYCONST = #{MYCONST}"
    end
  end
end
