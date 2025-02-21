require 'mixlib/shellout'

require_relative 'util'
require_relative 'repoconfig'
require_relative 'log'
require_relative 'version'
require_relative 'commands/amend'
require_relative 'commands/bclean'
require_relative 'commands/branch'
require_relative 'commands/checks'
require_relative 'commands/feature'
require_relative 'commands/pullsuggestions'
require_relative 'commands/push'
require_relative 'commands/smartclone'
require_relative 'commands/smartpullrequest'
require_relative 'commands/up'
require_relative 'commands/version'

class SugarJar
  # This is the workhorse of SugarJar. Short of #initialize, all other public
  # methods are "commands". Anything in private is internal implementation
  # details.
  class Commands
    include SugarJar::Util

    MAIN_BRANCHES = %w{master main}.freeze

    def initialize(options)
      SugarJar::Log.debug("Commands.initialize options: #{options}")
      @ghuser = options['github_user']
      @ghhost = options['github_host']
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
      return if options['no_change']

      # technically this doesn't "change" things, but we won't have this
      # option on the no_change call
      @cli = determine_cli(options['github_cli'])

      set_hub_host
      set_commit_template if @repo_config['commit_template']
    end

    private

    def rebase
      SugarJar::Log.debug('Fetching upstream')
      fetch_upstream
      curr = current_branch
      # this isn't a hash, it's a named param, silly rubocop
      # rubocop:disable Style/HashSyntax
      base = tracked_branch(fallback: false)
      # rubocop:enable Style/HashSyntax
      unless base
        SugarJar::Log.info(
          'The brach we were tracking is gone, resetting tracking to ' +
          most_main,
        )
        git('branch', '-u', most_main)
        base = most_main
      end
      # If this is a subfeature based on a local branch which has since
      # been deleted, 'tracked branch' will automatically return <most_main>
      # so we don't need any special handling for that
      if !MAIN_BRANCHES.include?(curr) && base == "origin/#{curr}"
        SugarJar::Log.warn(
          "This branch is tracking origin/#{curr}, which is probably your " +
          'downstream (where you push _to_) as opposed to your upstream ' +
          '(where you pull _from_). This means that "sj up" is probably ' +
          'rebasing on the wrong thing and doing nothing. You probably want ' +
          "to do a 'git branch -u #{most_main}'.",
        )
      end
      SugarJar::Log.debug('Rebasing')
      s = git_nofail('rebase', base)
      {
        'so' => s,
        'base' => base,
      }
    end

    def rebase_in_progress?
      # for rebase without -i
      rebase_file = git('rev-parse', '--git-path', 'rebase-apply').stdout.strip
      # for rebase -i
      rebase_merge_file = git('rev-parse', '--git-path', 'rebase-merge').
                          stdout.strip
      File.exist?(rebase_file) || File.exist?(rebase_merge_file)
    end

    def fprefix(name)
      return name unless @feature_prefix

      return name if name.start_with?(@feature_prefix)
      return name if all_local_branches.include?(name)

      newname = "#{@feature_prefix}#{name}"
      SugarJar::Log.debug(
        "Munging feature name: #{name} -> #{newname} due to feature prefix",
      )
      newname
    end

    def extract_org(repo)
      if repo.start_with?('http')
        File.basename(File.dirname(repo))
      elsif repo.start_with?('git@')
        repo.split(':')[1].split('/')[0]
      else
        # assume they passed in a hub-friendly name
        repo.split('/').first
      end
    end

    def extract_repo(repo)
      File.basename(repo, '.git')
    end

    def forked_repo(repo, username)
      repo = if repo.start_with?('http', 'git@')
               File.basename(repo)
             else
               "#{File.basename(repo)}.git"
             end
      "git@#{@ghhost || 'github.com'}:#{username}/#{repo}"
    end

    # Hub will default to https, but we should always default to SSH
    # unless otherwise specified since https will cause prompting.
    def canonicalize_repo(repo)
      # if they fully-qualified it, we're good
      return repo if repo.start_with?('http', 'git@')

      # otherwise, ti's a shortname
      cr = "git@#{@ghhost || 'github.com'}:#{repo}.git"
      SugarJar::Log.debug("canonicalized #{repo} to #{cr}")
      cr
    end

    def set_hub_host
      return unless hub? && in_repo && @ghhost

      s = git_nofail('config', '--local', '--get', 'hub.host')
      if s.error?
        SugarJar::Log.info("Setting repo hub.host = #{@ghhost}")
      else
        current = s.stdout
        if current == @ghhost
          SugarJar::Log.debug('Repo hub.host already set correctly')
        else
          # Even though we have an explicit config, in most cases, it
          # comes from a global or user config, but the config in the
          # local repo we likely set. So we'd just constantly revert that.
          SugarJar::Log.debug(
            "Not overwriting repo hub.host. Already set to #{current}. " +
            "To change it, run `git config --local --add hub.host #{@ghhost}`",
          )
        end
        return
      end
      git('config', '--local', '--add', 'hub.host', @ghhost)
    end

    def set_commit_template
      unless in_repo
        SugarJar::Log.debug('Skipping set_commit_template: not in repo')
        return
      end

      realpath = if @repo_config['commit_template'].start_with?('/')
                   @repo_config['commit_template']
                 else
                   "#{repo_root}/#{@repo_config['commit_template']}"
                 end
      unless File.exist?(realpath)
        die(
          "Repo config specifies #{@repo_config['commit_template']} as the " +
          'commit template, but that file does not exist.',
        )
      end

      s = git_nofail('config', '--local', 'commit.template')
      unless s.error?
        current = s.stdout.strip
        if current == @repo_config['commit_template']
          SugarJar::Log.debug('Commit template already set correctly')
          return
        else
          SugarJar::Log.warn(
            "Updating repo-specific commit template from #{current} " +
            "to #{@repo_config['commit_template']}",
          )
        end
      end

      SugarJar::Log.debug(
        'Setting repo-specific commit template to ' +
        "#{@repo_config['commit_template']} per sugarjar repo config.",
      )
      git(
        'config', '--local', 'commit.template', @repo_config['commit_template']
      )
    end

    def run_prepush
      @repo_config['on_push']&.each do |item|
        SugarJar::Log.debug("Running on_push check type #{item}")
        unless send(:run_check, item)
          SugarJar::Log.info("[prepush]: #{item} #{color('failed', :red)}.")
          return false
        end
      end
      true
    end

    def die(msg)
      SugarJar::Log.fatal(msg)
      exit(1)
    end

    def assert_common_main_branch
      upstream_branch = main_remote_branch(upstream)
      unless main_branch == upstream_branch
        die(
          "The local main branch is '#{main_branch}', but the main branch " +
          "of the #{upstream} remote is '#{upstream_branch}'. You probably " +
          "want to rename your local branch by doing:\n\t" +
          "git branch -m #{main_branch} #{upstream_branch}\n\t" +
          "git fetch #{upstream}\n\t" +
          "git branch -u #{upstream}/#{upstream_branch} #{upstream_branch}\n" +
          "\tgit remote set-head #{upstream} -a",
        )
      end
      return if upstream_branch == 'origin'

      origin_branch = main_remote_branch('origin')
      return if origin_branch == upstream_branch

      die(
        "The main branch of your upstream (#{upstream_branch}) and your " +
        "fork/origin (#{origin_branch}) are not the same. You should go " +
        "to https://#{@ghhost || 'github.com'}/#{@ghuser}/#{repo_name}/" +
        'branches/ and rename the \'default\' branch to ' +
        "'#{upstream_branch}'. It will then give you some commands to " +
        'run to update this clone.',
      )
    end

    def assert_in_repo
      die('sugarjar must be run from inside a git repo') unless in_repo
    end

    def determine_main_branch(branches)
      branches.include?('main') ? 'main' : 'master'
    end

    def main_branch
      @main_branch = determine_main_branch(all_local_branches)
    end

    def main_remote_branch(remote)
      @main_remote_branches[remote] ||=
        determine_main_branch(all_remote_branches(remote))
    end

    def checkout_main_branch
      git('checkout', main_branch)
    end

    def all_remote_branches(remote = 'origin')
      branches = []
      git('branch', '-r', '--format', '%(refname)').stdout.lines.each do |line|
        next unless line.start_with?("refs/remotes/#{remote}/")

        branches << branch_from_ref(line.strip, :remote)
      end
      branches
    end

    def all_local_branches
      git(
        'branch', '--format', '%(refname)'
      ).stdout.lines.map do |line|
        branch_from_ref(line.strip)
      end
    end

    def all_remotes
      git('remote').stdout.lines.map(&:strip)
    end

    def current_branch
      branch_from_ref(git('symbolic-ref', 'HEAD').stdout.strip)
    end

    def fetch_upstream
      us = upstream
      fetch(us) if us
    end

    def fetch(remote)
      git('fetch', remote)
    end

    # determine if this branch is based on another local branch (i.e. is a
    # subfeature). Used to figure out of we should stack the PR
    def subfeature?(base)
      all_local_branches.reject { |x| x == most_main }.include?(base)
    end

    def tracked_branch(fallback: true)
      branch = nil
      s = git_nofail(
        'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'
      )
      if s.error?
        branch = fallback ? most_main : nil
        SugarJar::Log.debug("No specific tracked branch, using #{branch}")
      else
        branch = s.stdout.strip
        SugarJar::Log.debug(
          "Using explicit tracked branch: #{branch}, use " +
          '`git branch -u` to change',
        )
      end
      branch
    end

    def most_main
      us = upstream
      if us
        "#{us}/#{main_branch}"
      else
        main_branch
      end
    end

    def upstream
      return @remote if @remote

      remotes = all_remotes
      SugarJar::Log.debug("remotes is #{remotes}")
      if remotes.empty?
        @remote = nil
      elsif remotes.length == 1
        @remote = remotes[0]
      elsif remotes.include?('upstream')
        @remote = 'upstream'
      elsif remotes.include?('origin')
        @remote = 'origin'
      else
        raise 'Could not determine "upstream" remote to use...'
      end
      @remote
    end

    # Whatever org we push to, regardless of if this is a fork or not
    def push_org
      url = git('remote', 'get-url', 'origin').stdout.strip
      extract_org(url)
    end

    def branch_from_ref(ref, type = :local)
      # local branches are refs/head/XXXX
      # remote branches are refs/remotes/<remote>/XXXX
      base = type == :local ? 2 : 3
      ref.split('/')[base..].join('/')
    end

    def color(string, *colors)
      if @color
        pastel.decorate(string, *colors)
      else
        string
      end
    end

    def pastel
      @pastel ||= begin
        require 'pastel'
        Pastel.new
      end
    end

    def determine_cli(cli)
      return cli if %w{gh hub}.include?(cli)

      die("'github_cli' has unknown setting: #{cli}") unless cli == 'auto'

      SugarJar::Log.debug('github_cli set to auto')

      if which_nofail('gh')
        SugarJar::Log.debug('Found "gh"')
        return 'gh'
      end
      if which_nofail('hub')
        SugarJar::Log.debug('Did not find "gh" but did find "hub"')
        return 'hub'
      end

      die(
        'Neither "gh" nor "hub" found in PATH, please ensure at least one ' +
        'of these utilities is in the PATH. If both are available you can ' +
        'specify which to use with --github-cli',
      )
    end

    def hub?
      @cli == 'hub'
    end

    def gh?
      @cli == 'gh'
    end

    def ghcli_nofail(*args)
      gh? ? gh_nofail(*args) : hub_nofail(*args)
    end

    def ghcli(*args)
      gh? ? gh(*args) : hub(*args)
    end
  end
end
