module Arqivarius
  class PackIndexEntry
    def initialize(pack_sha1, offset, length, object_sha1)
      @pack_sha1 = pack_sha1
      @offset = offset
      @length = length
      @object_sha1 = object_sha1
    end

    attr_reader :pack_sha1, :offset, :length, :object_sha1
  end
end
