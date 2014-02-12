require 'arqivarius/data_reader'
require 'arqivarius/pack_index_entry'

module Arqivarius
  class DiskPackIndex
    include DataReader

    def initialize(data, pack_sha1)
      @data = data
      @pack_sha1 = pack_sha1
      @entries = []

      @io = StringIO.new(@data)
      @io.binmode

      parse_data
    end

    attr_reader :entries, :archive_id, :archive_size

    private

    attr_reader :io

    def parse_data

      io.seek(1028)
      count = read_uint32

      count.times do |i|
        offset = read_uint64
        length = read_uint64
        sha1 = io.read(20).unpack('H40')[0]
        io.seek(4, IO::SEEK_CUR) # alignment

        @entries << PackIndexEntry.new(@pack_sha1, offset, length, sha1)
      end

      if io.size - io.pos > 20
        # looks like there might be glacier archive info
        if read_bool
          @archive_id = read_data
          @archive_size = read_uint64
        end
      end
    end
  end
end
