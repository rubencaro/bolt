require 'helpers/generic'

module Bolt::Tasks
  module Composite
    def self.run(task)
      bh = Bolt::Helpers # namespaces are good

      # schedule tasks
      idA = bh.schedule_subtask :task => 'subtask', :data => 'heyA'
      idB = bh.schedule_subtask :task => 'subtask', :data => 'heyB'

      # wait for tasks
      taskA = bh.wait_for idA, :step => 0.01

      taskB = bh.wait_for idB, :step => 0.01

      # put results on the success email
      res = taskA['results'].to_s + taskB['results'].to_s
      task.set! 'opts','email','success','body', res
    ensure
      bh.remove idA if idA
      bh.remove idB if idB
    end
  end
end
