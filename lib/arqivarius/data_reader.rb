require 'arqivarius/blob_key'
require 'arqivarius/node'

module Arqivarius
  module DataReader
    # Requires #io

    private

    def read_string
      if read_bool
        read_data
      end
    end

    def read_bool
      io.read(1).unpack('C')[0] == 1
    end

    def read_date
      if read_bool
        msecs = read_int64
        Time.at(msecs / 1000.0)
      end
    end

    def read_int32
      io.read(4).unpack('l>')[0]
    end

    def read_uint32
      io.read(4).unpack('L>')[0]
    end

    def read_int64
      io.read(8).unpack('q>')[0]
    end

    def read_uint64
      io.read(8).unpack('Q>')[0]
    end

    def read_data
      io.read(read_uint64)
    end

    def read_blob_key(tree_version, compressed)
      data_sha1 = read_string

      stretch_encryption_key = if tree_version >= 14
                                 read_bool
                               else
                                 false
                               end

      if tree_version >= 17
        storage_type = read_uint32
        archive_id = read_string
        archive_size = read_uint64
        archive_uploaded_date = read_date
      else
        storage_type = STORAGE_S3
        archive_id = nil
        archive_size = 0
        archive_uploaded_date = nil
      end


      BlobKey.new(data_sha1, storage_type, stretch_encryption_key, compressed, archive_id, archive_size, archive_uploaded_date)
    end

    def read_node(tree_version)
      start = io.pos

      h = {
        version: tree_version,
        data_blob_keys: [],
        tree: read_bool,
      }


      if tree_version >= 18
        h[:tree_contains_missing_items] = read_bool
      end

      if tree_version >= 12
        h.merge!(
          data_are_compressed: read_bool,
          xattrs_are_compressed: read_bool,
          acl_is_compressed: read_bool
        )
      end

      data_blob_keys_count = read_int32
      data_blob_keys_count.times do
        h[:data_blob_keys] << read_blob_key(tree_version, h[:data_are_compressed])
      end

      h[:uncompressed_data_size] = read_uint64

      if tree_version < 18
        # As of Tree version 18 thumbnailBlobKey and previewBlobKey have been
        # removed. They were never used.
        read_blob_key(tree_version, false) # thumbnailBlobKey
        read_blob_key(tree_version, false) # previewBlobKey
      end

      h.merge!(
        xattrs_blob_key: read_blob_key(tree_version, h[:xattrs_are_compressed]),
        xattrs_size: read_uint64,
        acl_blob_key: read_blob_key(tree_version, h[:acl_is_compressed]),
        uid: read_int32,
        gid: read_int32,
        mode: read_int32,
        mtime_sec: read_int64,
        mtime_nsec: read_int64,
        flags: read_int64,
        finder_flags: read_int32,
        extended_finder_flags: read_int32,
        finder_file_type: read_string,
        finder_file_creator: read_string,
        file_extension_hiden: read_bool,
        st_dev: read_int32,
        st_ino: read_int32,
        st_nlink: read_uint32,
        st_rdev: read_int32,
        ctime_sec: read_int64,
        ctime_nsec: read_int64,
        create_time_sec: read_int64,
        create_time_nsec: read_int64,
        st_blocks: read_int64,
        st_blocksize: read_uint32
      )

      if h[:xattrs_blob_key].sha1.nil?
        h[:xattrs_blob_key] = nil
      end

      if h[:acl_blob_key].sha1.nil?
        h[:acl_blob_key] = nil
      end

      Node.new(h)
    end
  end
end
