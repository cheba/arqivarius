module Arqivarius
  class Salt
    def initialize(dir, computer_uuid)
      @dir = dir
      @computer_uuid = computer_uuid
    end

    def salt
      @salt ||= @dir.files.get("#{@computer_uuid}/salt").body
    end
  end
end
