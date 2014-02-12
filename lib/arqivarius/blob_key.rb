module Arqivarius
  class BlobKey
    def initialize(sha1, storage_type, stretch_encryption_key, compressed, archive_id = nil, archive_size = 0, archive_uploaded_date = nil)
      @sha1 = sha1
      @storage_type = storage_type
      @stretch_encryption_key = stretch_encryption_key
      @compressed = compressed
      @archive_id = archive_id
      @archive_size = archive_size
      @archive_uploaded_date = archive_uploaded_date
    end

    attr_reader :sha1, :stretch_encryption_key, :compressed, :storage_type

    def ==(other)
      other.sha1 == @sha1 && other.stretch_encryption_key = @stretch_encryption_key
    end
  end
end
