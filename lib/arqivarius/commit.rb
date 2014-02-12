require 'stringio'
require 'arqivarius/commit_failed_file'
require 'arqivarius/data_reader'

module Arqivarius
  class Commit

    include DataReader

    HEADER_LENGTH = 10
    CURRENT_COMMIT_VERSION = 9

    def initialize(data)
      @data = data
      @io = StringIO.new(@data)
      @io.binmode

      parse_data
    end

    attr_reader :author, :creation_date, :location, :tree_blob_key

    private

    attr_reader :io

    def parse_data
      read_header

      @author = read_string
      @comment = read_string

      parent_commit_key_count = io.read(8).unpack('Q>')[0]

      parent_commit_key_count.times do |i|
        key = read_string
        crypto_key_stretched = @version >= 4 ? read_bool : false

        if @parent_commit_blob_key.nil?
          @parent_commit_blob_key = BlobKey.new(key, STORAGE_S3, crypto_key_stretched, false)
        end
      end

      tree_sha1 = read_string
      tree_stretched_key = @version >= 4 ? read_bool : false
      tree_is_compressed = @version >= 8 ? read_bool : false
      @tree_blob_key = BlobKey.new(tree_sha1, STORAGE_S3, tree_stretched_key, tree_is_compressed)

      @location = read_string

      if match = @location.match(%r{^file://([^/]+)/})
        @computer = match[1]
      else
        @computer = ''
      end

      if @version < 8
        merge_common_ancestors_commit_sha1 = read_string
        if @version >= 4
          merge_common_ancestors_commit_stretch_key = read_bool
        end
      end

      @creation_date = read_date

      if @version >= 3
        commit_failed_file_count = read_uint64
        @commit_failed_files = []
        commit_failed_file_count.times do
          @commit_failed_files << CommitFailedFile.new(read_string, read_string)
        end
      end

      if @version >= 8
        @has_missing_nodes = read_bool
      end

      @is_complete = @version >= 9 ? read_bool : true

      if @version >= 5
        @bucket_xml_data = read_data
      end
    end

    def read_header
      header = io.read(HEADER_LENGTH)
      if !header.start_with?('CommitV') || header.length < 8
        raise Error.new("Invalid commit header: #{header.inspect}")
      end

      @version = header[7..-1].to_i
      if @version > CURRENT_COMMIT_VERSION || @version < 2
        raise Error.new("Invalid commit version: #{@version}")
      end
    end
  end
end
