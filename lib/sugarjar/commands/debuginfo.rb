require 'json'

class SugarJar
  class Commands
    def debuginfo
      puts "sugarjar version #{SugarJar::VERSION}"
      puts ghcli('version').stdout
      puts git('version').stdout

      puts "Config: #{JSON.pretty_generate(SugarJar::Config.config)}"
      return unless @repo_config

      puts "Repo config: #{JSON.pretty_generate(@repo_config)}"
    end
  end
end
