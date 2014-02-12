require 'ffi'

module Arqivarius
  module Stat
    extend FFI::Library
    ffi_lib FFI::Library::LIBC

    S_IFMT   = 0170000
    S_IFIFO  = 0010000
    S_IFCHR  = 0020000
    S_IFBLK  = 0060000
    S_IFLNK  = 0120000
    S_IFSOCK = 0140000

    S_ISUID = 0004000
    S_ISGID = 0002000
    S_ISVTX = 0001000


    attach_function :mkfifo, [ :string, :ushort ], :int


    # Definitions of flags stored in file flags word.
    #
    # Super-user and owner changeable flags.
    UF_SETTABLE   = 0x0000ffff  # mask of owner changeable flags
    UF_NODUMP     = 0x00000001  # do not dump file
    UF_IMMUTABLE  = 0x00000002  # file may not be changed
    UF_APPEND     = 0x00000004  # writes to file may only append
    UF_OPAQUE     = 0x00000008  # directory is opaque wrt. union

    # The following bit is reserved for FreeBSD.  It is not implemented
    # in Mac OS X.
    # UF_NOUNLINK = 0x00000010  # file may not be removed or renamed
    UF_COMPRESSED = 0x00000020  # file is hfs-compressed
    UF_TRACKED    = 0x00000040  # file renames and deletes are tracked
    # Bits 0x0080 through 0x4000 are currently undefined.
    UF_HIDDEN     = 0x00008000  # hint that this item should not be
                                # displayed in a GUI

    #
    # Super-user changeable flags.
    #
    SF_SETTABLE   = 0xffff0000  # mask of superuser changeable flags
    SF_ARCHIVED   = 0x00010000  # file is archived
    SF_IMMUTABLE  = 0x00020000  # file may not be changed
    SF_APPEND     = 0x00040000  # writes to file may only append

    #
    # The following two bits are reserved for FreeBSD.  They are not
    # implemented in Mac OS X.
    #
    # SF_NOUNLINK = 0x00100000  # file may not be removed or renamed
    # SF_SNAPSHOT = 0x00200000  # snapshot inode
    # NOTE: There is no SF_HIDDEN bit.

    attach_function :chflags, [ :string, :uint ], :int

    module_function

    # mode helpers
    def is_fifo(mode)
      mode & S_IFMT == S_IFIFO
    end

    def is_sock(mode)
      mode & S_IFMT == S_IFSOCK
    end

    def is_chr(mode)
      mode & S_IFMT == S_IFCHR
    end

    def is_blk(mode)
      mode & S_IFMT == S_IFBLK
    end

    def is_lnk(mode)
      mode & S_IFMT == S_IFLNK
    end
  end
end
