require 'stringio'

module Arqivarius
  class ServerBlob
    def self.from_file(file)
      data = file.body
      mime_type = file.content_type

      if file.content_disposition
        name = file.content_disposition[/attachment;filename=(.+)/, 1]
      end

      new(data, mime_type, name)
    end

    def initialize(data, mime_type, name)
      @data = data
      @mime_type = mime_type
      @name = name
    end

    attr_reader :data, :mime_type, :name
  end
end
