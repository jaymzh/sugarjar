class SugarJar
  module Help
    # Keyed by the "primary" command (the longest/most-descriptive name -
    # not necessarily the actual method name in SugarJar::Commands, though
    # both work identically for dispatch). `aliases` are other, usually
    # shorter, names that dispatch to the same command. `description` is
    # the full text shown by `sj help <command>`.
    COMMANDS = {
      'amend' => {
        :aliases => [],
        :usage => '',
        :description => <<~DESC,
          Amend the current commit. Alias for `git commit --amend`.
          Accepts other arguments such as `-a` or files.
        DESC
      },
      'amendq' => {
        :aliases => ['qamend'],
        :usage => '',
        :description => <<~DESC,
          Same as `amend` but without changing the message. Alias for
          `git commit --amend --no-edit`.
        DESC
      },
      'binfo' => {
        :aliases => [],
        :usage => '',
        :description => 'Verbose information about the current branch.',
      },
      'br' => {
        :aliases => [],
        :usage => '',
        :description => 'Verbose branch list. An alias for `git branch -v`.',
      },
      'debuginfo' => {
        :aliases => [],
        :usage => '',
        :description => <<~DESC,
          Prints out a bunch of version and config information useful for
          including in bug reports.
        DESC
      },
      'feature' => {
        :aliases => ['f'],
        :usage => '<branch_name>',
        :description => <<~DESC,
          Create a "feature" branch. It's morally equivalent to
          `git checkout -b ...` except it defaults to creating it based on
          some form of the primary branch (`master`, `main`, etc.) instead of
          your current branch. In order of preference it will be
          `upstream/$PRIMARY`, `origin/$PRIMARY`, `$PRIMARY`,
          depending upon what remotes are available.

          Note that you can specify `--feature-prefix` (or add `feature_prefix`
          to your config's 'host_configs' section) to have all features created
          with a prefix. This is useful for branch-based workflows where
          developers are expected to create branches names that, for example,
          start with their username.
        DESC
      },
      'forcepush' => {
        :aliases => ['fpush'],
        :usage => '',
        :description => <<~DESC,
          The same as `smartpush`, but uses `--force-with-lease`. This is
          a "safer" way of doing force-pushes and is the recommended way
          to push after rebasing or amending. Never do this to shared
          branches. Very convenient for keeping the branch behind a pull-
          request clean.
        DESC
      },
      'forcesync' => {
        :aliases => ['fsync'],
        :usage => '',
        :description => <<~DESC,
          Similar to `sync`, but never tries to rebase, always does a
          hard reset.
        DESC
      },
      'globalbranchclean' => {
        :aliases => ['gbclean'],
        :usage => '[<branch>] [<remote>]',
        :description => <<~DESC,
          WARNING: EXPERIMENTAL COMMAND.

          Combination of `localbranchclean` and `remotebranchclean`. Cleans up
          both local and remote branches safely. See those commands for
          details.
        DESC
      },
      'globalbranchcleanall' => {
        :aliases => ['gbcleanall'],
        :usage => '[<remote>]',
        :description => <<~DESC,
          WARNING: EXPERIMENTAL COMMAND.

          Safely clean all branches, both local and remote. See
          `globalbranchclean` for details.
        DESC
      },
      'lint' => {
        :aliases => [],
        :usage => '',
        :description => 'Run any linters configured in the repoconfig.',
      },
      'localbranchclean' => {
        :aliases => %w{lbclean bclean},
        :usage => '[<branch>]',
        :description => <<~DESC,
          If safe, delete the current branch (or the specified branch).
          Unlike `git branch -d`, this can handle squash-merged branches.
          Think of it as a smarter `git branch -d`.

          Aliased to `bclean` for backwards compatibility.
        DESC
      },
      'localbranchcleanall' => {
        :aliases => %w{lbcleanall bcleanall},
        :usage => '',
        :description => <<~DESC,
          Walk all branches, and try to delete them if it's safe. See
          `localbranchclean` for details.

          Aliased to `bcleanall` for backwards compatibility.
        DESC
      },
      'modernizeconfig' => {
        :aliases => ['fixconfig'],
        :usage => '',
        :description => <<~DESC,
          Will take a sugarjar config file and modernize it for all of
          the changes in 4.x. The new version will be printed to stdout.
        DESC
      },
      'pullsuggestions' => {
        :aliases => ['ps'],
        :usage => '',
        :description => <<~DESC,
          Pull any suggestions *that have been committed* in the GitHub UI.
          This will show the diff and prompt for confirmation before
          merging. Note that a fast-forward merge will be used.
        DESC
      },
      'remotebranchclean' => {
        :aliases => ['rbclean'],
        :usage => '[<branch>] [<remote>]',
        :description => <<~DESC,
          WARNING: EXPERIMENTAL COMMAND.

          Similar to `localbranchclean`, except safely cleans up remote
          branches. Unlike many git commands, <remote> comes after <branch> so
          that you can specify a branch and the remote defaults to `origin`.
          This means you can do `sj remotebranchclean` to clean the remote
          branch with the same name as the local one. Note that you probably
          want `globalbranchclean`, which will do both local and remote cleaning
          in one command.

          WARNING: This command cannot differentiate release branches
          that are fully merged but still need to be kept around for future
          work unless they are specified in your repoconfig! So if main contains
          everything that 2.0-devel and 3.0-devel has, then those branches will
          be deleted. Use with caution.
        DESC
      },
      'remotebranchcleanall' => {
        :aliases => ['rbcleanall'],
        :usage => '[<remote>]',
        :description => <<~DESC,
          WARNING: EXPERIMENTAL COMMAND.

          Walk all remote branches, and try to delete them if it's safe. See
          `remotebranchclean` for details.
        DESC
      },
      'smartclone' => {
        :aliases => ['sclone'],
        :usage => '<repo> [<dir>]',
        :description => <<~DESC,
          A smart wrapper to `git clone` that handles forking and managing
          remotes for you.

          If the org of the repository is not the same as your forge user
          then it will fork the repo for you to your account (if not
          already done), clone the repo, and then setup your remotes
          so that `origin` is your fork and `upstream` is the upstream.

          It is assumed that there will be at least one positional
          argument, and it will be the repo in any format (git, ssh,
          forge-style shortname [e.g. e.g. `$org/$repo`]). A second
          positional argument will be interpreted as the directory to
          clone into.

          If you want to change the name of the repo in your fork of it,
          you may pass in `--fork-name` to specify another.

          Note that if you pass in additional options after " -- ", they
          will be passed to `gh` in the case of GitHub, or `git` in the
          case of GitLab.

          For example to clone foo/bar/docs on gitlab, but have the
          repo named "bar-docs" when it's cloned to your org, and to
          have the directory be called "bar-docs":

            sj sclone foo/bar/docs bar-docs \\
              --default-forge-host gitlab.com --fork-name bar-docs

          Or for GitHub:

            sj sclone bar/docs bar-docs \\
              --default-forge-host github.com --fork-name bar-docs
        DESC
      },
      'smartlog' => {
        :aliases => ['sl'],
        :usage => '',
        :description => <<~DESC,
          Inspired by Facebook's `sl` extension to Mercurial, this command
          will show you a tree of all your local branches relative to your
          upstream.
        DESC
      },
      'smartpullrequest' => {
        :aliases => %w{smartpr spr},
        :usage => '',
        :description => <<~DESC,
          A smart wrapper to `gh pr`/`glab mr`/etc. that checks if your repo
          is dirty before creating the pull request, handles intelligently
          picking the base, fills in the PR body, etc.
        DESC
      },
      'smartpush' => {
        :aliases => ['spush'],
        :usage => '',
        :description => <<~DESC,
          A smart wrapper to `git push` that runs whatever is defined in
          `on_push` in the repoconfig, and only pushes if they succeed.
        DESC
      },
      'subfeature' => {
        :aliases => ['sf'],
        :usage => '<feature>',
        :description =>
          'An alias for `sj feature <feature> <current_branch>`.',
      },
      'sync' => {
        :aliases => [],
        :usage => '',
        :description => <<~DESC,
          Similar to `up`, except instead of rebasing on a tracked branch
          (usually `upstream` remote), rebases to wherever our remote push
          target is (usually `origin` remote). Useful for syncing work
          across different machines.

          For example, if you do some work on feature `foo` on machine1 and
          push to `origin/foo` (intending to eventually merge to
          `upstream/main`), then on machine2, you pull that branch, do more
          work, which you also push to `origin/foo`, then on machine1, you
          can do `sj sync` to pull down the changes from `origin/foo`. If
          you have local changes, that are not already on `origin/foo`,
          those will be rebased on top of the changes from `origin/foo`.
        DESC
      },
      'unit' => {
        :aliases => [],
        :usage => '',
        :description => 'Run any unitests configured in the repoconfig.',
      },
      'up' => {
        :aliases => [],
        :usage => '[<branch>]',
        :description => <<~DESC,
          Rebase the current branch (or specified branch) intelligently.
          In most causes this will check for a primary branch on
          `upstream`, then `origin`. If a branch explicitly tracks something
          else, then that will be used, instead.
        DESC
      },
      'upall' => {
        :aliases => [],
        :usage => '',
        :description => 'Same as `up`, but for all branches.',
      },
    }.freeze

    # Map of every valid command/alias name -> its canonical (primary) name.
    ALIASES = COMMANDS.each_with_object({}) do |(name, info), map|
      map[name] = name
      info[:aliases].each { |a| map[a] = name }
    end.freeze

    def self.canonical(name)
      ALIASES[name]
    end

    def self.summary_list
      COMMANDS.sort.map do |name, info|
        names = ([name] + info[:aliases]).join(', ')
        "  #{names}"
      end.join("\n")
    end

    def self.command_help(name)
      canonical_name = canonical(name)
      return nil unless canonical_name

      info = COMMANDS[canonical_name]
      names = ([canonical_name] + info[:aliases]).join(', ')
      usage = info[:usage].empty? ? '' : " #{info[:usage]}"
      "#{names}#{usage}\n\n#{info[:description]}"
    end
  end
end
