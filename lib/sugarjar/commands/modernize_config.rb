class SugarJar
  class Commands
    def modernizeconfig(config)
      data = YAML.safe_load_file(config)
      data = _modernize(data)
      puts data.to_yaml
    end
    alias fixconfig modernizeconfig

    def _modernize(data)
      data['host_configs'] ||= {}
      data['host_configs']['default'] ||= {}

      # First, take anything that used to be a top-level config
      # that's now a host config and move it to host_configs->default
      %w{use_forks feature_prefix}.each do |tlc|
        # this needs to return true even if the value is false-y
        next unless data.key?(tlc)

        if data['host_configs']['default'][tlc]
          if data['host_configs']['default'][tlc] != data[tlc]
            SugarJar::Log.warn(
              "host_configs->default->#{tlc} already set to something" +
              " different than deprecated top-level #{tlc}, so just deleting" +
              ' old top-level config.',
            )
          end
        else
          data['host_configs']['default'][tlc] = data[tlc]
        end

        # we delete it either way, just only warn if it's different
        data.delete(tlc)
      end

      # Users move into the default config, plus other userless hosts
      # of that type
      %w{github gitlab}.each do |forge|
        tlc = "#{forge}_user"
        site = "#{forge}.com"
        next unless data[tlc]

        # start with the "default site" for this user (github.com/gitlab.com)
        if data.dig('host_configs', site, 'user')
          if data['host_configs'][site]['user'] != data[tlc]
            SugarJar::Log.warn(
              "host_configs->#{site}->user already set to something" +
              " different than deprecated top-level #{tlc}, so just" +
              ' deleting old top-level config.',
            )
          end
        else
          data['host_configs'][site] ||= {}
          data['host_configs'][site]['user'] = data[tlc]
        end

        # now loop through any existing hosts that have been configured that
        # are NOT those default hosts... IFthey don't have a user, populate
        # with the relevant top-level user as in the old world, we would have
        # fallen back to ${type}_user
        data['host_configs'].each do |host, cfg|
          next if host == site
          next unless host.include?(forge)
          next if cfg && cfg['user']

          data['host_configs'][host] ||= {}
          data['host_configs'][host]['user'] = data[tlc]
        end

        # and finally, delete the top-level config
        data.delete(tlc)
      end

      # Remove any unused/deprecated configs.
      #
      # we don't use TOP_LEVEL_CONFIGS here as that includes things
      # that are cli-only
      data.slice(*SugarJar::Config::DEFAULTS.keys)
    end
  end
end
