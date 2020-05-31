require 'yaml'
require_relative 'log'

class SugarJar
  # This parses SugarJar configs (not to be confused with repoconfigs).
  # This is stuff like log level, github-user, etc.
  class Config
    DEFAULTS = {
      'ghuser' => ENV['USER']
    }.freeze

    def self._find_ordered_files
      [
        '/etc/sugarjar/config.yaml',
        "#{ENV['HOME']}/.config/sugarjar/config.yaml"
      ].select { |f| File.exist?(f) }
    end

    def self.config
      SugarJar::Log.debug("Defaults: #{DEFAULTS}")
      c = DEFAULTS.dup
      _find_ordered_files.each do |f|
        SugarJar::Log.debug("Loading config #{f}")
        c.merge!(YAML.safe_load(File.read(f)))
        SugarJar::Log.debug("Modified config: #{c}")
      end
      c
    end
  end
end
