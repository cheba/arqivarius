require 'ffi'

module Arqivarius
  class ACL
    def initialize(text)
      @acl = ACL.acl_from_text(text)

      ObjectSpace.define_finalizer(self, proc {
        puts @acl
        ACL.acl_free(@acl)
      })
    end

    def write(path)
      result = if File.symlink?(path)
        ACL.acl_set_link_np(path, :extended, @acl)
      else
        ACL.acl_set_file(path, :extended, @acl)
      end
      if result != 0
        raise FFI.errno
      end
    end

    module ACL
      extend FFI::Library
      ffi_lib FFI::Library::LIBC

      enum :acl_type, [
        :extended, 0x00000100,
        # Posix 1003.1e types - not supported
        :access,  0x00000000,
        :default, 0x00000001,
        # The following types are defined on FreeBSD/Linux - not supported
        :afs,     0x00000002,
        :coda,    0x00000003,
        :ntfs,    0x00000004,
        :nwfs,    0x00000005
      ]

      attach_function :acl_init, [:int], :pointer
      attach_function :acl_free, [ :pointer ], :int

      attach_function :acl_get_file, [:string, :acl_type], :pointer
      attach_function :acl_get_link_np, [:string, :acl_type], :pointer
      attach_function :acl_set_file, [:string, :acl_type, :pointer], :int
      attach_function :acl_set_link_np, [:string, :acl_type, :pointer], :int

      attach_function :acl_from_text, [ :string ], :pointer
      attach_function :acl_to_text, [:pointer, :pointer], :string
    end
  end
end
