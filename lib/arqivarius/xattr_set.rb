require 'stringio'
require 'arqivarius/data_reader'
require 'ffi-xattr'

module Arqivarius
  class XAttrSet

    include DataReader

    HEADER_LENGTH = 12

    def initialize(data)
      @xattrs = {}

      @io = StringIO.new(data)

      parse_data
    end

    def apply_to_file(path)
      xattr = Xattr.new(path)

      @xattrs.each do |key, value|
        xattr[key] = value
      end
    end

    private

    attr_reader :io

    def parse_data
      read_header

      count = read_uint64
      count.times do
        name = read_string
        @xattrs[name] = read_data
      end
    end

    def read_header
      header = io.read(HEADER_LENGTH)

      if header != 'XAttrSetV002'
        raise Error.new('invalid XAttrSet header')
      end
    end
  end
end
