require 'mixlib/shellout'

require_relative 'log'

class SugarJar
  module Util
    # a mixin to hold stuff that Commands and RepoConfig both use
    def self.which(cmd)
      path = which_nofail(cmd)
      return path if path

      SugarJar::Log.fatal("Could not find #{cmd} in your path")
      exit(1)
    end

    # Finds the first entry in the path for a binary and checks
    # to make sure it's not us. Warn if it is us as that won't work in 2.x
    def self.which_nofail(cmd)
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
        p = File.join(dir, cmd)
        next unless File.exist?(p) && File.executable?(p)

        if File.basename(File.realpath(p)) == 'sj'
          SugarJar::Log.error(
            "'#{cmd}' is linked to 'sj' which is no longer supported.",
          )
          next
        end
        return p
      end
      false
    end
  end
end
