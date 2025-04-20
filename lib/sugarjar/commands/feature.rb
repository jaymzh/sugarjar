class SugarJar
  class Commands
    def feature(name, base = nil)
      assert_in_repo!
      SugarJar::Log.debug("Feature: #{name}, #{base}")
      name = fprefix(name)
      die("#{name} already exists!") if all_local_branches.include?(name)
      if base
        fbase = fprefix(base)
        base = fbase if all_local_branches.include?(fbase)
      else
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

    def subfeature(name)
      assert_in_repo!
      SugarJar::Log.debug("Subfature: #{name}")
      feature(name, current_branch)
    end
    alias sf subfeature
  end
end
