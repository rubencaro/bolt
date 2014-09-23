 # -*- coding:utf-8 -*-
$:.unshift '.','lib'
require 'bundler/setup'

require 'helpers/config'
CURRENT_ENV = 'test'
H.config do |config|
  config[:current_env] = CURRENT_ENV  # !!
end

require 'helpers/test'
