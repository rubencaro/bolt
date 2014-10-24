require 'mongo'
require 'helpers/system'

module Bolt
  module Helpers

    # Returns a plain mongo collection object for Bolt's db and queue.
    #
    def self.get_mongo_collection
      Mongo::MongoClient.new.db(Bolt.db)[Bolt.queue]
    end

    # Manage in-memory task saving, meant for testing
    #
    @@tasks = nil
    def self.tasks; @@tasks; end
    def self.save_tasks!; @@tasks = []; end
    def self.no_save_tasks!; @@tasks = nil; end

    # Insert given task to the task queue. Returns its ID.
    # If an array of tasks is given, an array of IDs is returned.
    #
    def self.schedule(task)
      get_mongo_collection.insert task
    end

    # Insert given task to the task queue, adding some params making that task
    # behave as a subtask. Returns its ID.
    #
    def self.schedule_subtask(data)
      opts = { :persist => true,     # don't remove the task once it's done
               :expire => Time.now + 3600,  # remove after 1 hour, just in case this crashes
               :silent => true }     # don't send notifications
      schedule data.merge(opts)
    end

    # Wait for given task's ID to finish. Raise Timeout::Error if it doesn't.
    # You can give custom `timeout` and `step` in seconds.
    # Returns the task fresh from DB.
    #
    def self.wait_for(id, opts = {})
      timeout = opts[:timeout] || 300
      step = opts[:step] || 5
      taskA = nil
      coll = get_mongo_collection
      H.wait_for :timeout => timeout, :step => step do
        taskA = coll.find_one '_id' => id
        taskA['finished']  # true when done
      end
      taskA
    end

    # Remove given task's ID from the queue.
    #
    def self.remove(id)
      coll = get_mongo_collection
      coll.remove( '_id' => id )
    end

  end
end
