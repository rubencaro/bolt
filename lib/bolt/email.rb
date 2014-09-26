
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
      if body then
        body += '<div style="display:none;">'
      else
        body = 'Bolt nailed it! Again!<br/><div>'
      end
      body += "&nbsp;&nbsp;&nbsp;Original run request was: #{opts[:task].to_html_ul} </div>"

      H.email :to => to,
              :body => body,
              :subject => subject
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
      if body then
        body += '<div style="display:none;">'
      else
        body = 'Something went wrong. Bolt could not run that race.<br/><div>'
      end
      body += "&nbsp;&nbsp;&nbsp;Original run request was: #{opts[:task].to_html_ul}"
      body += "&nbsp;&nbsp;&nbsp;Exception was: #{ex}" if ex
      body += "<br/> trace: &nbsp;&nbsp;&nbsp;#{backtrace.to_html_ul}" if backtrace
      body += "</div>"

      H.email :to => to,
              :body => body,
              :subject => subject
    end

  end

end
