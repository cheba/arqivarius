require 'stringio'
require 'arqivarius/data_reader'

module Arqivarius
  class Tree

    include DataReader

    CURRENT_TREE_VERSION = 18
    TREE_HEADER_LENGTH = 8

    def initialize(data)
      @data = data
      @io = StringIO.new(@data)

      @nodes = {}
      @missing_nodes = {}

      parse_data
    end

    attr_reader :nodes, :st_ino, :st_nlink, :uid, :gid, :xattrs_blob_key,
      :xattrs_are_compressed, :finder_flags, :mode, :version, :mtime_sec,
      :mtime_nsec, :ctime_sec, :ctime_nsec, :flags, :acl_blob_key,
      :acl_is_compressed

    private

    attr_reader :io

    def parse_data
      read_header

      if version >= 12
        @xattrs_are_compressed = read_bool
        @acl_is_compressed = read_bool
      end

      @xattrs_blob_key = read_blob_key(version, @xattrs_are_compressed)
      @xattrs_size = read_uint64
      @acl_blob_key = read_blob_key(version, @acl_is_compressed)
      @uid = read_int32
      @gid = read_int32
      @mode = read_int32
      @mtime_sec = read_int64
      @mtime_nsec = read_int64
      @flags = read_int64
      @finder_flags = read_int32
      @extended_finder_flags = read_int32
      @st_dev = read_int32
      @st_ino = read_int32
      @st_nlink = read_uint32
      @st_rdev = read_int32
      @ctime_sec = read_int64
      @ctime_nsec = read_int64
      @st_blocks = read_int64
      @st_blksize = read_uint32

      if @xattrs_blob_key.sha1.nil?
        @xattrs_blob_key = nil
      end

      if @acl_blob_key.sha1.nil?
        @acl_blob_key = nil
      end

      if version >= 11 && version <= 16
        unusedAggregateSizeOnDisk = read_uint64
      end

      if version >= 15
        @create_time_sec = read_int64
        @create_time_nsec = read_int64
      end

      if version >= 18
        missing_node_count = read_uint32

        missing_node_count.times do
          missing_node_name = read_string
          @missing_nodes[missing_node_name] = read_node(version)
        end
      end

      node_count = read_uint32
      node_count.times do |i|
        node_name = read_string
        @nodes[node_name] = read_node(version)
      end
    end

    def read_header
      header = io.read(TREE_HEADER_LENGTH)

      if !header.start_with?('TreeV') || header.length < 6
        raise Error.new("invalid Tree header: #{header.inspect}")
      end

      @version = header[5..-1].to_i

      if @version < 10
        raise Error.new("unsupported Tree version: #{@version}")
      end

      if @version == 13
        raise Error.new("invalid Tree version: 13")
      end
    end

  end
end
