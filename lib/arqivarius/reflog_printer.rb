require 'arqivarius/reflog_entry'

module Arqivarius
  class ReflogPrinter
    def initialize(dir, computer_uuid, bucket_uuid, repo)
      @dir = dir.dup
      @computer_uuid = computer_uuid
      @bucket_uuid = bucket_uuid
      @repo = repo
    end

    def print_reflog
      prefix = "#{computer_uuid}/bucketdata/#{bucket_uuid}/refs/logs/master/"
      dir.files.prefix = prefix
      paths = []
      dir.files.each do |f|
        paths << f
      end

      files = paths.sort do |a, b|
        # descending
        File.basename(b.key).to_i <=> File.basename(a.key).to_i
      end

      files.each do |file|
        print_entry(file)
      end
    end

    private

    attr_reader :repo, :dir, :computer_uuid, :bucket_uuid

    def print_entry(file)
      puts "reflog #{file.key}"

      begin
        entry = ReflogEntry.new(file.body)
      rescue => e
        puts "\terror reading reflog entry: #{e}"
      else
        if commit = repo.commit_for_blob_key(entry.new_head_blob_key)

        puts "\tblobkey: #{entry.new_head_blob_key.inspect}"
        puts "\tauthor: #{commit.author}"
        puts "\tdate: #{commit.creation_date}"
        puts "\tlocation: #{commit.location}"
        puts "\trestore command: #{$0} #{dir.key}/#{computer_uuid}/buckets/#{bucket_uuid} #{entry.new_head_blob_key.sha1}\n\n"
        else
          puts 'oops'
        end
      end
    end
  end
end
