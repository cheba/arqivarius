require 'arqivarius/blob_key'
require 'fileutils'
require 'arqivarius/stat'
require 'arqivarius/acl'
require 'arqivarius/file_attributes'
require 'arqivarius/xattr_set'

module Arqivarius
  class Restorer
    def initialize(repo, bucket_name, commit_sha1)
      @repo = repo
      @bucket_name = bucket_name
      @commit_sha1 = commit_sha1
      @hard_links = {}
      @super_user_node_count = 0

      @errors_by_path = {}

      @root_path = File.join(BASE_PATH, 'restores', @bucket_name)
    end

    attr_reader :errors_by_path

    def restore
      if @commit_sha1.nil?
        commit_blob_key = BlobKey.new(commit_sha1, STORAGE_S3, true, false)
        commit = repo.commit_for_blob_key(commit_blob_key)
        if commit.nil?
          # Try without stretched encryption key.
          commit_blob_key = BlobKey.new(commit_sha1, STORAGE_S3, true, false)
          commit = repo.commit_for_blob_key(commit_blob_key)
          if commit.nil?
            raise Error.new("error attempting to read commit for #{commit_blob_key}")
          end
        end
      else
        commit_blob_key = repo.head_blob_key
        commit = repo.commit_for_blob_key(commit_blob_key)
      end

      puts "restoring #{commit_sha1.nil? ? "head " : ""} #{commit_blob_key.inspect}"

      #if File.exist? root_path
      #  raise Error.new("#{root_path} already exists")
      #end

      FileUtils.mkdir_p(root_path)

      root_tree = repo.tree_for_blob_key(commit.tree_blob_key)
      restore_tree(root_tree, root_path)
    end

    private

    attr_reader :root_path, :repo, :commit_sha1, :hard_links

    def restore_tree(tree, path)
      $stderr.puts "#{path}/"
      inode = tree.st_ino

      existing = nil
      if tree.st_nlink > 1
        existing = hard_links[inode]
      end
      if existing
        File.link(existing, path)
      else
        FileUtils.mkdir_p(path)
        tree.nodes.each do |node_name, node|
          node_path = File.join(path, node_name)
          if node.tree?
            node_tree = repo.tree_for_blob_key(node.tree_blob_key)
            begin
              restore_tree node_tree, node_path
            rescue => e
              $stderr.puts "  Error: #{e}"
              @errors_by_path[node_path] = e
            end
          else
            begin
              restore_node(node, tree, node_path)
            rescue => e
              @errors_by_path[node_path] = e
              raise
            end
          end
        end

        apply_tree(tree, path)
        hard_links[inode] = path

        if need_super_user_for_tree?(tree)
          @super_user_node_count += 1
        end
      end
    end

    def restore_node(node, tree, path)
      $stderr.puts path
      if node.nil?
        raise Error.new("node can't be nil")
      end
      if tree.nil?
        raise Error.new("tree can't be nil")
      end

      inode = node.st_ino
      existing = nil
      if node.st_nlink > 1
        existing = hard_links[inode]
      end

      if existing
        # Link
        FileUtils.link(existing, path)
      else
        mode = node.mode

        if Stat.is_fifo(mode)
          Stat.mkfifo(path, mode)
        elsif Stat.is_sock(mode)
          # Skip socket -- restoring it doesn't make any sense.
        elsif Stat.is_chr(mode)
          # character device: needs to be done as super-user.
        elsif Stat.is_blk(mode)
          # block device: needs to be done as super-user.
        else
          create_file(node, path)
          apply_node(node, path)
        end

        hard_links[inode] = path

        if need_super_user_for_node?(node, tree)
          @super_user_node_count += 1
        end

      end
    end

    def need_super_user_for_tree?(tree)
      if tree.nil?
        raise Error.new("tree can't be nil")
      end

      (tree.uid != Process.uid) || (tree.gid != Process.gid) ||
        (tree.mode & (Stat::S_ISUID | Stat::S_ISGID | Stat::S_ISVTX)) != 0
    end

    def need_super_user_for_node?(node, tree)
      if node.nil?
        raise Error.new("node can't be nil")
      end
      if tree.nil?
        raise Error.new("tree can't be nil")
      end

      ((tree.version >= 7) && (Stat::is_chr(node.mode) || Stat::is_blk(node.mode))) ||
        (node.uid != Process.uid) || (node.gid != Process.gid) ||
        (node.mode & (Stat::S_ISUID | Stat::S_ISGID | Stat::S_ISVTX)) != 0
    end

    def create_file(node, path)
      FileUtils.mkdir_p(File.dirname(path))

      if File.exist?(path)
        File.delete(path)
      end

      if Stat.is_lnk(node.mode)
        target = node.data_blob_keys.map do |data_blob_key|
          repo.blob_data(data_blob_key)
        end.join('').force_encoding(Encoding::UTF_8)
        create_symlink(node, path, target)
      elsif node.uncompressed_data_size > 0
        create_file_from_blobs(path, node.data_blob_keys)
      else
        File.write(path, '')
      end
    end

    def create_symlink(node, path, target)
      if File.exists?(path)
        File.delete(path)
      end

      File.symlink(target, path)
    end

    def create_file_from_blobs(path, blob_keys)
      File.open(path, 'wb') do |f|
        blob_keys.each do |blob_key|
          f.write repo.server_blob(blob_key).data
        end
      end
    end

    def apply_tree(tree, path)
      $stderr.puts " >> applying tree: #{tree.inspect}"
      fa = FileAttributes.new(path)

      apply_xattrs_blob_key(tree.xattrs_blob_key, tree.xattrs_are_compressed, path)

      fa.apply_finder_flags(tree.finder_flags)

      if (tree.mode & (Stat::S_ISUID | Stat::S_ISGID | Stat::S_ISVTX)) != 0
        fa.apply_mode(tree.mode)
      end

      if tree.version >= 7
        if !Stat.is_lnk(tree.mode)
          fa.apply_mtime(tree.mtime_sec, tree.mtime_nsec)
        end

        fa.apply_ctime(tree.ctime_sec, tree.ctime_nsec)
      end

      fa.apply_flags(tree.flags)

      apply_acl_blob_key(tree.acl_blob_key, tree.acl_is_compressed, path)
    end

    def apply_node(node, path)
      $stderr.puts " >> applying node: #{node.inspect}"
      fa = FileAttributes.new(path)

      apply_xattrs_blob_key(node.xattrs_blob_key, node.xattrs_are_compressed, path)
      apply_acl_blob_key(node.acl_blob_key, node.acl_is_compressed, path)

      if Stat.is_fifo(node.mode)
        fa.apply_finder_flags(node.finder_flags)
        fa.apply_extended_finder_flags(node.extended_finder_flags)
        fa.apply_finder_file_type(node.finder_file_type, node.finder_file_creator)
      end

      if (node.mode & (Stat::S_ISUID | Stat::S_ISGID | Stat::S_ISVTX)) != 0
        fa.apply_mode(node.mode)
      end

      if node.version >= 7
        if !Stat.is_lnk(node.mode)
          fa.apply_mtime(node.mtime_sec, node.mtime_nsec)
        end

        fa.apply_ctime(node.ctime_sec, node.ctime_nsec)
      end

      if !Stat.is_fifo(node.mode)
        fa.apply_flags(node.flags)
      end
    end

    def apply_xattrs_blob_key(xattrs_blob_key, uncompress, path)
      if xattrs_blob_key
        puts "XAttrs blob key: #{xattrs_blob_key.inspect}"
        data = repo.blob_data(xattrs_blob_key)
        if uncompress
          data = Zlib::GzipReader.new(StringIO.new(data)).read
        end

        xattr_set = XAttrSet.new(data)

        xattr_set.apply_to_file(path)
      end
    end

    def apply_acl_blob_key(acl_blob_key, uncompress, path)
      if acl_blob_key
        data = repo.blob_data(acl_blob_key)
        if uncompress
          data = Zlib::GzipReader.new(StringIO.new(data)).read
        end

        ACL.new(data).write(path)
      end
    end
  end
end
