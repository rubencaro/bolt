
module Helpers
  @@config = {
    :current_env => 'development',
    :test_server_port => 10000,

    :email => { :defaults => {
        :from => "test", # ejemplo de uso: "'My name' <myname@mydomain.com>"
        :to => 'heya@heeeeyaaaa.com',
        :content_type => 'text/html'
      }
    },

    :net => {
      :whitelisted_ips => [],
      :fog => {
        :provider => 'AWS',
        :region => 'eu-west-1',
        :endpoint => 'https://s3.amazonaws.com'
      }
    }
  }

  def self.config
    if block_given? then
      yield @@config
    else
      @@config
    end
  end
end

H = Helpers if not defined? H
