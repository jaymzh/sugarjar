class SugarJar
  class Commands
    def up(branch = nil)
      assert_in_repo!
      branch ||= current_branch
      branch = fprefix(branch)
      # get a copy of our current branch, if rebase fails, we won't
      # be able to determine it without backing out
      curr = current_branch
      git('checkout', branch)
      result = rebase
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

    def upall
      assert_in_repo!
      all_local_branches.each do |branch|
        next if MAIN_BRANCHES.include?(branch)

        git('checkout', branch)
        result = rebase
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

    def sync
      assert_in_repo!
      dirty_check!

      src = "origin/#{current_branch}"
      fetch('origin')
      s = git_nofail('merge-base', '--is-ancestor', 'HEAD', src)
      if s.error?
        SugarJar::Log.debug(
          "Choosing rebase sync since this isn't a direct ancestor",
        )
        rebase(src)
      else
        SugarJar::Log.debug('Choosing reset sync since this is an ancestor')
        git('reset', '--hard', src)
      end
      SugarJar::Log.info("Synced to #{src}.")
    end

    private

    def rebase(base = nil)
      skip_base_warning = !base.nil?
      SugarJar::Log.debug('Fetching upstream')
      fetch_upstream
      curr = current_branch
      # this isn't a hash, it's a named param, silly rubocop
      # rubocop:disable Style/HashSyntax
      base ||= tracked_branch(fallback: false)
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
      if !MAIN_BRANCHES.include?(curr) && base == "origin/#{curr}" &&
         !skip_base_warning
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
  end
end
