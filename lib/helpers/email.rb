
# mail config here to be shared wit everyone requiring this file
require 'mail'
require_relative 'config'
require_relative 'log'

# to be overriden in production
#
# Example:
#
#   Mail.defaults do
#     delivery_method :smtp, {
#       :enable_starttls_auto => true,
#       :address => 'smtp.mydom.com',
#       :port => 587,
#       :domain => 'mydom.com',
#       :authentication => 'plain',
#       :user_name => 'user',
#       :password => 'pass'
#     }
#
#

# By default is
#
#   Mail.defaults do
#     delivery_method :test
#   end
module Bolt
  module Helpers
    module Email

      @@calls = nil
      def self.count_calls!; @@calls = []; end
      def self.nocount_calls!; @@calls = nil; end
      def self.calls; @@calls; end

      def email(options = {})
        defaults = { :body => options[:subject].to_s }.merge(H.config[:email][:defaults])
        options = defaults.merge(options)
        m = Mail.new(options)
        @@calls << m if not @@calls.nil?
        m.deliver!
      rescue => ex
        H.log_ex ex
        false
      end

      def self.clear
        #Clear deliveries and calls. (to avoid trace overflow)
        Mail::TestMailer.deliveries.clear
        count_calls!
      end

    end
    extend Email
  end
end
