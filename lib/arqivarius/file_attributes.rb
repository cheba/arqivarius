require 'arqivarius/stat'

module Arqivarius
  class FileAttributes
    def initialize(path)
      @path = path
      @stat = File.lstat(@path)

      @target_exists = File.exist?(@path) # this resolves symlinks
    end

    def apply_finder_flags(flags)
      # FIXME
      $stderr.puts "Finder flags for #{@path}: #{flags.inspect}"
    end

    def apply_flags(flags)
      #$stderr.puts "Flags for #{@path}: #{flags.inspect}"
      Stat.chflags(@path, flags)
    end

    def apply_mtime(sec, nsec)
      mtime = sec + nsec / 1e9
      File.utime(File.atime(@path), mtime, @path)
    end

    def apply_ctime(sec, nsec)
      ctime = sec + nsec / 1e9
      File.utime(ctime, File.mtime(@path), @path)
    end
  end
end
