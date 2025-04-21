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

    def self.git_nofail(*args, color: true)
      if %w{diff log grep branch}.include?(args[0]) &&
         args.none? { |x| x.include?('color') }
        args << (color ? '--color' : '--no-color')
      end
      SugarJar::Log.trace("Running: git #{args.join(' ')}")
      Mixlib::ShellOut.new([which('git')] + args).run_command
    end

    def self.git(*args, color: true)
      s = git_nofail(*args, :color => color)
      s.error!
      s
    end

    def self.ghcli_nofail(*args)
      SugarJar::Log.trace("Running: gh #{args.join(' ')}")
      gh = which('gh')
      s = Mixlib::ShellOut.new([gh] + args).run_command
      if s.error? && s.stderr.include?('gh auth')
        SugarJar::Log.info(
          'gh was run but no github token exists. Will run "gh auth login" ' +
          "to force\ngh to authenticate...",
        )
        unless system(gh, 'auth', 'login', '-p', 'ssh')
          SugarJar::Log.fatal(
            'That failed, I will bail out. Hub needs to get a github ' +
            'token. Try running "gh auth login" (will list info about ' +
            'your account) and try this again when that works.',
          )
          exit(1)
        end
      end
      s
    end

    def self.ghcli(*args)
      s = ghcli_nofail(*args)
      s.error!
      s
    end

    def self.in_repo?
      s = git_nofail('rev-parse', '--is-inside-work-tree')
      !s.error? && s.stdout.strip == 'true'
    end

    def self.repo_root
      git('rev-parse', '--show-toplevel').stdout.strip
    end
  end
end
