module Arqivarius
  class BackupSet
    def self.all_backup_sets(storage)
      storage.directories.map do |dir|
        if dir.key =~ /-com-haystacksoftware-arq|comhaystacksoftwarearq|\.com\.haystacksoftware\.arq|-arqivarius/
          storage.directories.get(dir.key, delimiter: '/')
        else
          nil
        end
      end.compact.map do |dir|
        dir.files.common_prefixes.map do |prefix|
          backup_dir = dir.dup
          computer_info_path = "#{prefix}computerinfo"

          if uac_data = backup_dir.files.get(computer_info_path)
            uac = UserAndComputer.from_plist(uac_data.body)
          end

          computer_uuid = File.basename(prefix)

          BackupSet.new(backup_dir, computer_uuid, uac)
        end
      end.flatten.sort do |a, b|
        a.description <=> b.description
      end
    end

    def initialize(dir, computer_uuid, user_and_computer)
      @dir = dir
      @computer_uuid = computer_uuid
      @user_and_computer = user_and_computer
    end

    def description
      if @user_and_computer
        "#{@user_and_computer.computer_name} (#{@user_and_computer.user_name}) : #{@dir.location} (#{@computer_uuid})"
      else
        "unknown computer : #{@dir.location} (#{@computer_uuid})"
      end
    end

    def s3_bucket_name
      @dir.key
    end

    attr_reader :computer_uuid, :user_and_computer

    def buckets
      dir = @dir.dup
      dir.files.prefix = "#{@computer_uuid}/buckets/"
      dir.files.all
    end
  end
end
