require 'json'

class SugarJar
  class Commands
    def debuginfo(*args)
      puts "sugarjar version #{SugarJar::VERSION}"
      puts ghcli('version').stdout
      puts git('version').stdout

      puts "Config: #{JSON.pretty_generate(args[0])}"
      return unless @repo_config

      puts "Repo config: #{JSON.pretty_generate(@repo_config)}"
    end
  end
end
