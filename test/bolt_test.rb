# -*- coding:utf-8 -*-
require 'test_helper'
require 'helpers/email'
require 'bolt'
require 'mongo'

class BoltTest < BasicTestCase

  def setup
    # clean queue
    db = 'bolt_test'
    tasks_folder = 'test/fixtures/bolt/tasks'
    @coll = Mongo::MongoClient.new.db(db)['task_queue']
    @coll.db.eval 'db.dropDatabase()'
    Mail::TestMailer.deliveries.clear
    @opts = { :db => db, :tasks_folder => tasks_folder }
  end

  def test_dispatches_tasks
    H.announce

    # run Bolt, it should raise that there are no tasks
    H::Log.swallow! 1
    assert_raises Bolt::NotEnoughTasks do
      Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    end

    # Check runtime isolation, a constant is defined in two tasks
    # There must be no redefinition
    @coll.insert [{:task => 'constant_a'}, {:task => 'constant_b'}]
    Bolt.dispatch_loop @opts.merge(:tasks_count => 2)
    # Both tasks should be cleaned up on exit whether they failed or not.
    rows = @coll.find.to_a
    assert_equal 0, rows.count, rows
    # They should not fail, therefore send two success emails.
    mails = Mail::TestMailer.deliveries
    assert_equal 2, mails.count
    assert mails.all? { |m| m.subject =~ /Bolt nailed it!/ }, mails

    # Invalid task (no run method defined)
    Mail::TestMailer.deliveries.clear
    @coll.insert [{:task => 'invalid'}]
    H::Log.swallow! 1
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    # Both tasks should be cleaned up on exit whether they failed or not.
    rows = @coll.find.to_a
    assert_equal 0, rows.count, rows
    # This one should fail, therefore send one failure email.
    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count
    assert mails.first.subject =~ /Bolt could not run/, mails
    assert mails.first.body =~ /undefined method `run'/, mails.first

    # Exception raising task
    Mail::TestMailer.deliveries.clear
    @coll.insert [{:task => 'exception'}]
    H::Log.swallow! 1
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    # Both tasks should be cleaned up on exit whether they failed or not.
    rows = @coll.find.to_a
    assert_equal 0, rows.count, rows
    # This one should fail, therefore send one failure email.
    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count
    assert mails.first.subject =~ /Bolt could not run/, mails
    assert mails.first.body =~ /something bad happened/, mails.first
  end

  def test_applies_task_timeout
    H::Log.swallow! 1
    Mail::TestMailer.deliveries.clear

    @coll.insert [{:task => 'timeout', :timeout => 0.01}]
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)

    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count
    assert mails.first.body =~ /execution expired/, mails.first
  end

  # Pass a body to Bolt.email_success
  def test_use_email_body_from_task
    todo
  end

  # Execute a task at a given time
  def test_schedule
    H::Log.swallow! 1
    Mail::TestMailer.deliveries.clear
    @coll.insert [{:task => 'schedule', :run_at => Time.now.to_i + 10 }]
    assert_raises Bolt::NotEnoughTasks do
      Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    end

    @coll.insert [{:task => 'schedule', :run_at => Time.now.to_i }]
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
  end

  # No more than X forks at any given time
  def test_throttle
    todo
  end
end