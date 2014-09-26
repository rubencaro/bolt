require 'mongo'

module Bolt
  module Helpers

    def self.get_mongo_collection
      Mongo::MongoClient.new.db(Bolt.db)[Bolt.queue]
    end

  end
end
