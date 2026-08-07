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

    def initialize(type, host)
      @type = type
      @host = host
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

    def run_with_system(*args)
      SugarJar::Log.trace("Running: #{cmd} #{args.join(' ')}")
      system(cmd, *args)
    end

    private

    def _forge_nofail(cli, *args)
      SugarJar::Log.trace("Running: #{cli} #{args.join(' ')}")
      bin = SugarJar::Util.which_nofail(cli)
      s = Mixlib::ShellOut.new([bin] + args).run_command
      if s.error? && ["#{cli} auth", 'Unauthorized'].any? do |err|
        s.stderr.include?(err)
      end
        SugarJar::Log.info(
          "#{cli} was run but no gitlab token exists. Will run " +
          "'#{cli} auth login' to force\n#{cli} to authenticate...",
        )
        args = if cli == 'fj'
                 [bin, '-H', @host, 'auth', 'login']
               else
                 [bin, 'auth', 'login', '-p', 'ssh']
               end
        unless system(*args)
          SugarJar::Log.fatal(
            "That failed, I will bail out. #{cli} needs to get a " +
            "token. Try running '#{cli} auth login' (will list info about " +
            'your account) and try this again when that works.',
          )
          exit(1)
        end

        if cli == 'fj'
          fj = Mixlib::ShellOut.new([bin, 'auth', 'list']).run_command
          unless fj.stdout.include?(@host)
            SugarJar::Log.fatal(
              'Logging in for you failed - this usually means you need to ' +
              'create a token manually - the instructions should have been ' +
              'printed above. Setup the token and then try again.',
            )
            exit(1)
          end
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
