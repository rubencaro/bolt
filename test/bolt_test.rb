# -*- coding:utf-8 -*-
require 'test_helper'
require 'helpers/email'
require 'bolt'

class BoltTest < BasicTestCase

  def test_dispatches_tasks
    H.announce
    Bolt::Helpers::Email.clear
    # run Bolt, it should raise that there are no tasks
    H::Log.swallow! 1
    assert_raises Bolt::NotExpectedNumberOfTasks do
      Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    end

    # Check runtime isolation, a constant is defined in two tasks
    # There must be no redefinition
    Bolt::Helpers.schedule [{:task => 'constant_a'}, {:task => 'constant_b'}]
    Bolt.dispatch_loop @opts.merge(:tasks_count => 2)
    # Both tasks should be cleaned up on exit whether they failed or not.
    rows = @coll.find.to_a
    assert_equal 0, rows.count, rows
    # They should not fail, therefore send two success emails.
    mails = Mail::TestMailer.deliveries
    assert_equal 2, mails.count
    assert mails.all? { |m| m.subject =~ /Bolt nailed it!/ }, mails

    # Invalid task (no run method defined)
    Bolt::Helpers::Email.clear
    Mail::TestMailer.deliveries.clear
    Bolt::Helpers.schedule :task => 'invalid'
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
    Bolt::Helpers::Email.clear
    Mail::TestMailer.deliveries.clear
    Bolt::Helpers.schedule :task => 'exception'
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
    H.announce
    Bolt::Helpers::Email.clear
    H::Log.swallow! 1
    Bolt::Helpers::Email.count_calls!

    Bolt::Helpers.schedule :task => 'timeout', :timeout => 0.01
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)

    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count
    assert mails.first.body =~ /execution expired/, mails.first
  end

  # Pass a body to Bolt.email_success
  def test_use_email_body_from_task
    H.announce
    Bolt::Helpers::Email.clear
    # create a task giving specific success email options
    body = 'specific body'
    subject = 'specificier subject'
    Bolt::Helpers.schedule({:task => 'constant_a',
                  :opts => { :email => { :success => { :body => body,
                                                       :subject => subject } } } } )
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)

    # sent success email has the specifics
    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count, mails
    assert_equal subject,  mails.first.subject, mails
    assert mails.first.body.to_s.include?(body), mails
    # and hidden techie details
    assert mails.first.body.to_s.include?('<div style="display:none !important;">'), mails

    # create a task giving specific failure email options
    H::Log.swallow! 1
    Bolt::Helpers::Email.clear
    Mail::TestMailer.deliveries.clear
    body = 'specific body'
    subject = 'specificier subject'
    Bolt::Helpers.schedule({:task => 'exception',
                  :opts => { :email => { :failure => { :body => body,
                                                       :subject => subject } } } } )
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)

    # sent success email has the specifics
    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count, mails
    assert_equal subject,  mails.first.subject, mails
    assert mails.first.body.to_s.include?(body), mails
    # and hidden techie details
    assert mails.first.body.to_s.include?('<div style="display:none !important;">'), mails
  end

  def test_saves_task_if_asked
    H.announce
    Bolt::Helpers::Email.clear
    # no ask, no tasks
    Bolt::Helpers.no_save_tasks!
    Bolt::Helpers.schedule :task => 'constant_a'
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    assert_equal nil, Bolt::Helpers.tasks

    # now ask, then tasks
    Bolt::Helpers::Email.clear
    Bolt::Helpers.save_tasks!
    Bolt::Helpers.schedule :task => 'constant_a'
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    tasks = Bolt::Helpers.tasks
    assert_equal 1, tasks.count, tasks
    assert_equal 'constant_a', tasks.first['task']
  end

  # Execute a task at a given time
  def test_run_at
    H.announce
    H::Log.swallow! 1
    Bolt::Helpers::Email.clear
    Bolt::Helpers.schedule :task => 'schedule', :run_at => Time.now.to_i + 10
    assert_raises Bolt::NotExpectedNumberOfTasks do
      Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    end

    Bolt::Helpers.schedule :task => 'schedule', :run_at => Time.now.to_i
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
  end

  # No more than X forks at any given time
  def test_throttle
    H.announce
    Bolt::Helpers::Email.clear
    prev = Bolt.throttle

    Bolt::Helpers.save_tasks!

    # enqueue several tasks
    3.times do |i|
      Bolt::Helpers.schedule :task => 'constant_a', :i => i
    end

    # if we ask Bolt to run over throttle it complains, not enough tasks
    H::Log.swallow! 1
    assert_raises Bolt::NotExpectedNumberOfTasks do
      Bolt.dispatch_loop @opts.merge(:tasks_count => 3, :throttle => 2)
    end

    Bolt.throttle = prev
  end

  def test_persist_and_finished
    H.announce

    Bolt::Helpers::Email.clear
    Bolt::Helpers.schedule :task => 'constant_a'
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    # Task should be cleaned up
    rows = @coll.find.to_a
    assert_equal 0, rows.count, rows

    Bolt::Helpers::Email.clear
    Bolt::Helpers.schedule :task => 'constant_a', :persist => true
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    # Task should not be cleaned up
    rows = @coll.find.to_a
    assert_equal 1, rows.count, rows
    # It should be marked as finished
    assert rows.first['finished'], rows
  end

  def test_silent
    H.announce
    Bolt::Helpers::Email.clear
    # default, via email
    Bolt::Helpers.schedule :task => 'constant_a'
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    # there should be one mail
    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count, mails

    # silent, saved in the task
    Bolt::Helpers::Email.clear
    # Mail::TestMailer.deliveries.clear
    Bolt::Helpers.schedule :task => 'constant_a', :silent => true, :persist => true
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    # there should be no mails
    mails = Mail::TestMailer.deliveries
    assert_equal 0, mails.count, mails
    # notifications should be in the task
    rows = @coll.find.to_a
    assert_equal 1, rows.count, rows
    assert rows.first['notifications'], rows
    # silent and failing, saved in the task, as the task is persisting
    @coll.remove
    Bolt::Helpers.schedule :task => 'invalid', :silent => true, :persist => true
    H::Log.swallow! 1
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    # there should be no mails
    mails = Mail::TestMailer.deliveries
    assert_equal 0, mails.count, mails
    # notifications should be in the task
    rows = @coll.find.to_a
    assert_equal 1, rows.count, rows
    assert rows.first['notifications'], rows
    Bolt::Helpers::Email.clear
    # silent and failing, via email, as the task is not persisting
    Bolt::Helpers.schedule :task => 'invalid', :silent => true, :persist => false
    H::Log.swallow! 1
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    # there should be some error mail
    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count, mails
    assert mails.first.subject =~ /Bolt could not run/, mails
  end

  def test_composite
    H.announce
    Bolt::Helpers::Email.clear
    # run composite task
    Bolt::Helpers.schedule :task => 'composite'
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1, :rounds => 3, :tasks_wait => 0.5)
    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count, mails
    assert mails.first.body.to_s.include?('fine from heyA'), mails.first.body.to_s
    assert mails.first.body.to_s.include?('fine from heyB'), mails.first.body.to_s
    # Tasks should be cleaned up
    rows = @coll.find.to_a
    assert_equal 0, rows.count, rows

    # now failing on subtasks
    Bolt::Helpers::Email.clear
    Mail::TestMailer.deliveries.clear
    Bolt::Helpers.schedule :task => 'composite', :fail => true
    H::Log.swallow! 2
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1, :rounds => 3, :tasks_wait => 0.5)
    mails = Mail::TestMailer.deliveries
    assert_equal 1, mails.count, mails
    assert mails.first.body.to_s.include?('failing from heyA'), mails.first.body.to_s
    assert mails.first.body.to_s.include?('failing from heyB'), mails.first.body.to_s
    # Tasks should be cleaned up
    rows = @coll.find.to_a
    assert_equal 0, rows.count, rows
  end

  def test_gets_recycled_tasks
    H.announce

    # schedule several tasks and only process the ones that should be recycled
    Bolt::Helpers::Email.clear
    # regular, non dispatched
    Bolt::Helpers.schedule :task => 'constant_a'

    # already dispatched, should be recycled
    Bolt::Helpers.schedule :task => 'constant_a', :dispatched => true

    # dispatched but also finished, should not be recycled
    Bolt::Helpers.schedule :task => 'constant_a', :dispatched => true,
        :finished => true

    # takes recycled and new tasks
    Bolt.dispatch_loop @opts.merge(:tasks_count => 2)

    # no new tasks, and nothing left to recycle
    H::Log.swallow! 1
    assert_raises Bolt::NotExpectedNumberOfTasks do
      Bolt.dispatch_loop @opts.merge(:tasks_count => 1)
    end
  end

  def test_sort_ids
    H.announce
    Bolt::Helpers::Email.clear
    # Order of creation -> order of return when querying.
    Bolt::Helpers.schedule :task => 'task_1'
    Bolt::Helpers.schedule :task => 'task_2'
    Bolt::Helpers.schedule :task => 'task_3'

    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)

    # The task that should be found must be the second one.
    task = @coll.find.to_a
    task_2 = @coll.find(task: 'task_2').to_a.first

    assert_equal task.first, task_2

  end
end
