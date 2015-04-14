
module Helpers
  module Path

    # 'watcher' must respond to 'file_modified'
    #
    #  Example:
    #
    #     m = Module.new do
    #       def self.file_modified(file,opts = {})
    #         log "Suiciding now (from #{File.basename file})..."
    #         exit 0
    #       end
    #     end
    #
    #     watch_file(Dir.pwd + "/tmp/restart.txt", m)
    #
    #     loop do
    #       sleep 30
    #       check_watched_files :hey => 'you'
    #     end
    #
    #
    def watch_file(path,watcher)
      @watched_files ||= {}
      @watched_files[path] ||= {}
      @watched_files[path][:watchers] ||= []
      @watched_files[path][:watchers] << watcher
      @watched_files[path][:mtime] = File.new(path).mtime
    end

    def check_watched_files(*args)
      @watched_files.each do |path,data|
        file = File.new(path)
        next if data[:mtime] == file.mtime
        data[:watchers].each{ |w| w.file_modified file, *args }
        data[:mtime] = file.mtime # maybe we want to rerun this
      end
    end

  end
  extend Path
end

H = Helpers if not defined? H
