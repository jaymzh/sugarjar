require 'yaml'
require_relative 'log'

class SugarJar
  # This parses SugarJar configs (not to be confused with repoconfigs).
  # This is stuff like log level, github-user, etc.
  class Config
    DEFAULTS = {
      'github_user' => ENV.fetch('USER'),
      'pr_autofill' => true,
      'pr_autostack' => nil,
      'color' => true,
      'ignore_deprecated_options' => [],
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
        warn_on_deprecated_configs(data, f)
        # an empty file is a `nil` which you can't merge
        c.merge!(YAML.safe_load_file(f)) if data
        SugarJar::Log.debug("Modified config: #{c}")
      end
      c
    end

    def self.warn_on_deprecated_configs(data, fname)
      ignore_deprecated_options = data['ignore_deprecated_options'] || []
      %w{fallthru gh_cli}.each do |opt|
        next unless data.key?(opt)

        if ignore_deprecated_options.include?(opt)
          SugarJar::Log.debug(
            "Not warning about deprecated option '#{opt}' in #{fname} due to " +
            '"ignore_deprecated_options" in that file.',
          )
          next
        end
        SugarJar::Log.warn(
          "Config file #{fname} contains deprecated option #{opt}. You can " +
          'suppress this warning with ignore_deprecated_options.',
        )
      end
    end
  end
end
