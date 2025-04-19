class SugarJar
  class Commands
    def smartpush(remote = nil, branch = nil)
      assert_in_repo!
      _smartpush(remote, branch, false)
    end
    alias spush smartpush

    def forcepush(remote = nil, branch = nil)
      assert_in_repo!
      _smartpush(remote, branch, true)
    end
    alias fpush forcepush

    private

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
  end
end
