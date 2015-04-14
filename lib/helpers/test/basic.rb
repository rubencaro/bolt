# -*- coding: utf-8 -*-

#
#  Basic unit test needs. No running server, no bigfish requires, no fancy helpers.
#
require 'minitest/pride'
require 'minitest/autorun'
require_relative '../log'
require_relative '../test'

class BasicTestCase < Minitest::Test

  def assert(boolean, message='')
    message = message.call if message.respond_to?(:call)

    # cut the boring bits
    bt_limit = caller.find_index { |c| c =~ /test\.rb/ }
    bt = caller[0..bt_limit]

    message = H.yellow(message.to_s) + H.brown("\n#{bt.join("\n")}")
    super(boolean, message)
  end

  def todo(msg = nil, opts = {})
    place, label = H.get_location
    msg ||= "\n TODO: #{label} (#{place})..."
    opts[:color] ||= :yellow
    opts[:clean] = true
    H.log msg, opts
    skip msg
  end

  def wonttest(msg = nil, opts = {})
    place, label = H.get_location
    msg ||= "\n WONTTEST: #{label} (#{place})..."
    opts[:color] ||= :brown
    opts[:clean] = true
    H.log msg, opts
  end

end
