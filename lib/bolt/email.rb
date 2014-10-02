
require 'helpers/email'

module Bolt

  module Email

    def self.success(opts)
      opts[:task] ||= {}
      to = opts[:task]['email'] || 'tech+bolt@elpulgardelpanda.com'

      opts[:task]['opts'] ||= {}
      opts[:task]['opts']['email'] ||= {}
      opts[:task]['opts']['email']['success'] ||= {}

      subject = opts[:task]['opts']['email']['success']['subject'] ||
                "Bolt nailed it! '#{opts[:task]['task'].to_s}'"

      body = opts[:task]['opts']['email']['success']['body']
      if not body then
        body = "Bolt nailed it! Again!<br/>Task #{opts[:task]['task']} is complete."
      end
      body += "<br>(Details are on invisible ink...)<div style=\"display:none !important;\">\n\n\n\n"
      body += "Original run request was: #{opts[:task].inspect} </div>"

      H.email :to => to,
              :body => body,
              :subject => subject,
              :content_type => 'text/html'
    end

    def self.failure(opts)
      opts[:task] ||= {}
      emails = []
      emails << opts[:task]['email'] if opts[:task]['email']
      emails << 'tech+bolt@elpulgardelpanda.com'
      to = emails.join(',')

      ex = opts[:task].delete 'ex'
      backtrace = opts[:task].delete 'backtrace'

      opts[:task]['opts'] ||= {}
      opts[:task]['opts']['email'] ||= {}
      opts[:task]['opts']['email']['failure'] ||= {}

      subject = opts[:task]['opts']['email']['failure']['subject'] ||
                "Bolt could not run '#{opts[:task]['task'].to_s}'"

      body = opts[:task]['opts']['email']['failure']['body']
      if not body then
        body = "Something went wrong. Bolt could not run that race.<br>"
        body += "Exception was: #{ex}" if ex
      end
      body += "<br>(Details are on invisible ink...)<div style=\"display:none !important;\">\n\n\n\n"
      body += "Original run request was: #{opts[:task].inspect}"
      body += "\n\n Exception was: #{ex}" if ex
      body += "\n\n trace: #{backtrace.inspect}" if backtrace
      body += "</div>"

      H.email :to => to,
              :body => body,
              :subject => subject,
              :content_type => 'text/html'
    end

  end

end
