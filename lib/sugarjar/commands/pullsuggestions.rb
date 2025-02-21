class SugarJar
  class Commands
    def pullsuggestions
      assert_in_repo

      if dirty?
        if @ignore_dirty
          SugarJar::Log.warn(
            'Your repo is dirty, but --ignore-dirty was specified, so ' +
            'carrying on anyway.',
          )
        else
          SugarJar::Log.error(
            'Your repo is dirty, so I am not going to push. Please commit ' +
            'or amend first.',
          )
          exit(1)
        end
      end

      src = "origin/#{current_branch}"
      fetch('origin')
      diff = git('diff', "..#{src}").stdout
      return unless diff && !diff.empty?

      puts "Will merge the following suggestions:\n\n#{diff}"

      loop do
        $stdout.print("\nAre you sure? [y/n] ")
        ans = $stdin.gets.strip
        case ans
        when /^[Yy]$/
          system(which('git'), 'merge', '--ff', "origin/#{current_branch}")
          break
        when /^[Nn]$/, /^[Qq](uit)?/
          puts 'Not merging at user request...'
          break
        else
          puts "Didn't understand '#{ans}'."
        end
      end
    end
    alias ps pullsuggestions
  end
end
