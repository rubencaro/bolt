require 'mongo'
require 'helpers/system'
require 'helpers/log'

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
      H.log "Scheduling #{task}"
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

    # Wait for given task's ID to finish.
    # You can give custom `timeout` and `step` in seconds.
    # Returns the task fresh from DB. Returns nil if it doesn't finish on time.
    #
    def self.wait_for(id, opts = {})
      timeout = opts[:timeout] || 300
      step = opts[:step] || 5
      coll = get_mongo_collection
      task = coll.find_one '_id' => id
      H.log "Waiting for #{task}..."
      H.wait_for :timeout => timeout, :step => step do
        task = coll.find_one '_id' => id
        if task then
          task['finished']  # true when done
        else
          false
        end
      end
      task
    rescue Exception => ex
      H.log_ex ex
      nil
    end

    # Remove given task's ID from the queue.
    #
    def self.remove(id)
      coll = get_mongo_collection
      coll.remove( '_id' => id )
    end

    # Perform suited notification for this task
    #
    def self.notify(opts)
      t = opts[:task]

      # notify via email when not silent, or when failing and not persisting
      if not t['silent'] or
          (not t['success'] and not t['persist']) then
        return notify_via_email opts
      end

      # save notifications in the task
      t['notifications'] = notify_via_hash opts
      coll = get_mongo_collection

      # save the task with everything it has collected until now
      coll.update({'_id' => t['_id']}, t)
    end

    # Perform email notification for this task
    #
    def self.notify_via_email(opts)
      if opts[:task]['success'] then
        Bolt::Email.success opts
      else
        Bolt::Email.failure opts
      end
    end

    # Get a hash with notification data for this task
    #
    def self.notify_via_hash(opts)
      {}  # nothing to say, by now
    end

  end
end
