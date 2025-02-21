class SugarJar
  class Commands
    def smartclone(repo, dir = nil, *args)
      # If the user has specified a hub host, set the environment variable
      # since we don't have a repo to configure yet
      ENV['GITHUB_HOST'] = @ghhost if @ghhost

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
      if gh? && org != @ghuser
        ghcli('repo', 'fork', '--clone', canonicalize_repo(repo), dir, *args)
        SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
        return
      end

      # For 'hub' first we clone, using git, as 'hub' always needs a repo to
      # operate on.
      #
      # Or for 'gh' when we can't fork...
      git('clone', canonicalize_repo(repo), dir, *args)

      # Then we go into it and attempt to use the 'fork' capability
      # or if not
      Dir.chdir dir do
        # Now that we have a repo, if we have a hub host set it.
        set_hub_host

        SugarJar::Log.debug("Comparing org #{org} to ghuser #{@ghuser}")
        if org == @ghuser
          puts 'Cloned forked or self-owned repo. Not creating "upstream".'
          SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
          return
        end

        s = ghcli_nofail('repo', 'fork', '--remote-name=origin')
        if s.error?
          if s.stdout.include?('SAML enforcement')
            SugarJar::Log.info(
              'Forking the repo failed because the repo requires SAML ' +
              "authentication. Full output:\n\n\t#{s.stdout}",
            )
            exit(1)
          else
            # gh as well as old versions of hub, it would fail if the upstream
            # fork already existed. If we got an error, but didn't recognize
            # that, we'll assume that's what happened and try to add the remote
            # ourselves.
            SugarJar::Log.info("Fork (#{@ghuser}/#{reponame}) detected.")
            SugarJar::Log.debug(
              'The above is a bit of a lie. "hub" failed to fork and it was ' +
              'not a SAML error, so our best guess is that a fork exists ' +
              'and so we will try to configure it.',
            )
            git('remote', 'rename', 'origin', 'upstream')
            git('remote', 'add', 'origin', forked_repo(repo, @ghuser))
          end
        else
          SugarJar::Log.info("Forked #{reponame} to #{@ghuser}")
        end
        SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
      end
    end
    alias sclone smartclone
  end
end
