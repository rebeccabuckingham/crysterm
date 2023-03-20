module Crysterm
  # Mixin containing helper functions
  module Helpers
    # Sorts array alphabetically by property 'name'.
    def asort(obj)
      obj.sort do |a, b|
        a = a.not_nil!.name.not_nil!.downcase
        b = b.not_nil!.name.not_nil!.downcase

        if ((a[0] == '.') && (b[0] == '.'))
          a = a[1]
          b = b[1]
        else
          a = a[0]
          b = b[0]
        end

        a > b ? 1 : (a < b ? -1 : 0)
      end
    end

    # Sorts array numerically by property 'index'
    def hsort(obj)
      obj.sort do |a, b|
        b.index - a.index
      end
    end

    # Finds a file with name 'target' inside toplevel directory 'start'.
    # XXX Possibly replace with github: mlobl/finder
    def find_file(start, target)
      if start == "/dev" || start == "/sys" || start == "/proc" || start == "/net"
        return nil
      end
      files = begin
        # https://github.com/crystal-lang/crystal/issues/4807
        Dir.children start
      rescue e : Exception
        [] of String
      end
      files.each do |file|
        full = File.join start, file
        if file == target
          return full
        end
        stat = begin
          File.info full, follow_symlinks: false
        rescue e : Exception
          nil
        end
        if stat && stat.directory? && !stat.symlink?
          f = find_file full, target
          if f
            return f
          end
        end
      end
      nil
    end

    private def find(prefix, word)
      w0 = word[0].to_s
      file = File.join(prefix, w0)
      begin
        File.info(file) # Test existence basically. # XXX needs to be replaced with if( -e FILE), in multiple places
        return file
      rescue e : Exception
      end

      ch = w0.char_at(0).to_s
      if (ch.size < 2)
        ch = "0" + ch
      end

      # XXX path.resolve
      file = File.join(prefix, ch)
      begin
        File.info(file)
        return file
      rescue e : Exception
      end

      nil
    end
  end
end
