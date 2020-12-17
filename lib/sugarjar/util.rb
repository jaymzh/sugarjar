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
      if %w{diff log grep branch}.include?(args[0]) &&
         args.none? { |x| x.include?('color') }
        args << (@color ? '--color' : '--no-color')
      end
      SugarJar::Log.trace("Running: hub #{args.join(' ')}")
      s = Mixlib::ShellOut.new([which('hub')] + args).run_command
      if s.error?
        # depending on hub version and possibly other things, STDERR
        # is either "Requires authentication" or "Must authenticate"
        case s.stderr
        when /^(Must|Requires) authenticat/
          SugarJar::Log.info(
            'Hub was run but no github token exists. Will run "hub api user" ' +
            "to force\nhub to authenticate...",
          )
          unless system(which('hub'), 'api', 'user')
            SugarJar::Log.fatal(
              'That failed, I will bail out. Hub needs to get a github ' +
              'token. Try running "hub api user" (will list info about ' +
              'your account) and try this again when that works.',
            )
            exit(1)
          end
          SugarJar::Log.info('Re-running original hub command...')
          s = Mixlib::ShellOut.new([which('hub')] + args).run_command
        when /^fatal: could not read Username/
          # On http(s) URLs, git may prompt for username/passwd
          SugarJar::Log.info(
            'Hub was run but git prompted for authentication. This probably ' +
            "means you have\nused an http repo URL instead of an ssh one. It " +
            "is recommended you reclone\nusing 'sj sclone' to setup your " +
            "remotes properly. However, in the meantime,\nwe'll go ahead " +
            "and re-run the command in a shell so you can type in the\n" +
            'credentials.',
          )
          unless system(which('hub'), *args)
            SugarJar::Log.fatal(
              'That failed, I will bail out. You can either manually change ' +
              'your remotes, or simply create a fresh clone with ' +
              '"sj smartclone".',
            )
            exit(1)
          end
          SugarJar::Log.info('Re-running original hub command...')
          s = Mixlib::ShellOut.new([which('hub')] + args).run_command
        end
      end
      s
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
