require 'plist'

module Arqivarius
  class UserAndComputer
    def self.from_plist(xml)
      h = Plist.parse_xml(xml)

      if h
        new(h['userName'], h['computerName'])
      else
        new
      end
    end

    def initialize(user_name = nil, computer_name = nil)
      @user_name = user_name || ENV['USER']
      @computer_name = computer_name || ''
    end

    attr_reader :user_name, :computer_name
  end
end
