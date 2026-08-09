require 'yaml'
require_relative 'log'
require 'deep_merge'

class SugarJar
  # This parses SugarJar configs (not to be confused with repoconfigs).
  # This is stuff like log level, github-user, etc.
  class Config
    DEFAULTS = {
      'default_forge_host' => nil,
      'pr_autofill' => true,
      'pr_autostack' => nil,
      'color' => true,
      'ignore_deprecated_options' => [],
      'host_configs' => {
        'default' => {
          'user' => ENV.fetch('USER'),
          'use_forks' => true,
        },
      },
    }.freeze

    # things we have a command-line option for, but doesn't make sense
    # in a config file.
    EXTRA_CONFIGS = %w{fork_name force_forge_type}.freeze

    TOP_LEVEL_CONFIGS = (DEFAULTS.keys + EXTRA_CONFIGS).freeze

    DEPRECATED_OPTIONS = %w{
      fallthru
      gh_cli
      github_user
      gitlab_user
      github_host
      gitlab_host
    }.freeze

    def self._find_ordered_files
      real_files = []
      [
        '/etc/sugarjar',
        "#{Dir.home}/.config/sugarjar",
      ].each do |dir|
        %w{yaml yml}.each do |ext|
          f = File.join(dir, "config.#{ext}")
          real_files << f if File.exist?(f)
        end
      end
      real_files
    end

    def self.config
      SugarJar::Log.debug("Defaults: #{DEFAULTS}")
      c = DEFAULTS.dup
      _find_ordered_files.each do |f|
        SugarJar::Log.debug("Loading config #{f}")
        data = YAML.safe_load_file(f)
        next unless data

        warn_on_deprecated_configs(data, f)
        data = data.slice(*TOP_LEVEL_CONFIGS)
        c.deep_merge!(data)
        SugarJar::Log.debug("Modified config: #{c}")
      end
      c
    end

    def self.warn_on_deprecated_configs(data, fname)
      # if it doesn't have host_configs **and** it has one of the
      # previous user options, that were effectively required before
      # and have now moved to host_configs, then we treat it as an
      # old config
      if %w{github_user gitlab_user}.any? { |useropt| data.key?(useropt) } &&
         !data['host_configs']
        SugarJar::Log.warn(
          "#{fname} appears to be an old-style config.\nIt likely will " +
          'not result in the behavior you want. You should run' +
          "\n\n\tsj modernizeconfig #{fname}\n\n" +
          "To automatically convert it.\n",
        )
        return
      end

      ignore_deprecated_options = data['ignore_deprecated_options'] || []
      DEPRECATED_OPTIONS.each do |opt|
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
    end
  end
end
