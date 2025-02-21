class SugarJar
  class Commands
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

    private

    def clean_branch(name)
      die("Cannot remove #{name} branch") if MAIN_BRANCHES.include?(name)
      SugarJar::Log.debug('Fetch relevant remote...')
      fetch_upstream
      return false unless safe_to_clean(name)

      SugarJar::Log.debug('branch deemed safe to delete...')
      checkout_main_branch
      git('branch', '-D', name)
      rebase
      true
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
  end
end
