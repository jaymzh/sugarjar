require 'mixlib/shellout'

require_relative 'util'
require_relative 'repoconfig'
require_relative 'log'
require_relative 'version'
require_relative 'commands/amend'
require_relative 'commands/bclean'
require_relative 'commands/branch'
require_relative 'commands/checks'
require_relative 'commands/debuginfo'
require_relative 'commands/feature'
require_relative 'commands/pullsuggestions'
require_relative 'commands/push'
require_relative 'commands/smartclone'
require_relative 'commands/smartpullrequest'
require_relative 'commands/up'

class SugarJar
  # This is the workhorse of SugarJar. Short of #initialize, all other public
  # methods are "commands". Anything in private is internal implementation
  # details.
  class Commands
    MAIN_BRANCHES = %w{master main}.freeze

    def initialize(options)
      SugarJar::Log.debug("Commands.initialize options: #{options}")
      @ignore_dirty = options['ignore_dirty']
      @ignore_prerun_failure = options['ignore_prerun_failure']
      @repo_config = SugarJar::RepoConfig.config
      SugarJar::Log.debug("Repoconfig: #{@repo_config}")
      @color = options['color']
      @pr_autofill = options['pr_autofill']
      @pr_autostack = options['pr_autostack']
      @feature_prefix = options['feature_prefix']
      @checks = {}
      @main_branch = nil
      @main_remote_branches = {}
      @ghuser = @repo_config['github_user'] || options['github_user']
      @ghhost = @repo_config['github_host'] || options['github_host']

      die("No 'gh' found, please install 'gh'") unless gh_avail?

      # Tell the 'gh' cli where to talk to, if not github.com
      ENV['GH_HOST'] = @ghhost if @ghhost

      return if options['no_change']

      set_commit_template if @repo_config['commit_template']
    end

    include SugarJar::Util
  end
end
