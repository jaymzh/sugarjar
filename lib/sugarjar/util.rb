require_relative 'log'

class SugarJar
  # Some common methods needed by other classes
  module Util
    # Finds the first entry in the path for a binary and checks
    # to make sure it's not us (i.e. we may be linked to as 'git'
    # or 'hub', but when we are calling that, we don't want ourselves.
    def which_nofail(cmd)
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
        p = File.join(dir, cmd)
        # if it exists, and it is executable and is not us...
        if File.exist?(p) && File.executable?(p) &&
           File.basename(File.realpath(p)) != 'sj'
          return p
        end
      end
      false
    end

    def which(cmd)
      path = which_nofail(cmd)
      return path if path

      SugarJar::Log.fatal("Could not find #{cmd} in your path")
      exit(1)
    end

    def hub_nofail(*args)
      SugarJar::Log.trace("Running: hub #{args.join(' ')}")
      Mixlib::ShellOut.new([which('hub')] + args).run_command
    end

    def hub(*args)
      s = hub_nofail(*args)
      s.error!
      s
    end

    def in_repo
      s = hub_nofail('rev-parse', '--is-inside-work-tree')
      !s.error? && s.stdout.strip == 'true'
    end

    def repo_root
      hub('rev-parse', '--show-toplevel').stdout.strip
    end
  end
end
