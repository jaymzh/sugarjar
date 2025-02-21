class SugarJar
  class Commands
    def checkout(*args)
      assert_in_repo
      # Pop the last arguement, which is _probably_ a branch name
      # and then add any featureprefix, and if _that_ is a branch
      # name, replace the last arguement with that
      name = args.last
      bname = fprefix(name)
      if all_local_branches.include?(bname)
        SugarJar::Log.debug("Featurepefixing #{name} -> #{bname}")
        args[-1] = bname
      end
      s = git('checkout', *args)
      SugarJar::Log.info(s.stderr + s.stdout.chomp)
    end
    alias co checkout

    def br
      assert_in_repo
      SugarJar::Log.info(git('branch', '-v').stdout.chomp)
    end

    def binfo
      assert_in_repo
      SugarJar::Log.info(git(
        'log', '--graph', '--oneline', '--decorate', '--boundary',
        "#{tracked_branch}.."
      ).stdout.chomp)
    end

    # binfo for all branches
    def smartlog
      assert_in_repo
      SugarJar::Log.info(git(
        'log', '--graph', '--oneline', '--decorate', '--boundary',
        '--branches', "#{most_main}.."
      ).stdout.chomp)
    end
    alias sl smartlog
  end
end
