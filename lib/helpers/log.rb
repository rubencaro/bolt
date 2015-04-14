
NODE = 'devel' if not defined? NODE


module Helpers
  module Log

    @@next_color = 0 # for alternate
    @@palette = [:dark_gray, :light_gray]

    @@quiet = false
    def self.quiet!; @@quiet = true; end
    def self.noquiet!; @@quiet = false; end

    # swallow that many exceptions
    @@swallow = 0
    def self.swallow!(num = 1); @@swallow = num; end

    def log(msg, opts = {})
      return if @@quiet
      opts[:location] ||= get_location.first

      msg = "[#{NODE}][#{opts[:location]}] #{msg}" if not opts[:clean]

      msg = send(opts[:color],msg) if opts[:color]

      msg = "[#{Time.now}]" + msg if not opts[:clean]
      puts msg
      $stdout.flush
    end

    def log_ex(ex, opts = {})
      @@swallow -= 1
      return if @@swallow >= 0
      opts[:location] ||= get_location.first
      msg = opts[:msg].to_s
      msg += light_purple(" \n Exception: #{ex.to_s} \n ")
      msg << purple(" Backtrace: #{ex.backtrace.join("\n")} ") unless opts[:trace] == false
      log msg, opts
    end

    def spit(msg, opts = {}) # allow hashes as msg
      opts[:color] ||= :light_red
      log "\n (#{get_location.first}) \n " + msg.inspect + " \n ", color: opts[:color], clean: true
    end

    def announce(msg = nil, opts = {})
      location = get_location
      msg ||= "\n ==> Entering #{location.last} (#{location.first})..."
      opts[:color] ||= :light_cyan
      opts[:clean] = true
      log msg, opts
    end

    def get_location(offset = 2)
      return get_location_19(offset + 1) if not defined?(caller_locations)
      label = caller_locations(offset, 1)[0].label
      place = File.basename(caller_locations(offset, 1)[0].path) + ":" + caller_locations(offset, 1)[0].lineno.to_s
      [place, label]
    end

    def get_location_19(offset = 2)
      call_site_info = caller[offset]
      file_info, function_info = call_site_info.split(' ')
      full_file_name, line_number, _ = file_info.split(':')
      function_name = function_info.gsub(/`/, '').gsub(/'/, '')
      place = File.basename(full_file_name) + ":" + line_number
      [place, function_name]
    end

    def yellow(str)
      " \033[1;33m " + str + " \033[00m "
    end

    def cyan(str)
      " \033[0;36m " + str + " \033[00m "
    end

    def light_cyan(str)
      " \033[1;36m " + str + " \033[00m "
    end

    def blue(str)
      " \033[0;34m " + str + " \033[00m "
    end

    def light_blue(str)
      " \033[1;34m " + str + " \033[00m "
    end

    def purple(str)
      " \033[0;35m " + str + " \033[00m "
    end

    def light_purple(str)
      " \033[1;35m " + str + " \033[00m "
    end

    def brown(str)
      " \033[0;33m " + str + " \033[00m "
    end

    def red(str)
      " \033[0;31m " + str + " \033[00m "
    end

    def light_red(str)
      " \033[1;31m " + str + " \033[00m "
    end

    def light_gray(str)
      " \033[0;37m " + str + " \033[00m "
    end

    def dark_gray(str)
      " \033[1;30m " + str + " \033[00m "
    end

    def white(str)
      " \033[1;37m " + str + " \033[00m "
    end

    def alternate(str)
      color = @@palette[@@next_color]
      @@next_color += 1
      @@next_color = 0 if @@next_color >= @@palette.size
      send(color,str)
    end

  end

  extend Log
end

H = Helpers if not defined? H
