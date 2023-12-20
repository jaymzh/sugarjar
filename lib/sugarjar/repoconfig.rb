require_relative 'util'
require_relative 'log'
require 'yaml'
require 'deep_merge'

class SugarJar
  # This parses SugarJar repoconfigs (not to be confused with configs).
  # This is lint/unit/on_push configs.
  class RepoConfig
    extend SugarJar::Util

    CONFIG_NAME = '.sugarjar.yaml'.freeze

    def self.repo_config_path(config)
      ::File.join(repo_root, config)
    end

    def self.hash_from_file(config_file)
      SugarJar::Log.debug("Loading repo config: #{config_file}")
      YAML.safe_load(File.read(config_file))
    end

    # wrapper for File.exist to make unittests easier
    def self.config_file?(config_file)
      File.exist?(config_file)
    end

    def self.config(config = CONFIG_NAME)
      data = {}
      unless in_repo
        SugarJar::Log.debug('Not in repo, skipping repoconfig load')
        return data
      end
      config_file = repo_config_path(config)
      data = hash_from_file(config_file) if config_file?(config_file)
      if data['overwrite_from'] && config_file?(data['overwrite_from'])
        SugarJar::Log.debug(
          "Attempting overwrite_from #{data['overwrite_from']}",
        )
        data = config(data['overwrite_from'])
        data.delete('overwrite_from')
      elsif data['include_from'] && config_file?(data['include_from'])
        SugarJar::Log.debug("Attempting include_from #{data['include_from']}")
        data.deep_merge!(config(data['include_from']))
        data.delete('include_from')
      end
      data
    end
  end
end
