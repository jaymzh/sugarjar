require 'mixlib/shellout'

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
require_relative 'log'
require_relative 'repoconfig'
require_relative 'util'
require_relative 'version'

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

    private

    def forked_repo(repo, username)
      repo = if repo.start_with?('http', 'git@')
               File.basename(repo)
             else
               "#{File.basename(repo)}.git"
             end
      "git@#{@ghhost || 'github.com'}:#{username}/#{repo}"
    end

    # gh utils will default to https, but we should always default to SSH
    # unless otherwise specified since https will cause prompting.
    def canonicalize_repo(repo)
      # if they fully-qualified it, we're good
      return repo if repo.start_with?('http', 'git@')

      # otherwise, ti's a shortname
      cr = "git@#{@ghhost || 'github.com'}:#{repo}.git"
      SugarJar::Log.debug("canonicalized #{repo} to #{cr}")
      cr
    end

    def set_commit_template
      unless SugarJar::Util.in_repo?
        SugarJar::Log.debug('Skipping set_commit_template: not in repo')
        return
      end

      realpath = if @repo_config['commit_template'].start_with?('/')
                   @repo_config['commit_template']
                 else
                   "#{Util.repo_root}/#{@repo_config['commit_template']}"
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

    def assert_in_repo!
      return if SugarJar::Util.in_repo?

      die('sugarjar must be run from inside a git repo')
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
        next if line.start_with?('(HEAD detached')

        branch_from_ref(line.strip)
      end
    end

    def all_remotes
      git('remote').stdout.lines.map(&:strip)
    end

    def remote_url_map
      m = {}
      git('remote', '-v').stdout.each_line do |line|
        name, url, = line.split
        m[name] = url
      end
      m
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

    def upstream_org
      us = upstream
      remotes = remote_url_map
      extract_org(remotes[us])
    end

    # Whatever org we push to, regardless of if this is a fork or not
    def push_org
      url = git('remote', 'get-url', 'origin').stdout.strip
      extract_org(url)
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

    def gh_avail?
      !!SugarJar::Util.which_nofail('gh')
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

    def dirty?
      s = git_nofail('diff', '--quiet')
      s.error?
    end

    def repo_name
      SugarJar::Util.repo_root.split('/').last
    end

    def extract_org(repo)
      if repo.start_with?('http')
        File.basename(File.dirname(repo))
      elsif repo.start_with?('git@')
        repo.split(':')[1].split('/')[0]
      else
        # assume they passed in a ghcli-friendly name
        repo.split('/').first
      end
    end

    def extract_repo(repo)
      File.basename(repo, '.git')
    end

    def die(msg)
      SugarJar::Log.fatal(msg)
      exit(1)
    end

    def worktree_branches
      worktrees.values.map do |wt|
        branch_from_ref(wt['branch'])
      end
    end

    def worktrees
      root = SugarJar::Util.repo_root
      s = git('worktree', 'list', '--porcelain')
      s.error!
      worktrees = {}
      # each entry is separated by a double newline
      s.stdout.split("\n\n").each do |entry|
        # then each key/val is split by a new line with the key and
        # the value themselves split by a whitespace
        tree = entry.split("\n").to_h(&:split)
        # Skip the one
        next if tree['worktree'] == root

        worktrees[tree['worktree']] = tree
      end
      worktrees
    end

    def branch_from_ref(ref, type = :local)
      # local branches are refs/head/XXXX
      # remote branches are refs/remotes/<remote>/XXXX
      base = type == :local ? 2 : 3
      ref.split('/')[base..].join('/')
    end

    def git(*)
      SugarJar::Util.git(*, :color => @color)
    end

    def git_nofail(*)
      SugarJar::Util.git_nofail(*, :color => @color)
    end

    def ghcli(*)
      SugarJar::Util.ghcli(*)
    end

    def ghcli_nofail(*)
      SugarJar::Util.ghcli_nofail(*)
    end
  end
end
