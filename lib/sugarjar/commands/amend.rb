class SugarJar
  class Commands
    def amend(*args)
      assert_in_repo!
      # This cannot use shellout since we need a full terminal for the editor
      exit(system(which('git'), 'commit', '--amend', *args))
    end

    def qamend(*args)
      assert_in_repo!
      SugarJar::Log.info(git('commit', '--amend', '--no-edit', *args).stdout)
    end
    alias amendq qamend
  end
end
