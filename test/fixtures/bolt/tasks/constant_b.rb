MYCONST = 'B'
module Bolt::Tasks
  module ConstantB
    def self.run(task)
      puts "task: ConstantB, MYCONST = #{MYCONST}"
    end
  end
end
