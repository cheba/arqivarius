module Arqivarius
  class CommitFailedFile
    def initialize(path, error_message)
      @path = path
      @error_message = error_message
    end
  end
end
