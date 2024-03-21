require 'yaml'
require_relative 'log'

class SugarJar
  # This parses SugarJar configs (not to be confused with repoconfigs).
  # This is stuff like log level, github-user, etc.
  class Config
    DEFAULTS = {
      'github_cli' => 'auto',
      'github_user' => ENV.fetch('USER'),
      'fallthru' => true,
      'pr_autofill' => true,
    }.freeze

    def self._find_ordered_files
      [
        '/etc/sugarjar/config.yaml',
        "#{Dir.home}/.config/sugarjar/config.yaml",
      ].select { |f| File.exist?(f) }
    end

    def self.config
      SugarJar::Log.debug("Defaults: #{DEFAULTS}")
      c = DEFAULTS.dup
      _find_ordered_files.each do |f|
        SugarJar::Log.debug("Loading config #{f}")
        data = YAML.safe_load_file(f)
        # an empty file is a `nil` which you can't merge
        c.merge!(YAML.safe_load_file(f)) if data
        SugarJar::Log.debug("Modified config: #{c}")
      end
      c
    end
  end
end
