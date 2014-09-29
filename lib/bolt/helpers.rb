require 'mongo'

module Bolt
  module Helpers

    def self.get_mongo_collection
      Mongo::MongoClient.new.db(Bolt.db)[Bolt.queue]
    end

    @@tasks = nil
    def self.tasks; @@tasks; end
    def self.save_tasks!; @@tasks = []; end

  end
end
