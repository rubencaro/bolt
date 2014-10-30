require 'helpers/generic'

module Bolt::Tasks
  module Composite
    def self.run(args)
      bh = Bolt::Helpers # namespaces are good

      # schedule tasks
      idA = bh.schedule_subtask :task => 'subtask',
                                :data => 'heyA',
                                :fail => args[:task]['fail']
      idB = bh.schedule_subtask :task => 'subtask',
                                :data => 'heyB',
                                :fail => args[:task]['fail']

      # wait for tasks
      taskA = bh.wait_for(idA, :step => 0.01)[:task]
      taskB = bh.wait_for(idB, :step => 0.01)[:task]

      # put results on the success email
      res = ''
      [taskA,taskB].each do |t|
        res += if t['success'] then
          t['results'].to_s
        else
          t['ex'].to_s
        end
      end

      args[:task].set! 'opts','email','success','body', res
    ensure
      bh.remove idA if idA
      bh.remove idB if idB
    end
  end
end
