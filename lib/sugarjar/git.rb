require_relative 'util'

class SugarJar
  module Git
    def self.run_nofail(*args, color: true)
      if %w{diff log grep branch}.include?(args[0]) &&
         args.none? { |x| x.include?('color') }
        args << (color ? '--color' : '--no-color')
      end
      SugarJar::Log.trace("Running: git #{args.join(' ')}")
      Mixlib::ShellOut.new([SugarJar::Util.which('git')] + args).run_command
    end

    def self.run(*, color: true)
      s = run_nofail(*, :color => color)
      s.error!
      s
    end

    def self.in_repo?
      s = run_nofail('rev-parse', '--is-inside-work-tree')
      !s.error? && s.stdout.strip == 'true'
    end

    def self.repo_root
      run('rev-parse', '--show-toplevel').stdout.strip
    end
  end
end
