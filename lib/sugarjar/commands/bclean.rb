class SugarJar
  class Commands
    def lbclean(name = nil)
      assert_in_repo!
      name ||= current_branch
      name = fprefix(name)

      wt_branches = worktree_branches

      if wt_branches.include?(name)
        SugarJar::Log.warn("#{name}: #{color('skipped', :yellow)} (worktree)")
        return
      end

      if clean_branch(name)
        SugarJar::Log.info("#{name}: #{color('reaped', :green)}")
      else
        die(
          "#{color("Cannot clean #{name}", :red)}! there are unmerged " +
          "commits; use 'git branch -D #{name}' to forcefully delete it.",
        )
      end
    end
    alias localbranchclean lbclean
    # backcompat
    alias bclean lbclean

    def rbclean(name = nil, remote = nil)
      assert_in_repo!
      name ||= current_branch
      name = fprefix(name)
      remote ||= 'origin'

      ref = "refs/remotes/#{remote}/#{name}"
      if git_nofail('show-ref', '--quiet', ref).error?
        SugarJar::Log.warn("Remote branch #{name} on #{remote} does not exist.")
        return
      end

      if clean_branch(ref, :remote)
        SugarJar::Log.info("#{ref}: #{color('reaped', :green)}")
      else
        die(
          "#{color("Cannot clean #{ref}", :red)}! there are unmerged " +
          "commits; use 'git push #{remote} -d #{name}' to forcefully delete " +
          ' it.',
        )
      end
    end
    alias remotebranchclean rbclean

    def gbclean(name = nil, remote = nil)
      assert_in_repo!
      name ||= current_branch
      remote ||= 'origin'
      lbclean(name)
      rbclean(name, remote)
    end
    alias globalbranchclean gbclean

    def lbcleanall
      assert_in_repo!
      curr = current_branch
      wt_branches = worktree_branches
      all_local_branches.each do |branch|
        if MAIN_BRANCHES.include?(branch)
          SugarJar::Log.debug("Skipping #{branch}")
          next
        end
        if wt_branches.include?(branch)
          SugarJar::Log.info(
            "#{branch}: #{color('skipped', :yellow)} (worktree)",
          )
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
    alias localbranchcleanall lbcleanall
    # backcomat
    alias bcleanall lbcleanall

    def rbcleanall(remote = nil)
      assert_in_repo!
      curr = current_branch
      remote ||= 'origin'
      all_remote_branches(remote).each do |branch|
        if (MAIN_BRANCHES + ['HEAD']).include?(branch)
          SugarJar::Log.debug("Skipping #{branch}")
          next
        end

        ref = "refs/remotes/#{remote}/#{branch}"
        if clean_branch(ref, :remote)
          SugarJar::Log.info("#{ref}: #{color('reaped', :green)}")
        else
          SugarJar::Log.info("#{ref}: skipped")
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
    alias remotebranchcleanall rbcleanall

    def gbcleanall(remote = nil)
      assert_in_repo!
      bcleanall
      rcleanall(remote)
    end
    alias globalbranchcleanall gbcleanall

    private

    # rubocop:disable Naming/PredicateMethod
    def clean_branch(name, type = :local)
      undeleteable = MAIN_BRANCHES.dup
      undeleteable << 'HEAD' if type == :remote
      die("Cannot remove #{name} branch") if undeleteable.include?(name)
      SugarJar::Log.debug('Fetch relevant remote...')
      fetch_upstream
      fetch(remote_from_ref(name)) if type == :remote
      return false unless safe_to_clean?(name)

      SugarJar::Log.debug('branch deemed safe to delete...')
      if type == :remote
        remote = remote_from_ref(name)
        branch = branch_from_ref(name, :remote)
        git('push', remote, '--delete', branch)
      else
        checkout_main_branch
        git('branch', '-D', name)
        rebase
      end
      true
    end
    # rubocop:enable Naming/PredicateMethod

    def safe_to_clean?(branch)
      # cherry -v will output 1 line per commit on the target branch
      # prefixed by a - or + - anything with a - can be dropped, anything
      # else cannot.
      SugarJar::Log.debug("Checking if branch #{branch} is safe to delete...")
      if branch.start_with?('refs/remotes/')
        remote = remote_from_ref(branch)
        tracked = main_remote_branch(remote)
      else
        tracked = tracked_branch(branch)
      end
      out = git(
        'cherry', '-v', tracked, branch
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

      git('checkout', '-b', tmpbranch, tracked)
      s = git_nofail('merge', '--squash', branch)
      if s.error?
        cleanup_tmp_branch(tmpbranch, branch, tracked)
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
      cleanup_tmp_branch(tmpbranch, branch, tracked)
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

    def cleanup_tmp_branch(tmp, backto, tracked = nil)
      tracked ||= tracked_branch
      # Reset any changes on our temp branch from various merge attempts
      # so we're in a state we know we can 'checkout' away from.
      git('reset', '--hard', tracked)
      # checkout whatever branch we were on before
      git('checkout', backto)
      # delete our temp branch
      git('branch', '-D', tmp)
    end
  end
end
