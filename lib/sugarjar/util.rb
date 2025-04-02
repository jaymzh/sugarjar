require_relative 'log'

require 'mixlib/shellout'

class SugarJar
  # Some common methods needed by other classes
  module Util
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
        next if line.start_with?('(HEAD detached')

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

    def gh_avail?
      !!which_nofail('gh')
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

    # Finds the first entry in the path for a binary and checks
    # to make sure it's not us. Warn if it is us as that won't work in 2.x
    def which_nofail(cmd)
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
        p = File.join(dir, cmd)
        next unless File.exist?(p) && File.executable?(p)

        if File.basename(File.realpath(p)) == 'sj'
          SugarJar::Log.error(
            "'#{cmd}' is linked to 'sj' which is no longer supported.",
          )
          next
        end
        return p
      end
      false
    end

    def which(cmd)
      path = which_nofail(cmd)
      return path if path

      SugarJar::Log.fatal("Could not find #{cmd} in your path")
      exit(1)
    end

    def git_nofail(*args)
      if %w{diff log grep branch}.include?(args[0]) &&
         args.none? { |x| x.include?('color') }
        args << (@color ? '--color' : '--no-color')
      end
      SugarJar::Log.trace("Running: git #{args.join(' ')}")
      Mixlib::ShellOut.new([which('git')] + args).run_command
    end

    def git(*args)
      s = git_nofail(*args)
      s.error!
      s
    end

    def ghcli_nofail(*args)
      SugarJar::Log.trace("Running: gh #{args.join(' ')}")
      s = Mixlib::ShellOut.new([which('gh')] + args).run_command
      if s.error? && s.stderr.include?('gh auth')
        SugarJar::Log.info(
          'gh was run but no github token exists. Will run "gh auth login" ' +
          "to force\ngh to authenticate...",
        )
        unless system(which('gh'), 'auth', 'login', '-p', 'ssh')
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

    def ghcli(*args)
      s = ghcli_nofail(*args)
      s.error!
      s
    end

    def in_repo
      s = git_nofail('rev-parse', '--is-inside-work-tree')
      !s.error? && s.stdout.strip == 'true'
    end

    def dirty?
      s = git_nofail('diff', '--quiet')
      s.error?
    end

    def repo_root
      git('rev-parse', '--show-toplevel').stdout.strip
    end

    def repo_name
      repo_root.split('/').last
    end
  end
end
