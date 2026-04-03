class SugarJar
  class Commands
    def feature(name, base = nil)
      assert_in_repo!
      SugarJar::Log.debug("Feature: #{name}, #{base}")
      name = fprefix(name)
      die("#{name} already exists!") if all_local_branches.include?(name)
      rel_branches = release_branches
      if base
        # If the user specified a base branch (sf mything base)
        # we check if <base> is a release branch and if so, we make
        # this track <upstream>/<base>
        if rel_branches.include?(base)
          newbase = "#{upstream}/#{base}"
          SugarJar::Log.info(
            "Base branch #{base} is a release branch, setting it to track " +
            newbase,
          )
          base = newbase
        else
          fbase = fprefix(base)
          base = fbase if all_local_branches.include?(fbase)
        end
      elsif rel_branches.include?(name)
        # If the user did NOT specify a base *and* this new feature is
        # a release branch, check it out tracking the upstream release
        # branch instead of main
        base = "#{upstream}/#{name}"
        SugarJar::Log.info(
          "Feature #{name} is a release branch, setting it to track #{base}",
        )
      else
        # otherwise, fallback to most-main
        base ||= most_main
      end
      # If our base is a local branch, don't try to parse it for a remote name
      unless all_local_branches.include?(base)
        base_pieces = base.split('/')
        git('fetch', base_pieces[0]) if base_pieces.length > 1
      end
      git('checkout', '-b', name, base)
      git('branch', '-u', base)
      SugarJar::Log.info(
        "Created feature branch #{color(name, :green)} based on " +
        color(base, :green),
      )
    end
    alias f feature

    # alias for "feature <current_branch>'
    def subfeature(name)
      assert_in_repo!
      SugarJar::Log.debug("Subfature: #{name}")
      feature(name, current_branch)
    end
    alias sf subfeature
  end
end
