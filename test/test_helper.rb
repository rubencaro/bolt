 # -*- coding:utf-8 -*-
$:.unshift '.','lib'
require 'bundler/setup'

require 'helpers/config'
CURRENT_ENV = 'test'
H.config do |config|
  config[:current_env] = CURRENT_ENV  # !!
end

require 'mail'

Mail.defaults do
  delivery_method :test
end

require 'helpers/test/basic'


class BasicTestCase

  def common_setup
    # clean queue
    db = 'bolt_test'
    tasks_folder = 'test/fixtures/bolt/tasks'
    @coll = Mongo::MongoClient.new.db(db)['task_queue']
    @coll.db.eval 'db.dropDatabase()'
    Mail::TestMailer.deliveries.clear
    @opts = { :db => db, :tasks_folder => tasks_folder }
    H::Log.swallow! 0
  end

  def setup
    common_setup
  end

end
