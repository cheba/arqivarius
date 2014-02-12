require 'stringio'

module Arqivarius
  class DiskPack
    def initialize(dir, computer_uuid, pack_set_name, pack_sha1, uid, gid)
      @dir = dir.dup
      @computer_uuid = computer_uuid
      @pack_set_name = pack_set_name
      @pack_sha1 = pack_sha1
    end

    def new_server_blob_for_object_at_offset(offset)
      io.seek(offset)

      if io.read(1).unpack('C')[0] == 1
        # Has MIME type
        mime_length = io.read(8).unpack('Q>')[0]
        mime_type = io.read(mime_length)
      end

      if io.read(1).unpack('C')[0] == 1
        # Has name
        name_length = io.read(8).unpack('Q>')[0]
        name = io.read(name_length)
      end

      data_length = io.read(8).unpack('Q>')[0]
      data = io.read(data_length)

      ServerBlob.new(data, mime_type, name)
    end

    private

    def io
      @io ||= begin
        cache_file_name = "#{BASE_PATH}/#{@dir.key}/#{@computer_uuid}/packsets/#{@pack_set_name}/#{@pack_sha1}.pack"
        if File.exist?(cache_file_name)
          data = File.binread(cache_file_name)
        else
          pack = @dir.files.get("#{@computer_uuid}/packsets/#{@pack_set_name}/#{@pack_sha1}.pack")
          data = pack.body
          FileUtils.mkdir_p(File.dirname(cache_file_name))
          File.binwrite(cache_file_name, data)
        end
        io = StringIO.new(data)
        io.binmode
        io
      end
    end
  end
end
