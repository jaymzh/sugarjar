require 'yaml'
require_relative 'log'

class SugarJar
  # This parses SugarJar configs (not to be confused with repoconfigs).
  # This is stuff like log level, github-user, etc.
  class Config
    DEFAULTS = {
      'ghuser' => ENV['USER'],
      'fallthru' => true,
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
        data = YAML.safe_load(File.read(f))
        # an empty file is a `nil` which you can't merge
        c.merge!(YAML.safe_load(File.read(f))) if data
        SugarJar::Log.debug("Modified config: #{c}")
      end
      c
    end
  end
end
