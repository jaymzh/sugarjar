class SugarJar
  class Commands
    def smartpullrequest(*args)
      assert_in_repo!
      assert_common_main_branch!

      if dirty?
        SugarJar::Log.warn(
          'Your repo is dirty, so I am not going to create a pull request. ' +
          'You should commit or amend and push it to your remote first.',
        )
        exit(1)
      end

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
        if upstream_org != push_org
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
    end

    alias spr smartpullrequest
    alias smartpr smartpullrequest

    private

    def assert_common_main_branch!
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
  end
end
