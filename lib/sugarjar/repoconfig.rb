require_relative 'util'
require_relative 'log'
require 'yaml'

class SugarJar
  # This parses SugarJar repoconfigs (not to be confused with configs).
  # This is lint/unit/on_push configs.
  class RepoConfig
    extend SugarJar::Util

    CONFIG_NAME = '.sugarjar.yaml'.freeze

    def self.repo_config
      ::File.join(repo_root, CONFIG_NAME)
    end

    def self.config
      unless in_repo
        SugarJar::Log.debug('Not in repo, skipping repoconfig load')
        return {}
      end
      config = repo_config
      if File.exist?(config)
        SugarJar::Log.debug("Loading repo config: #{config}")
        YAML.safe_load(File.read(repo_config))
      else
        SugarJar::Log.debug("No repo config (#{config}), returning empty hash")
        {}
      end
    end
  end
end
