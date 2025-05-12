require_relative '../util'

class SugarJar
  class Commands
    def amend(*)
      assert_in_repo!
      # This cannot use shellout since we need a full terminal for the editor
      exit(system(SugarJar::Util.which('git'), 'commit', '--amend', *))
    end

    def qamend(*)
      assert_in_repo!
      SugarJar::Log.info(git('commit', '--amend', '--no-edit', *).stdout)
    end
    alias amendq qamend
  end
end
