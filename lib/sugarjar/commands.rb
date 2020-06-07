require_relative 'util'
require_relative 'repoconfig'
require_relative 'log'
require_relative 'version'

class SugarJar
  # This is the workhorse of SugarJar. Short of #initialize, all other public
  # methods are "commands". Anything in private is internal implementation
  # details.
  class Commands
    include SugarJar::Util

    def initialize(options)
      @ghuser = options['github_user']
      @ghhost = options['github_host']
      @repo_config = SugarJar::RepoConfig.config
      set_hub_host if @ghhost
    end

    def feature(name, base = nil)
      assert_in_repo
      SugarJar::Log.debug("Feature: #{name}, #{base}")
      die("#{name} already exists!") if all_branches.include?(name)
      base ||= most_master
      base_pieces = base.split('/')
      hub('fetch', base_pieces[0]) if base_pieces.length > 1
      hub('checkout', '-b', name, base)
      SugarJar::Log.info("Created feature branch #{name} based on #{base}")
    end

    def bclean(name = nil)
      assert_in_repo
      name ||= current_branch
      # rubocop:disable Style/GuardClause
      unless clean_branch(name)
        die("Cannot clean #{name} - there are unmerged commits")
      end
      # rubocop:enable Style/GuardClause
    end

    def bcleanall
      assert_in_repo
      all_branches.each do |branch|
        next if branch == 'master'

        # rubocop:disable Style/Next
        unless clean_branch(branch)
          SugarJar::Log.info(
            "Skipping branch #{branch} - there are unmerged commits",
          )
        end
        # rubocop:enable Style/Next
      end
    end

    def co(*args)
      assert_in_repo
      hub('checkout', *args)
    end

    def br
      assert_in_repo
      puts hub('branch', '-v').stdout
    end

    def binfo
      assert_in_repo
      SugarJar::Log.info(hub(
        'log', '--graph', '--oneline', '--decorate', '--boundary',
        "#{tracked_branch}.."
      ).stdout)
    end

    def up
      assert_in_repo
      result = gitup
      if result
        SugarJar::Log.info("Rebased branch on #{result}")
      else
        die('Failed to rebase current branch')
      end
    end

    def amend(*args)
      assert_in_repo
      # This cannot use shellout since we need a full terminal for the editor
      exit(system(which('git'), 'commit', '--amend', *args))
    end

    def qamend(*args)
      assert_in_repo
      SugarJar::Log.info(hub('commit', '--amend', '--no-edit', *args).stdout)
    end

    alias amendq qamend

    def upall
      assert_in_repo
      all_branches.each do |branch|
        next if branch == 'master'

        hub('checkout', branch)
        result = gitup
        if result
          SugarJar::Log.info("Rebased #{branch} on #{result}")
        else
          SugarJar::Log.error(
            "Failed to rebase #{branch}, aborting that and moving to next " +
            'branch',
          )
          hub('rebase', '--abort')
        end
      end
    end

    def smartclone(repo, dir = nil, *args)
      # If the user has specified a hub host, set the environment variable
      # since we don't have a repo to configure yet
      ENV['GITHUB_HOST'] = @ghhost if @ghhost

      reponame = File.basename(repo, '.git')
      dir ||= reponame
      SugarJar::Log.info("Cloning #{reponame}...")
      hub('clone', repo, dir, *args)

      Dir.chdir dir do
        # Now that we have a repo, if we have a hub host set it.
        set_hub_host if @ghhost

        org = File.basename(File.dirname(repo))
        if org == @ghuser
          put 'Cloned forked or self-owned repo. Not creating "upstream".'
          return
        end

        s = hub_nofail('fork', '--remote-name=origin')
        if s.error?
          # if the fork command failed, we already have one, so we have
          # to swap the remote names ourselves
          SugarJar::Log.info("Fork (#{@ghuser}/#{reponame}) detected.")
          hub('remote', 'rename', 'origin', 'upstream')
          hub('remote', 'add', 'origin', repo.gsub("#{org}/", "#{@ghuser}/"))
        else
          SugarJar::Log.info("Forked #{reponame} to #{@ghuser}")
        end
        SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
      end
    end

    alias sclone smartclone

    def lint
      exit(1) unless run_check('lint')
    end

    def unit
      exit(1) unless run_check('lint')
    end

    def smartpush(remote = nil, branch = nil)
      unless remote && branch
        remote ||= 'origin'
        branch ||= current_branch
      end

      if run_prepush
        puts hub('push', remote, branch).stderr
      else
        SugarJar::Log.error('Pre-push checks failed. Not pushing.')
      end
    end

    alias spush smartpush

    def forcepush(remote = nil, branch = nil)
      unless remote && branch
        remote ||= 'origin'
        branch ||= current_branch
      end
      if run_prepush
        puts hub('push', '--force-with-lease', remote, branch).stderr
      else
        SugarJar::Log.error('Pre-push checks failed. Not pushing.')
      end
    end

    alias fpush forcepush

    def version
      puts "sugarjar version #{SugarJar::VERSION}"
      puts hub('version').stdout
    end

    private

    def set_hub_host
      return unless in_repo

      s = hub_nofail('config', '--local', '--get', 'hub.host')
      if s.error?
        SugarJar::Log.info("Setting repo hub.host = #{@ghhost}")
      else
        current = s.stdout
        if current == @ghost
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
      hub('config', '--local', '--add', 'hub.host', @ghhost)
    end

    def run_check(type)
      unless @repo_config[type]
        SugarJar::Log.debug("No #{type} configured. Returning success")
        return true
      end
      Dir.chdir repo_root do
        @repo_config[type].each do |check|
          SugarJar::Log.info("Running #{type} #{check}")

          unless File.exist?(check)
            SugarJar::Log.error("Configured #{type} #{check} does not exist!")
            return false
          end
          s = Mixlib::ShellOut.new(check).run_command
          if s.error?
            SugarJar::Log.info("#{type} #{check} failed\n#{s.stdout}")
            return false
          end
        end
      end
    end

    def run_prepush
      @repo_config['on_push'].each do |item|
        SugarJar::Log.debug("Running on_push check type #{item}")
        unless send(:run_check, item)
          SugarJar::Log.info("Push check #{item} failed.")
          return false
        end
      end
      true
    end

    def die(msg)
      SugarJar::Log.fatal(msg)
      exit(1)
    end

    def assert_in_repo
      die('sugarjar must be run from inside a git repo') unless in_repo
    end

    def clean_branch(name)
      die('Cannot remove master branch') if name == 'master'
      SugarJar::Log.debug('Fetch relevant remote...')
      fetch_upstream
      return false unless safe_to_clean(name)

      SugarJar::Log.debug('branch deemed safe to delete...')
      hub('checkout', 'master')
      hub('branch', '-D', name)
      gitup
      SugarJar::Log.info("Reaped branch #{name}")
      true
    end

    def all_branches
      branches = []
      hub('branch', '--format', '%(refname)').stdout.lines.each do |line|
        next if line == 'master'

        branches << line.strip.split('/')[2]
      end
      branches
    end

    def safe_to_clean(branch)
      # cherry -v will output 1 line per commit on the target branch
      # prefixed by a - or + - anything with a - can be dropped, anything
      # else cannot.
      out = hub(
        'cherry', '-v', tracked_branch, branch
      ).stdout.lines.reject do |line|
        line.start_with?('-')
      end
      if out.length.zero?
        SugarJar::Log.debug(
          "cherry-pick shows branch #{branch} obviously safe to delete",
        )
        return true
      end

      # if the "easy" check didn't work, it's probably because there
      # was a squash-merge. To check for that we make our own squash
      # merge to upstream/master and see if that has any delta

      # First we need a temp branch to work on
      tmpbranch = "_sugar_jar.#{Process.pid}"

      hub('checkout', '-b', tmpbranch, tracked_branch)
      s = hub_nofail('merge', '--squash', branch)
      if s.error?
        cleanup_tmp_branch(tmpbranch, branch)
        SugarJar::Log.error(
          'Failed to merge changes into current master. This means we could ' +
          'not figure out if this is merged or not. Check manually and use ' +
          "'git branch -D #{branch}' if it is safe to do so.",
        )
        return false
      end

      s = hub('diff', '--staged')
      out = s.stdout
      SugarJar::Log.debug("Squash-merged diff: #{out}")
      cleanup_tmp_branch(tmpbranch, branch)
      if out.empty?
        SugarJar::Log.debug(
          'After squash-merging, this branch appears safe to delete',
        )
        true
      else
        SugarJar::Log.debug(
          'After squash-merging, this branch is NOT fully merged to master',
        )
        false
      end
    end

    def cleanup_tmp_branch(tmp, backto)
      hub('reset', '--hard', tracked_branch)
      hub('checkout', backto)
      hub('branch', '-D', tmp)
    end

    def current_branch
      hub('symbolic-ref', 'HEAD').stdout.strip.split('/')[2]
    end

    def fetch_upstream
      us = upstream
      hub('fetch', us) if us
    end

    def gitup
      SugarJar::Log.debug('Fetching upstream')
      fetch_upstream
      SugarJar::Log.debug('Rebasing')
      base = tracked_branch
      s = hub_nofail('rebase', base)
      s.error? ? nil : base
    end

    def tracked_branch
      s = hub_nofail(
        'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'
      )
      if s.error?
        most_master
      else
        s.stdout.strip
      end
    end

    def most_master
      us = upstream
      if us
        "#{us}/master"
      else
        master
      end
    end

    def upstream
      return @remote if @remote

      s = hub('remote')

      remotes = s.stdout.lines.map(&:strip)
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
  end
end
