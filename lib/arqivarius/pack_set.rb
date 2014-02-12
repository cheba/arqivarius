require 'arqivarius/server_blob'
require 'arqivarius/disk_pack_index'
require 'arqivarius/disk_pack'

module Arqivarius
  class PackSet
    MAX_RETRIES = 10

    def initialize(dir, computer_uuid, name)
      @dir = dir.dup
      @computer_uuid = computer_uuid
      @name = name
    end

    def new_server_blob_for_sha1(sha1)
      sb = nil
      retries = 0

      lambda do
        begin
          sb = new_internal_server_blob_for_sha1(sha1)
        rescue => e
          # log it or something
          puts "#{retries}/#{MAX_RETRIES}: #{e}"
          if retries < MAX_RETRIES
            retries += 1
            redo
          end
        end
      end.call

      sb
    end


    private

    def new_internal_server_blob_for_sha1(sha1)

      # PackIndexEntry
      pie = pack_index_entries[sha1]
      if pie.nil?
        raise Error.new("sha1 #{sha1} not found in pack set #{@name}")
      end

      #puts pie.inspect

      disk_pack = DiskPack.new(@dir, @computer_uuid, @name, pie.pack_sha1, Process.uid, Process.gid)

      disk_pack.new_server_blob_for_object_at_offset(pie.offset)
    end

    def pack_index_entries
      @pack_index_entries ||= begin
        dir = @dir.dup
        dir.files.prefix = "#{@computer_uuid}/packsets/#{@name}/"
        packs = dir.files.all

        h = {}

        packs.each do |pack|
          if match = pack.key.match(Regexp.new('/(\w+)\.index$'))
            sha1 = match[1]
            puts sha1
            cache_file_name = "#{BASE_PATH}/#{dir.key}/#{dir.files.prefix}#{sha1}.index"
            if File.exist?(cache_file_name)
              data = File.binread(cache_file_name)
            else
              data = pack.body
              FileUtils.mkdir_p(File.dirname(cache_file_name))
              File.binwrite(cache_file_name, data)
            end

            index = DiskPackIndex.new(data, match[1])

            index.entries.each do |entry|
              h[entry.object_sha1] = entry
            end
          end
        end

        h
      end
    end
  end
end
