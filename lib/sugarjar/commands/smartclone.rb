class SugarJar
  class Commands
    def smartclone(repo, dir = nil, *args)
      reponame = File.basename(repo, '.git')
      dir ||= reponame
      org = extract_org(repo)

      SugarJar::Log.info("Cloning #{reponame}...")

      # GH's 'fork' command (with the --clone arg) will fork, if necessary,
      # then clone, and then setup the remotes with the appropriate names. So
      # we just let it do all the work for us and return.
      #
      # Unless the repo is in our own org and cannot be forked, then it
      # will fail.
      if org == @ghuser
        git('clone', canonicalize_repo(repo), dir, *args)
      else
        ghcli('repo', 'fork', '--clone', canonicalize_repo(repo), dir, *args)
        # make the main branch track upstream
        Dir.chdir dir do
          git('branch', '-u', "upstream/#{main_branch}")
        end
      end

      SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
    end
    alias sclone smartclone
  end
end
