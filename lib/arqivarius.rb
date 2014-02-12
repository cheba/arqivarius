require "arqivarius/version"

require "arqivarius/restore_command"

module Arqivarius

  STORAGE_S3 = 1
  STORAGE_GLACIER = 2

  BUCKET_PLIST_SALT = "BucketPL"
  BASE_PATH = '/tmp/.arqivarius'

  class Error < StandardError; end
end
