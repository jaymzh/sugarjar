class SugarJar
  class Commands
    def up(branch = nil)
      assert_in_repo
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
      assert_in_repo
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
  end
end
