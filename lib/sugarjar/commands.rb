require 'mixlib/shellout'

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
      SugarJar::Log.debug("Commands.initialize options: #{options}")
      @ghuser = options['github_user']
      @ghhost = options['github_host']
      @ignore_dirty = options['ignore_dirty']
      @ignore_prerun_failure = options['ignore_prerun_failure']
      @repo_config = SugarJar::RepoConfig.config
      @color = options['color']
      return if options['no_change']

      set_hub_host if @ghhost
      set_commit_template if @repo_config['commit_template']
    end

    def feature(name, base = nil)
      assert_in_repo
      SugarJar::Log.debug("Feature: #{name}, #{base}")
      die("#{name} already exists!") if all_branches.include?(name)
      base ||= most_master
      base_pieces = base.split('/')
      hub('fetch', base_pieces[0]) if base_pieces.length > 1
      hub('checkout', '-b', name, base)
      SugarJar::Log.info(
        "Created feature branch #{color(name, :green)} based on " +
        color(base, :green),
      )
    end

    def bclean(name = nil)
      assert_in_repo
      name ||= current_branch
      if clean_branch(name)
        SugarJar::Log.info("#{name}: #{color('reaped', :green)}")
      else
        die(
          "#{color("Cannot clean #{name}", :red)}! there are unmerged " +
          "commits; use 'git branch -D #{name}' to forcefully delete it.",
        )
      end
    end

    def bcleanall
      assert_in_repo
      curr = current_branch
      all_branches.each do |branch|
        if branch == 'master'
          SugarJar::Log.debug('Skipping master')
          next
        end

        if clean_branch(branch)
          SugarJar::Log.info("#{branch}: #{color('reaped', :green)}")
        else
          SugarJar::Log.info("#{branch}: skipped")
          SugarJar::Log.debug(
            "There are unmerged commits; use 'git branch -D #{branch}' to " +
            'forcefully delete it)',
          )
        end
      end

      # Return to the branch we were on, or master
      if all_branches.include?(curr)
        hub('checkout', curr)
      else
        hub('checkout', 'master')
      end
    end

    def co(*args)
      assert_in_repo
      s = hub('checkout', *args)
      SugarJar::Log.info(s.stderr + s.stdout.chomp)
    end

    def br
      assert_in_repo
      SugarJar::Log.info(hub('branch', '-v').stdout.chomp)
    end

    def binfo
      assert_in_repo
      SugarJar::Log.info(hub(
        'log', '--graph', '--oneline', '--decorate', '--boundary',
        "#{tracked_branch}.."
      ).stdout.chomp)
    end

    # binfo for all branches
    def smartlog
      assert_in_repo
      SugarJar::Log.info(hub(
        'log', '--graph', '--oneline', '--decorate', '--boundary',
        '--branches', "#{most_master}.."
      ).stdout.chomp)
    end

    alias sl smartlog

    def up
      assert_in_repo
      result = gitup
      if result
        SugarJar::Log.info(
          "#{color(current_branch, :green)} rebased on #{result}",
        )
      else
        die("#{color(current_branch, :red)}: Failed to rebase")
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
          SugarJar::Log.info(
            "#{color(branch, :green)} rebased on #{color(result, :green)}",
          )
        else
          SugarJar::Log.error(
            "#{color(branch, :red)} failed rebase. Reverting attempt and " +
            'moving to next branch',
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
      hub('clone', canonicalize_repo(repo), dir, *args)

      Dir.chdir dir do
        # Now that we have a repo, if we have a hub host set it.
        set_hub_host if @ghhost

        org = extract_org(repo)
        SugarJar::Log.debug("Comparing org #{org} to ghuser #{@ghuser}")
        if org == @ghuser
          puts 'Cloned forked or self-owned repo. Not creating "upstream".'
          return
        end

        s = hub_nofail('fork', '--remote-name=origin')
        if s.error?
          # if the fork command failed, we already have one, so we have
          # to swap the remote names ourselves
          # newer 'hub's don't fail and do the right thing...
          SugarJar::Log.info("Fork (#{@ghuser}/#{reponame}) detected.")
          hub('remote', 'rename', 'origin', 'upstream')
          hub('remote', 'add', 'origin', forked_repo(repo, @ghuser))
        else
          SugarJar::Log.info("Forked #{reponame} to #{@ghuser}")
        end
        SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
      end
    end

    alias sclone smartclone

    def lint
      assert_in_repo
      exit(1) unless run_check('lint')
    end

    def unit
      assert_in_repo
      exit(1) unless run_check('unit')
    end

    def smartpush(remote = nil, branch = nil)
      assert_in_repo
      _smartpush(remote, branch, false)
    end

    alias spush smartpush

    def forcepush(remote = nil, branch = nil)
      assert_in_repo
      _smartpush(remote, branch, true)
    end

    alias fpush forcepush

    def version
      puts "sugarjar version #{SugarJar::VERSION}"
      puts hub('version').stdout
    end

    def smartpullrequest
      assert_in_repo
      if dirty?
        SugarJar::Log.warn(
          'Your repo is dirty, so I am not going to create a pull request. ' +
          'You should commit or amend and push it to your remote first.',
        )
        exit(1)
      end
      system(which('hub'), 'pull-request')
    end

    alias spr smartpullrequest
    alias smartpr smartpullrequest

    private

    def _smartpush(remote, branch, force)
      unless remote && branch
        remote ||= 'origin'
        branch ||= current_branch
      end

      if dirty?
        if @ignore_dirty
          SugarJar::Log.warn(
            'Your repo is dirty, but --ignore-dirty was specified, so ' +
            'carrying on anyway.',
          )
        else
          SugarJar::Log.error(
            'Your repo is dirty, so I am not going to push. Please commit ' +
            'or amend first.',
          )
          exit(1)
        end
      end

      unless run_prepush
        if @ignore_prerun_failure
          SugarJar::Log.warn(
            'Pre-push checks failed, but --ignore-prerun-failure was ' +
            'specified, so carrying on anyway',
          )
        else
          SugarJar::Log.error('Pre-push checks failed. Not pushing.')
          exit(1)
        end
      end

      args = ['push', remote, branch]
      args << '--force-with-lease' if force
      puts hub(*args).stderr
    end

    def dirty?
      s = hub_nofail('diff', '--quiet')
      s.error?
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

    def forked_repo(repo, username)
      repo = if repo.start_with?('http', 'git@')
               File.basename(repo)
             else
               "#{File.basename(repo)}.git"
             end
      "git@github.com:#{username}/#{repo}"
    end

    # Hub will default to https, but we should always default to SSH
    # unless otherwise specified since https will cause prompting.
    def canonicalize_repo(repo)
      # if they fully-qualified it, we're good
      return repo if repo.start_with?('http', 'git@')

      # otherwise, ti's a shortname
      "git@github.com:#{repo}.git"
    end

    def set_hub_host
      return unless in_repo

      s = hub_nofail('config', '--local', '--get', 'hub.host')
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
      hub('config', '--local', '--add', 'hub.host', @ghhost)
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

      s = hub_nofail('config', '--local', 'commit.template')
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
      hub(
        'config', '--local', 'commit.template', @repo_config['commit_template']
      )
    end

    def run_check(type)
      unless @repo_config[type]
        SugarJar::Log.debug("No #{type} configured. Returning success")
        return true
      end
      Dir.chdir repo_root do
        @repo_config[type].each do |check|
          SugarJar::Log.debug("Running #{type} #{check}")

          short = check.split.first
          unless File.exist?(short)
            SugarJar::Log.error("Configured #{type} #{short} does not exist!")
            return false
          end
          s = Mixlib::ShellOut.new(check).run_command

          # Linters auto-correct, lets handle that gracefully
          if type == 'lint' && dirty?
            SugarJar::Log.info(
              "[#{type}] #{short}: #{color('Corrected', :yellow)}",
            )
            SugarJar::Log.warn(
              "The linter modified the repo. Here's the diff:\n",
            )
            puts hub('diff').stdout
            loop do
              $stdout.print(
                "\nWould you like to\n\t[q]uit and inspect\n\t[a]mend the " +
                "changes to the current commit and re-run\n  > ",
              )
              ans = $stdin.gets.strip
              case ans
              when /^q/
                SugarJar::Log.info('Exiting at user request.')
                exit(1)
              when /^a/
                qamend('-a')
                # break here, if we get out of this loop we 'redo', assuming
                # the user chose this option
                break
              end
            end
            redo
          end

          if s.error?
            SugarJar::Log.info(
              "[#{type}] #{short} #{color('failed', :red)}, output follows " +
              "(see debug for more)\n#{s.stdout}",
            )
            SugarJar::Log.debug(s.format_for_exception)
            return false
          end
          SugarJar::Log.info(
            "[#{type}] #{short}: #{color('OK', :green)}",
          )
        end
      end
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
        SugarJar::Log.debug(
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
      curr = current_branch
      SugarJar::Log.debug('Rebasing')
      base = tracked_branch
      if curr != 'master' && base == "origin/#{curr}"
        SugarJar::Log.warn(
          "This branch is tracking origin/#{curr}, which is probably your " +
          'downstream (where you push _to_) as opposed to your upstream ' +
          '(where you pull _from_). This means that "sj up" is probably ' +
          'rebasing on the wrong thing and doing nothing. You probably want ' +
          'to do a "git branch -u upstream".',
        )
      end
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
  end
end
