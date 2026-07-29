class SugarJar
  class Commands
    def smartclone(repo, *args)
      org = extract_org(repo)
      reponame = extract_repo(repo)
      host = extract_host(repo) || @config['default_forge_host']
      unless host
        raise 'Failed to determine host. Please specify --default-forge-host,' +
              ' and file a bug.'
      end
      @host_config = gen_host_config(host)
      raise 'Failed to determine forge_type' unless @host_config['forge_type']

      # force object creation for error checking
      forge

      # set env vars of the host, just for completeness
      # since it's short-lived we just set both vars
      ENV['GH_HOST'] = host
      ENV['GL_HOST'] = host

      dir = if args.length.positive? && !args.first.start_with?('-')
              args.shift
            else
              reponame
            end

      forkname = @config['fork_name'] || reponame

      SugarJar::Log.info("Cloning #{reponame}...")

      # GH's 'fork' command (with the --clone arg) will fork, if necessary,
      # then clone, and then setup the remotes with the appropriate names. So
      # we just let it do all the work for us and return.
      #
      # Unless the repo is in our own org and cannot be forked, then it
      # will fail.
      if @host_config['use_forks'] && @host_config['user'] != org
        case forge.type
        when 'gitlab', 'forgejo'
          _separate_fork_clone(org, repo, dir, forkname, *args)
        else
          forge.run(
            'repo', 'fork', '--clone', canonicalize_repo(repo), dir,
            '--fork-name', forkname, *args
          )
        end

        # make the main branch track upstream
        Dir.chdir dir do
          git('branch', '-u', "upstream/#{main_branch}")
        end
      else
        git('clone', canonicalize_repo(repo), dir, *args)
      end

      SugarJar::Log.info('Remotes "origin" and "upstream" configured.')
    end
    alias sclone smartclone

    def _separate_fork_clone(_org, repo, dir, forkname, *)
      # The gitlab CLI is much less forgiving about already-forked
      # repos, and it has no option to clone to a differently-named
      # directory. So we have to special case it.

      extract_repo(repo)

      # glab requires a short-name for the fork command...
      shortname = repo_shortname(repo)

      # For both gitlab and forgejo we fork without clone:
      #   * gitlab - it cannot clone to a chosen directory
      #   * forgjo - it doesn't have an option to fork and clone in one
      #
      # Also note that for gitlab we must be explicit, if we don't
      # set --clone=false it will prompt.
      repo_ref = forge.type == 'gitlab' ? shortname : repo
      args = ['repo', 'fork', repo_ref, '--name', forkname]
      args << '--clone=false' if forge.type == 'gitlab'
      s = forge.run_nofail(*args)

      # It fails with:
      #    409 {message: [Project namespace name has already been taken,
      #         Name has already been taken, Path has already been taken]}
      #
      # when there's already a fork... or if you happen to have a name
      # collision. There's no way to tell, so we assume it means we've
      # already forked.
      if s.error?
        if forge.type == 'gitlab' && s.stderr.include?(' 409 ')
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

        fork_url = forked_repo(repo, @host_config['user'])
        git('remote', 'add', 'origin', fork_url)
      end
    end
  end
end
