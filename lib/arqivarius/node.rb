module Arqivarius
  class Node
    def initialize(attrs)
      attrs.each do |k, v|
        instance_variable_set :"@#{k}", v
      end
    end

    attr_reader :st_ino, :st_nlink, :mode, :data_blob_keys,
      :uncompressed_data_size, :data_blob_keys, :xattrs_blob_key,
      :xattrs_are_compressed, :acl_blob_key, :acl_is_compressed, :version,
      :mtime_sec, :mtime_nsec, :ctime_sec, :ctime_nsec, :flags, :uid, :gid

    def tree?
      !!@tree
    end

    def tree_blob_key
      raise Error.new("must be a Tree") unless tree?

      @data_blob_keys.first
    end
  end
end
