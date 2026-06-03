class SugarJar
  class Commands
    def smartclone(repo, dir = nil, *)
      reponame = extract_repo(repo)
      dir ||= reponame
      org = extract_org(repo)

      SugarJar::Log.info("Cloning #{reponame}...")

      # GH's 'fork' command (with the --clone arg) will fork, if necessary,
      # then clone, and then setup the remotes with the appropriate names. So
      # we just let it do all the work for us and return.
      #
      # Unless the repo is in our own org and cannot be forked, then it
      # will fail.
      if org == @forge_user
        git('clone', canonicalize_repo(repo), dir, *)
      else
        if @repo_forge == 'gitlab'
          _gitlab_clone(org, repo, dir, *)
        else
          forge('repo', 'fork', '--clone', canonicalize_repo(repo), dir, *)
        end

        # make the main branch track upstream
        Dir.chdir dir do
          git('branch', '-u', "upstream/#{main_branch}")
        end
      end

      SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
    end
    alias sclone smartclone

    def _gitlab_clone(_org, repo, dir, *)
      # The gitlab CLI is much less forgiving about already-forked
      # repos, and it has no option to clone to a differently-named
      # directory. So we have to special case it.

      # glab requires a short-name for the fork command...
      shortname = repo_shortname(repo)

      # We call fork without --clone since --clone can't clone
      # to another directory. Also, we must specify =false, or it
      # will prompt
      s = forge_nofail('repo', 'fork', shortname, '--clone=false')

      # It fails with:
      #    409 {message: [Project namespace name has already been taken,
      #         Name has already been taken, Path has already been taken]}
      #
      # when there's already a fork... or if you happen to have a name
      # collision. There's no way to tell, so we assume it means we've
      # already forked.
      if s.error?
        if s.stderr.include?(' 409 ')
          SugarJar::Log.debug('Forking failed, probably already forked')
        else
          s.error!
        end
      end

      # Now we clone ourselves...
      git('clone', canonicalize_repo(repo), dir, *)
      Dir.chdir dir do
        # and then configure remotes properly
        git('remote', 'rename', 'origin', 'upstream')

        fork_url = forked_repo(repo, @forge_user)
        git('remote', 'add', 'origin', fork_url)
      end
    end
  end
end
