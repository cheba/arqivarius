require 'plist'

require 'arqivarius/blob_key'

module Arqivarius
  class ReflogEntry
    def initialize(data)
      h = Plist.parse_xml(data)
      $stderr.puts h.inspect

      required_keys = %w[newHeadSHA1 newHeadStretchKey]
      if (h.keys & required_keys) != required_keys
        raise Error.new('missing values in reflog entry')
      end

      @old_head_blob_key = BlobKey.new(h['oldHeadSHA1'], STORAGE_S3, h['oldHeadStretchKey'], false)
      @new_head_blob_key = BlobKey.new(h['newHeadSHA1'], STORAGE_S3, h['newHeadStretchKey'], false)
    end

    attr_reader :old_head_blob_key, :new_head_blob_key
  end
end
