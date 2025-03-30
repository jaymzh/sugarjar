class SugarJar
  class Commands
    def version
      puts "sugarjar version #{SugarJar::VERSION}"
      puts ghcli('version').stdout
      # 'hub' prints the 'git' version, but gh doesn't, so if we're on 'gh'
      # print out the git version directly
      puts git('version').stdout
    end
  end
end
