require_relative 'log'

class SugarJar
  # Some common methods needed by other classes
  module Util
    def hub_nofail(*args)
      SugarJar::Log.trace("Running: hub #{args.join(' ')}")
      Mixlib::ShellOut.new(['/usr/bin/hub'] + args).run_command
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
