require 'arqivarius/fark'
require 'arqivarius/pack_set'
require 'arqivarius/commit'
require 'arqivarius/tree'
require 'zlib'

module Arqivarius
  class Repo
    def initialize(dir, computer_uuid, bucket_uuid, password, salt)
      @dir = dir
      @computer_uuid = computer_uuid
      @bucket_uuid = bucket_uuid

      @crypto_key = LegacyCryptoKey.new(password)
      @stretched_crypto_key = CryptoKey.new(password, salt)

      @fark = Fark.new(@dir, computer_uuid)
      @trees_pack_set = PackSet.new(dir, computer_uuid, "#{bucket_uuid}-trees")
      @blobs_pack_set = PackSet.new(dir, computer_uuid, "#{bucket_uuid}-blobs")
      @glacier_blobs_pack_set = PackSet.new(dir, computer_uuid, "#{bucket_uuid}-glacierblobs")
    end

    def commit_for_blob_key(blob_key)
      sb = @trees_pack_set.new_server_blob_for_sha1(blob_key.sha1)

      encrypted = sb.data
      key = blob_key.stretch_encryption_key ? stretched_crypto_key : crypto_key
      data = key.decrypt(encrypted)

      begin
        Commit.new(data)
      rescue Error => e
        puts e, key.inspect, data.inspect
        nil
      end
    end

    def head_blob_key
      bucket_data_relative_path = "#{bucket_uuid}/refs/heads/master"

      sha1 = dir.files.get("#{computer_uuid}/bucketdata/#{bucket_uuid}/refs/heads/master").body

      stretch_encryption_key = false
      if sha1.length > 40
        stretch_encryption_key = sha1[40] == 'Y'
        sha1 = sha1[0...40]
      end

      BlobKey.new(sha1, STORAGE_S3, stretch_encryption_key, false)
    end

    def tree_for_blob_key(blob_key)
      sb = @trees_pack_set.new_server_blob_for_sha1(blob_key.sha1)

      encrypted = sb.data
      key = blob_key.stretch_encryption_key ? stretched_crypto_key : crypto_key
      data = key.decrypt(encrypted)

      data = Zlib::GzipReader.new(StringIO.new(data)).read

      Tree.new(data)
    end

    def server_blob(blob_key)
      sb = pack_set(blob_key).new_server_blob_for_sha1(blob_key.sha1) ||
        ServerBlob.from_file(dir.files.get("#{computer_uuid}/objects/#{blob_key.sha1}"))

      encrypted = sb.data
      key = blob_key.stretch_encryption_key ? stretched_crypto_key : crypto_key
      data = key.decrypt(encrypted)

      ServerBlob.new(data, sb.mime_type, sb.name)
    end

    def blob_data(blob_key)
      server_blob(blob_key).data
    end

    private

    attr_reader :dir, :computer_uuid, :bucket_uuid, :trees_pack_set, :stretched_crypto_key, :crypto_key

    def pack_set(blob_key)
      case blob_key.storage_type
      when STORAGE_S3
        @blobs_pack_set
      when STORAGE_GLACIER
        @glacier_blobs_pack_set
      end
    end
  end
end
