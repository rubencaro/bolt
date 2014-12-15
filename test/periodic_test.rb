# -*- coding:utf-8 -*-
require 'test_helper'
require 'helpers/email'
require 'bolt'
require 'mongo'

class PeriodicTest < BasicTestCase

  def test_periodic_run_process
    H.announce

    # create periodic task and run it
    t ={ :task => 'constant_a', :period => 30, :run_at => Time.now.to_i - 1,
         :more => 'things' }
    next_run_at = t[:run_at] + t[:period]
    Bolt::Helpers.schedule t
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)

    # it schedules a regular task with its data
    # and it reschedules itself in the future using given period
    check_periodic t, next_run_at
  end

  def test_every_given_hour
    H.announce

    # create periodic task and run it
    t ={ :task => 'constant_a', :period => 7, :period_type => 'every_given_hour',
         :run_at => Time.now.to_i - 1,
         :more => 'things' }
    next_run_at = (Time.at(t[:run_at]).to_datetime + 1).to_time.to_i
    Bolt::Helpers.schedule t
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)

    # it schedules a regular task with its data
    # and it reschedules itself in the future using given period
    check_periodic t, next_run_at
  end

  def test_every_given_day
    H.announce

    # create periodic task and run it
    t ={ :task => 'constant_a', :period => 7, :period_type => 'every_given_day',
         :run_at => Time.now.to_i - 1,
         :more => 'things' }
    next_run_at = (Time.at(t[:run_at]).to_datetime >> 1).to_time.to_i
    Bolt::Helpers.schedule t
    Bolt.dispatch_loop @opts.merge(:tasks_count => 1)

    # it schedules a regular task with its data
    # and it reschedules itself in the future using given period
    check_periodic t, next_run_at
  end

  def check_periodic(t, next_run_at)
    # it schedules a regular task with its data
    # and it reschedules itself in the future using given period
    rows = @coll.find.to_a
    assert_equal 2, rows.count, rows
    assert rows.any?{|r| r['period']}, rows
    assert rows.any?{|r| r['period'].nil?}, rows
    rows.each do |r|
      if r['period'] then # the periodic one
        assert_equal next_run_at, r['run_at'], r
        assert_equal t[:period], r['period']
      else # the regular one
        assert_equal t[:run_at], r['run_at']
      end
      assert_equal t[:task], r['task']
      assert_equal t[:more], r['more']
    end
  end

end
