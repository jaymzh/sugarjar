require 'yaml'
require_relative 'log'

class SugarJar
  # This parses SugarJar configs (not to be confused with repoconfigs).
  # This is stuff like log level, github-user, etc.
  class Config
    DEFAULTS = {
      'github_user' => ENV.fetch('USER'),
      'gitlab_user' => ENV.fetch('USER'),
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
        if data['github_host']
          data['forge_host'] = data['github_host'] if data['forge_host'].nil?
          data.delete('github_host')
        end
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
            "#{fname}: Not warning about deprecated option `#{opt}` due to " +
            '`ignore_deprecated_options` in that file.',
          )
          next
        end
        SugarJar::Log.warn(
          "#{fname}: contains deprecated option `#{opt}`. You can " +
          'suppress this warning with `ignore_deprecated_options`.',
        )
      end

      # github_host has special handling
      return unless data['github_host']

      if ignore_deprecated_options.include?('github_host')
        SugarJar::Log.debug(
          "#{fname}: Deprecated option `github_host` found, but not " +
          'warning due to `ignore_deprecated_options` in that file.',
        )
      elsif data.key?('forge_host')
        SugarJar::Log.warn(
          "#{fname}: Deprecated option `github_host` found. " +
          'Ignoring in favor of newer `force_host` option. You can ' +
          'suppress this warning with `ignore_deprecated_options`.',
        )
      else
        SugarJar::Log.warn(
          "#{fname}: Deprecated option `github_host` found. " +
          'Treating it as if it was `forge_host` for now. Please update ' +
          'your config file to use this new option. You can suppress ' +
          'this warning with `ignore_deprecated_options`.',
        )
      end
    end
  end
end
