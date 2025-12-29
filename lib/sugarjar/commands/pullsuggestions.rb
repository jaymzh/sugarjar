require_relative '../util'

class SugarJar
  class Commands
    def pullsuggestions
      assert_in_repo!
      dirty_check!

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
          git = SugarJar::Util.which('git')
          system(git, 'merge', '--ff', "origin/#{current_branch}")
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
