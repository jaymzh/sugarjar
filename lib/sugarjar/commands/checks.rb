class SugarJar
  class Commands
    def lint
      assert_in_repo!
      if dirty?
        if @ignore_dirty
          SugarJar::Log.warn(
            'Your repo is dirty, but --ignore-dirty was specified, so ' +
            'carrying on anyway. If the linter autocorrects, the displayed ' +
            'diff will be misleading',
          )
        else
          SugarJar::Log.error(
            'Your repo is dirty, but --ignore-dirty was not specified. ' +
            'Refusing to run lint. This is to ensure that if the linter ' +
            'autocorrects, we can show the correct diff.',
          )
          exit(1)
        end
      end
      exit(1) unless run_check('lint')
    end

    def unit
      assert_in_repo!
      exit(1) unless run_check('unit')
    end

    def get_checks_from_command(type)
      return nil unless @repo_config["#{type}_list_cmd"]

      cmd = @repo_config["#{type}_list_cmd"]
      short = cmd.split.first
      unless File.exist?(short)
        SugarJar::Log.error(
          "Configured #{type}_list_cmd #{short} does not exist!",
        )
        return false
      end
      s = Mixlib::ShellOut.new(cmd).run_command
      if s.error?
        SugarJar::Log.error(
          "#{type}_list_cmd (#{cmd}) failed: #{s.format_for_exception}",
        )
        return false
      end
      s.stdout.split("\n")
    end

    # determine if we're using the _list_cmd and if so run it to get the
    # checks, or just use the directly-defined check, and cache it
    def get_checks(type)
      return @checks[type] if @checks[type]

      ret = get_checks_from_command(type)
      if ret
        SugarJar::Log.debug("Found #{type}s: #{ret}")
        @checks[type] = ret
      # if it's explicitly false, we failed to run the command
      elsif ret == false
        @checks[type] = false
      # otherwise, we move on (basically: it's nil, there was no _list_cmd)
      else
        SugarJar::Log.debug("[#{type}]: using listed linters: #{ret}")
        @checks[type] = @repo_config[type] || []
      end
      @checks[type]
    end

    def run_check(type)
      Dir.chdir repo_root do
        checks = get_checks(type)
        # if we failed to determine the checks, the the checks have effectively
        # failed
        return false unless checks

        checks.each do |check|
          SugarJar::Log.debug("Running #{type} #{check}")

          short = check.split.first
          if short.include?('/')
            short = File.join(repo_root, short) unless short.start_with?('/')
            unless File.exist?(short)
              SugarJar::Log.error("Configured #{type} #{short} does not exist!")
            end
          elsif !which_nofail(short)
            SugarJar::Log.error("Configured #{type} #{short} does not exist!")
            return false
          end
          s = Mixlib::ShellOut.new(check).run_command

          # Linters auto-correct, lets handle that gracefully
          if type == 'lint' && dirty?
            SugarJar::Log.info(
              "[#{type}] #{short}: #{color('Corrected', :yellow)}",
            )
            SugarJar::Log.warn(
              "The linter modified the repo. Here's the diff:\n",
            )
            puts git('diff').stdout
            loop do
              $stdout.print(
                "\nWould you like to\n\t[q]uit and inspect\n\t[a]mend the " +
                "changes to the current commit and re-run\n  > ",
              )
              ans = $stdin.gets.strip
              case ans
              when /^q/
                SugarJar::Log.info('Exiting at user request.')
                exit(1)
              when /^a/
                qamend('-a')
                # break here, if we get out of this loop we 'redo', assuming
                # the user chose this option
                break
              end
            end
            redo
          end

          if s.error?
            SugarJar::Log.info(
              "[#{type}] #{short} #{color('failed', :red)}, output follows " +
              "(see debug for more)\n#{s.stdout}",
            )
            SugarJar::Log.debug(s.format_for_exception)
            return false
          end
          SugarJar::Log.info(
            "[#{type}] #{short}: #{color('OK', :green)}",
          )
        end
      end
    end
  end
end
