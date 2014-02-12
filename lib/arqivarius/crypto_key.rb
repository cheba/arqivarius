

module Arqivarius
  class CryptoKey
    ITERATIONS = 1000
    KEYLEN = 48

    def initialize(password, salt)
      if password.nil? || password.empty?
        raise Error.new("missing encryption password")
      end

      if !salt.nil? && salt.length != 8
        raise Error.new("salt must be 8 bytes or nil")
      end

      if salt.nil?
        $stderr.puts "NULL salt value for CryptoKey"
      end
      @salt = salt

      @buf = OpenSSL::PKCS5.pbkdf2_hmac_sha1(password, @salt, ITERATIONS, KEYLEN)
    end

    def decrypt(str)
      c = OpenSSL::Cipher::AES.new(256, 'CBC').decrypt
      c.pkcs5_keyivgen @buf, @salt, 1000, 'SHA1'

      c.update(str) + c.final
    end
  end

  class LegacyCryptoKey
    ITERATIONS = 1000
    KEYLEN = 48

    def initialize(password)
      if password.nil? || password.empty?
        raise Error.new("missing encryption password")
      end

      @password = password
    end

    def decrypt(str)
      c = OpenSSL::Cipher::AES.new(256, 'CBC').decrypt
      c.pkcs5_keyivgen @password, nil , 1
      c.padding = 0

      c.update(str) + c.final
    end
  end
end
