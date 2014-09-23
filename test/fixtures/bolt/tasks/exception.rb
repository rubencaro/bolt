module Bolt::Tasks
  module Exception
    def self.run(args)
      raise 'something bad happened'
    end
  end
end
