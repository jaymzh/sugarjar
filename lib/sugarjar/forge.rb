require 'mixlib/shellout'
require_relative 'util'
require_relative 'log'

class SugarJar
  class Forge
    attr_reader :type

    CMD_MAP = {
      'github' => 'gh',
      'gitlab' => 'glab',
      'forgejo' => 'fj',
    }.freeze

    def initialize(type)
      @type = type
      assert_cli_avail!
    end

    def cmd
      @cmd ||= CMD_MAP[@type]
    end

    def all_versions
      CMD_MAP.values.map do |cli|
        bin = SugarJar::Util.which_nofail(cli)
        _forge_nofail(cli, 'version').stdout if bin
      end.compact
    end

    def run_nofail(*)
      _forge_nofail(cmd, *)
    end

    def run(*)
      s = _forge_nofail(cmd, *)
      s.error!
      s
    end

    def run_with_system(*)
      system(cmd, *)
    end

    private

    def _forge_nofail(cli, *args)
      SugarJar::Log.trace("Running: #{cli} #{args.join(' ')}")
      bin = SugarJar::Util.which_nofail(cli)
      s = Mixlib::ShellOut.new([bin] + args).run_command
      if s.error? && s.stderr.include?("#{cli} auth")
        SugarJar::Log.info(
          'glab was run but no gitlab token exists. Will run ' +
          '"glab auth login" to force\ngh to authenticate...',
        )
        unless system(bin, 'auth', 'login', '-p', 'ssh')
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

    def assert_cli_avail!
      return if SugarJar::Util.which_nofail(cmd)

      SugarJar::Log.error(
        "Forge CLI #{cmd} is unavailable, please install",
      )
      exit 1
    end
  end
end
