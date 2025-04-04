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

    def feature(name, base = nil)
      assert_in_repo
      SugarJar::Log.debug("Feature: #{name}, #{base}")
      name = fprefix(name)
      die("#{name} already exists!") if all_local_branches.include?(name)
      base ||= most_main
      # If our base is a local branch, don't try to parse it for a remote name
      unless all_local_branches.include?(base)
        base_pieces = base.split('/')
        git('fetch', base_pieces[0]) if base_pieces.length > 1
      end
      git('checkout', '-b', name, base)
      git('branch', '-u', base)
      SugarJar::Log.info(
        "Created feature branch #{color(name, :green)} based on " +
        color(base, :green),
      )
    end
    alias f feature

    def subfeature(name)
      assert_in_repo
      SugarJar::Log.debug("Subfature: #{name}")
      feature(name, current_branch)
    end
    alias sf subfeature

    def bclean(name = nil)
      assert_in_repo
      name ||= current_branch
      name = fprefix(name)
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
      all_local_branches.each do |branch|
        if MAIN_BRANCHES.include?(branch)
          SugarJar::Log.debug("Skipping #{branch}")
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

      # Return to the branch we were on, or main
      if all_local_branches.include?(curr)
        git('checkout', curr)
      else
        checkout_main_branch
      end
    end

    def co(*args)
      assert_in_repo
      # Pop the last arguement, which is _probably_ a branch name
      # and then add any featureprefix, and if _that_ is a branch
      # name, replace the last arguement with that
      name = args.last
      bname = fprefix(name)
      if all_local_branches.include?(bname)
        SugarJar::Log.debug("Featurepefixing #{name} -> #{bname}")
        args[-1] = bname
      end
      s = git('checkout', *args)
      SugarJar::Log.info(s.stderr + s.stdout.chomp)
    end

    def br
      assert_in_repo
      SugarJar::Log.info(git('branch', '-v').stdout.chomp)
    end

    def binfo
      assert_in_repo
      SugarJar::Log.info(git(
        'log', '--graph', '--oneline', '--decorate', '--boundary',
        "#{tracked_branch}.."
      ).stdout.chomp)
    end

    # binfo for all branches
    def smartlog
      assert_in_repo
      SugarJar::Log.info(git(
        'log', '--graph', '--oneline', '--decorate', '--boundary',
        '--branches', "#{most_main}.."
      ).stdout.chomp)
    end

    alias sl smartlog

    def up(branch = nil)
      assert_in_repo
      branch ||= current_branch
      branch = fprefix(branch)
      # get a copy of our current branch, if rebase fails, we won't
      # be able to determine it without backing out
      curr = current_branch
      git('checkout', branch)
      result = gitup
      if result['so'].error?
        backout = ''
        if rebase_in_progress?
          backout = ' You can get out of this with a `git rebase --abort`.'
        end

        die(
          "#{color(curr, :red)}: Failed to rebase on " +
          "#{result['base']}. Leaving the repo as-is.#{backout} " +
          'Output from failed rebase is: ' +
          "\nSTDOUT:\n#{result['so'].stdout.lines.map { |x| "\t#{x}" }.join}" +
          "\nSTDERR:\n#{result['so'].stderr.lines.map { |x| "\t#{x}" }.join}",
        )
      else
        SugarJar::Log.info(
          "#{color(current_branch, :green)} rebased on #{result['base']}",
        )
        # go back to where we were if we rebased a different branch
        git('checkout', curr) if branch != curr
      end
    end

    def amend(*args)
      assert_in_repo
      # This cannot use shellout since we need a full terminal for the editor
      exit(system(which('git'), 'commit', '--amend', *args))
    end

    def qamend(*args)
      assert_in_repo
      SugarJar::Log.info(git('commit', '--amend', '--no-edit', *args).stdout)
    end

    alias amendq qamend

    def upall
      assert_in_repo
      all_local_branches.each do |branch|
        next if MAIN_BRANCHES.include?(branch)

        git('checkout', branch)
        result = gitup
        if result['so'].error?
          SugarJar::Log.error(
            "#{color(branch, :red)} failed rebase. Reverting attempt and " +
            'moving to next branch. Try `sj up` manually on that branch.',
          )
          git('rebase', '--abort') if rebase_in_progress?
        else
          SugarJar::Log.info(
            "#{color(branch, :green)} rebased on " +
            color(result['base'], :green).to_s,
          )
        end
      end
    end

    def smartclone(repo, dir = nil, *args)
      # If the user has specified a hub host, set the environment variable
      # since we don't have a repo to configure yet
      ENV['GITHUB_HOST'] = @ghhost if @ghhost

      reponame = File.basename(repo, '.git')
      dir ||= reponame
      org = extract_org(repo)

      SugarJar::Log.info("Cloning #{reponame}...")

      # GH's 'fork' command (with the --clone arg) will fork, if necessary,
      # then clone, and then setup the remotes with the appropriate names. So
      # we just let it do all the work for us and return.
      #
      # Unless the repo is in our own org and cannot be forked, then it
      # will fail.
      if gh? && org != @ghuser
        ghcli('repo', 'fork', '--clone', canonicalize_repo(repo), dir, *args)
        SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
        return
      end

      # For 'hub' first we clone, using git, as 'hub' always needs a repo to
      # operate on.
      #
      # Or for 'gh' when we can't fork...
      git('clone', canonicalize_repo(repo), dir, *args)

      # Then we go into it and attempt to use the 'fork' capability
      # or if not
      Dir.chdir dir do
        # Now that we have a repo, if we have a hub host set it.
        set_hub_host

        SugarJar::Log.debug("Comparing org #{org} to ghuser #{@ghuser}")
        if org == @ghuser
          puts 'Cloned forked or self-owned repo. Not creating "upstream".'
          SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
          return
        end

        s = ghcli_nofail('repo', 'fork', '--remote-name=origin')
        if s.error?
          if s.stdout.include?('SAML enforcement')
            SugarJar::Log.info(
              'Forking the repo failed because the repo requires SAML ' +
              "authentication. Full output:\n\n\t#{s.stdout}",
            )
            exit(1)
          else
            # gh as well as old versions of hub, it would fail if the upstream
            # fork already existed. If we got an error, but didn't recognize
            # that, we'll assume that's what happened and try to add the remote
            # ourselves.
            SugarJar::Log.info("Fork (#{@ghuser}/#{reponame}) detected.")
            SugarJar::Log.debug(
              'The above is a bit of a lie. "hub" failed to fork and it was ' +
              'not a SAML error, so our best guess is that a fork exists ' +
              'and so we will try to configure it.',
            )
            git('remote', 'rename', 'origin', 'upstream')
            git('remote', 'add', 'origin', forked_repo(repo, @ghuser))
          end
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
      puts ghcli('version').stdout
      # 'hub' prints the 'git' version, but gh doesn't, so if we're on 'gh'
      # print out the git version directly
      puts git('version').stdout if gh?
    end

    def smartpullrequest(*args)
      assert_in_repo
      assert_common_main_branch

      if dirty?
        SugarJar::Log.warn(
          'Your repo is dirty, so I am not going to create a pull request. ' +
          'You should commit or amend and push it to your remote first.',
        )
        exit(1)
      end

      if gh?
        curr = current_branch
        base = tracked_branch
        if @pr_autofill
          SugarJar::Log.info('Autofilling in PR from commit message')
          num_commits = git(
            'rev-list', '--count', curr, "^#{base}"
          ).stdout.strip.to_i
          if num_commits > 1
            args.unshift('--fill-first')
          else
            args.unshift('--fill')
          end
        end
        if subfeature?(base)
          if upstream != push_org
            SugarJar::Log.warn(
              'Unfortunately you cannot based one PR on another PR when' +
              " using fork-based PRs. We will base this on #{most_main}." +
              ' This just means the PR "Changes" tab will show changes for' +
              ' the full stack until those other PRs are merged and this PR' +
              ' PR is rebased.',
            )
          # nil is prompt, true is always, false is never
          elsif @pr_autostack.nil?
            $stdout.print(
              'It looks like this is a subfeature, would you like to base ' +
              "this PR on #{base}? [y/n] ",
            )
            ans = $stdin.gets.strip
            args.unshift('--base', base) if %w{Y y}.include?(ans)
          elsif @pr_autostack
            args.unshift('--base', base)
          end
        end
        # <org>:<branch> is the GH API syntax for:
        #   look for a branch of name <branch>, from a fork in owner <org>
        args.unshift('--head', "#{push_org}:#{curr}")
        SugarJar::Log.trace("Running: gh pr create #{args.join(' ')}")
        system(which('gh'), 'pr', 'create', *args)
      else
        SugarJar::Log.trace("Running: hub pull-request #{args.join(' ')}")
        system(which('hub'), 'pull-request', *args)
      end
    end

    alias spr smartpullrequest
    alias smartpr smartpullrequest

    def pullsuggestions
      assert_in_repo

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

      src = "origin/#{current_branch}"
      fetch('origin')
      diff = git('diff', "..#{src}").stdout
      return unless diff && !diff.empty?

      puts "Will merge the following suggestions:\n\n#{diff}"

      loop do
        $stdout.print("\nAre you sure? [y/n] ")
        ans = $stdin.gets.strip
        case ans
        when /^[Yy]$/
          system(which('git'), 'merge', '--ff', "origin/#{current_branch}")
          break
        when /^[Nn]$/, /^[Qq](uit)?/
          puts 'Not merging at user request...'
          break
        else
          puts "Didn't understand '#{ans}'."
        end
      end
    end

    alias ps pullsuggestions

    private

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
      puts git(*args).stderr
    end

    def dirty?
      s = git_nofail('diff', '--quiet')
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

    def get_checks_from_command(type)
      return nil unless @repo_config["#{type}_list_cmd"]

      cmd = @repo_config["#{type}_list_cmd"]
      short = cmd.split.first
      unless File.exist?(short)
        SugarJar::Log.error(
          "Configured #{type}_list_cmd #{short} does not exist!",
        )
        return false
      end
      s = Mixlib::ShellOut.new(cmd).run_command
      if s.error?
        SugarJar::Log.error(
          "#{type}_list_cmd (#{cmd}) failed: #{s.format_for_exception}",
        )
        return false
      end
      s.stdout.split("\n")
    end

    # determine if we're using the _list_cmd and if so run it to get the
    # checks, or just use the directly-defined check, and cache it
    def get_checks(type)
      return @checks[type] if @checks[type]

      ret = get_checks_from_command(type)
      if ret
        SugarJar::Log.debug("Found #{type}s: #{ret}")
        @checks[type] = ret
      # if it's explicitly false, we failed to run the command
      elsif ret == false
        @checks[type] = false
      # otherwise, we move on (basically: it's nil, there was no _list_cmd)
      else
        SugarJar::Log.debug("[#{type}]: using listed linters: #{ret}")
        @checks[type] = @repo_config[type] || []
      end
      @checks[type]
    end

    def run_check(type)
      Dir.chdir repo_root do
        checks = get_checks(type)
        # if we failed to determine the checks, the the checks have effectively
        # failed
        return false unless checks

        checks.each do |check|
          SugarJar::Log.debug("Running #{type} #{check}")

          short = check.split.first
          if short.include?('/')
            short = File.join(repo_root, short) unless short.start_with?('/')
            unless File.exist?(short)
              SugarJar::Log.error("Configured #{type} #{short} does not exist!")
            end
          elsif !which_nofail(short)
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
            puts git('diff').stdout
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

    def clean_branch(name)
      die("Cannot remove #{name} branch") if MAIN_BRANCHES.include?(name)
      SugarJar::Log.debug('Fetch relevant remote...')
      fetch_upstream
      return false unless safe_to_clean(name)

      SugarJar::Log.debug('branch deemed safe to delete...')
      checkout_main_branch
      git('branch', '-D', name)
      gitup
      true
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

    def safe_to_clean(branch)
      # cherry -v will output 1 line per commit on the target branch
      # prefixed by a - or + - anything with a - can be dropped, anything
      # else cannot.
      out = git(
        'cherry', '-v', tracked_branch, branch
      ).stdout.lines.reject do |line|
        line.start_with?('-')
      end
      if out.empty?
        SugarJar::Log.debug(
          "cherry-pick shows branch #{branch} obviously safe to delete",
        )
        return true
      end

      # if the "easy" check didn't work, it's probably because there
      # was a squash-merge. To check for that we make our own squash
      # merge to upstream/main and see if that has any delta

      # First we need a temp branch to work on
      tmpbranch = "_sugar_jar.#{Process.pid}"

      git('checkout', '-b', tmpbranch, tracked_branch)
      s = git_nofail('merge', '--squash', branch)
      if s.error?
        cleanup_tmp_branch(tmpbranch, branch)
        SugarJar::Log.debug(
          'Failed to merge changes into current main. This means we could ' +
          'not figure out if this is merged or not. Check manually and use ' +
          "'git branch -D #{branch}' if it is safe to do so.",
        )
        return false
      end

      s = git('diff', '--staged')
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
          'After squash-merging, this branch is NOT fully merged to main',
        )
        false
      end
    end

    def cleanup_tmp_branch(tmp, backto)
      git('reset', '--hard', tracked_branch)
      git('checkout', backto)
      git('branch', '-D', tmp)
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

    def gitup
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

    # determine if this branch is based on another local branch (i.e. is a
    # subfeature). Used to figure out of we should stack the PR
    def subfeature?(base)
      all_local_branches.reject { |x| x == most_main }.include?(base)
    end

    def rebase_in_progress?
      # for rebase without -i
      rebase_file = git('rev-parse', '--git-path', 'rebase-apply').stdout.strip
      # for rebase -i
      rebase_merge_file = git('rev-parse', '--git-path', 'rebase-merge').
                          stdout.strip
      File.exist?(rebase_file) || File.exist?(rebase_merge_file)
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
