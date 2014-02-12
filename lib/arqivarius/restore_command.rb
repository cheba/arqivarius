require 'unf'
require 'fog'
require 'plist'

require 'arqivarius/backup_set'
require 'arqivarius/crypto_key'
require 'arqivarius/user_and_computer'
require 'arqivarius/salt'
require 'arqivarius/repo'
require 'arqivarius/reflog_printer'
require 'arqivarius/restorer'

module Arqivarius
  class RestoreCommand

    def initialize
      @access_key = ENV['ARQ_ACCESS_KEY']
      @secret_key = ENV['ARQ_SECRET_KEY']
      @encryption_password = ENV['ARQ_ENCRYPTION_PASSWORD']

      validate_s3_keys

      @s3 = Fog::Storage.new({
        provider:              'AWS',
        aws_access_key_id:     @access_key,
        aws_secret_access_key: @secret_key
      })
    end

    # FIXME This is fucked up. Use something fomr std-lib
    def read_args
      ARGV.each_with_index do |arg, i|
        if arg[0] == '-'
          if arg == '-v'
            puts "#{$0} version 2014-02-01"
          else
            $stderr.puts "unknown option #{arg}"
          end
        elsif @path.nil?
          @path = arg
        elsif @commit_sha1.nil?
          @commit_sha1 = arg
        else
          $stderr.puts "warning: ignoring argument '#{arg}'"
        end
      end
    end

    def execute
      if @path.nil?
        print_arq_folders
      else
        process_path
      end
    end

    private

    def print_arq_folders
      backup_sets = BackupSet.all_backup_sets(@s3)
      backup_sets.each do |backup_set|
        puts "S3 bucket: #{backup_set.s3_bucket_name}"

        uac = backup_set.user_and_computer # UserAndComputer
        if !uac.nil?
          puts "    #{uac.computer_name} (#{uac.user_name})"
        else
          puts "    (unknown computer)"
        end
        puts "    UUID #{backup_set.computer_uuid}"

        buckets = backup_set.buckets
        if buckets.any?
          puts

          buckets.each do |bucket|
            data = bucket.body

            # Decrypt the plist if necessary:
            encryption_header = "encrypted"
            if data.length >= encryption_header.length && data[0...encryption_header.length] == encryption_header
              encrypted_data = data[encryption_header.length..-1]
              cryptoKey = CryptoKey.new(@encryption_password, BUCKET_PLIST_SALT)
              begin
                data = cryptoKey.decrypt(encrypted_data)
                if data.nil?
                  puts 'next'
                  next
                end
              rescue OpenSSL::Cipher::CipherError => e
                puts "    This backup cannot be decrypted with current password: #{e}", ''
                next
              end
            end

            plist = Plist.parse_xml(data)
            if plist
              puts "        #{plist['LocalPath']}"
              puts "            UUID:            #{File.basename bucket.key}"
              puts "            reflog command:  #{$0} #{backup_set.s3_bucket_name}/#{bucket.key} reflog"
              puts "            restore command: #{$0} #{backup_set.s3_bucket_name}/#{bucket.key}"
              puts
            end
          end
        else
          puts "    (no folders found)"
        end
      end
    end

    def process_path
      if @encryption_password.nil?
        Error.new("missing ARQ_ENCRYPTION_PASSWORD environment variable")
      end

      pattern = Regexp.new('^([^/]+)/([^/]+)/buckets/([^/]+)')
      match = @path.match(pattern)
      if match.nil?
        raise Error.new("invalid S3 path")
      end

      s3BucketName = match[1]
      computer_uuid = match[2]
      bucket_uuid = match[3]

      bucket_name = "(unknown)"

      dir = @s3.directories.get(s3BucketName, delimiter: '/')

      file = dir.files.get("#{computer_uuid}/buckets/#{bucket_uuid}")

      if file
        data = file.body
        if data[0...9] == "encrypted"
          data = data[9..-1]
          crypto_key = CryptoKey.new(@encryption_password, BUCKET_PLIST_SALT)

          data = crypto_key.decrypt(data)
          if data.nil?
            raise Error.new("failed to decrypt #{@path}")
          end
        end

        plist = Plist.parse_xml(data)
        if plist
          bucket_name = plist['BucketName']
        end
      end

      uac_data = dir.files.get("#{computer_uuid}/computerinfo")
      if uac_data
        h = Plist.parse_xml(uac_data.body)
        uac = UserAndComputer.new(h['userName'], h['computerName'])
      end

      salt = Salt.new(dir, computer_uuid)

      # ArqRepo
      repo = Repo.new(dir, computer_uuid, bucket_uuid, @encryption_password, salt.salt)

      if @commit_sha1 == 'reflog'
        puts "printing reflog for #{bucket_name}"
        printer = ReflogPrinter.new(dir, computer_uuid, bucket_uuid, repo)
        printer.print_reflog
      else
        computer_description = if uac
          "#{uac.computer_name} (#{uac.user_name})"
        else
          "(unknown computer)"
        end
        puts "restoring #{bucket_name} from #{computer_description} to #{BASE_PATH}/restores/#{bucket_name}"

        restorer = Restorer.new(repo, bucket_name, @commit_sha1)
        if !restorer.restore
          return false
        end
        puts "restored files are in #{bucket_name}"
        if restorer.errors_by_path.any?
          puts "\nErrors occurred:"
          restorer.errors_by_path.sort { |(a, _), (b, _)| a.downcase <=> b.downcase }.each do |key, val|
            puts "#{key}\t\t#{val}"
          end
        end
      end
    end

    def validate_s3_keys
      if @access_key.nil?
        raise Error.new("missing ARQ_ACCESS_KEY environment variable")
      end
      if @secret_key.nil?
        raise Error.new("missing ARQ_SECRET_KEY environment variable")
      end
    end
  end
end
