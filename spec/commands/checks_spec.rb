require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  context '#get_checks_from_command' do
    it 'returns nil if no list_cmd exists' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return({})
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj.get_checks_from_command('lint')).to eq(nil)
      expect(sj.get_checks_from_command('unit')).to eq(nil)
    end

    context 'runs the commands if they exist and returns the results' do
      %w{yaml bare}.each do |outtype|
        it "with #{outtype} output" do
          expect(SugarJar::RepoConfig).to receive(:config).and_return(
            {
              'lint_list_cmd' => 'get_lint_commands',
              'unit_list_cmd' => 'get_unit_commands',
            },
          )
          sj = SugarJar::Commands.new({ 'no_change' => true })
          %w{lint unit}.each do |type|
            checks = %w{one two}.map { |c| "#{type}_#{c}" }
            case outtype
            when 'yaml'
              out = "---\n#{
                checks.map do |c|
                  "- name: #{c}\n  command: #{c}_script.sh"
                end.join("\n")
              }"
            when 'bare'
              out = checks.join("\n") + "\n"
            end

            cmd = "get_#{type}_commands"
            expect(File).to receive(:exist?).with(cmd).and_return(true)
            so = double(
              {
                :error? => false,
                :stdout => out,
              },
            )
            expect(Mixlib::ShellOut).to receive(:new).and_return(so)
            expect(so).to receive(:run_command).and_return(so)
            case outtype
            when 'yaml'
              expect(sj.get_checks_from_command(type)).to eq(
                [
                  {
                    'name' => "#{type}_one",
                    'command' => "#{type}_one_script.sh",
                  },
                  {
                    'name' => "#{type}_two",
                    'command' => "#{type}_two_script.sh",
                  },
                ],
              )
            when 'bare'
              expect(sj.get_checks_from_command(type)).
                to eq(["#{type}_one", "#{type}_two"])
            end
          end
        end
      end
    end
  end

  context '#get_checks' do
    it 'defaults to _cmd variety' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        {
          'lint_list_cmd' => 'get_lint_commands',
          'unit_list_cmd' => 'get_unit_commands',
          'lint' => ['lint_foo'],
          'unit' => ['unit_foo'],
        },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      %w{lint unit}.each do |type|
        expect(sj).to receive(:get_checks_from_command).with(type).
          and_return([
                       "#{type}_cmd1", "#{type}_cmd2"
                     ])
        expect(sj.get_checks(type)).
          to eq(["#{type}_cmd1", "#{type}_cmd2"])
      end
    end

    it 'returns false if _cmd does not exist' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        {
          'lint_list_cmd' => 'get_lint_commands',
          'unit_list_cmd' => 'get_unit_commands',
          'lint' => ['lint_foo'],
          'unit' => ['unit_foo'],
        },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      %w{lint unit}.each do |type|
        cmd = "get_#{type}_commands"
        expect(File).to receive(:exist?).with(cmd).and_return(false)
        expect(sj.get_checks(type)).to eq(false)
      end
    end

    it 'returns false if _cmd fails' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        {
          'lint_list_cmd' => 'get_lint_commands',
          'unit_list_cmd' => 'get_unit_commands',
          'lint' => ['lint_foo'],
          'unit' => ['unit_foo'],
        },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      %w{lint unit}.each do |type|
        cmd = "get_#{type}_commands"
        expect(File).to receive(:exist?).with(cmd).and_return(true)
        so = double({ :error? => true, :format_for_exception => 'error' })
        expect(Mixlib::ShellOut).to receive(:new).with(cmd).and_return(so)
        expect(so).to receive(:run_command).and_return(so)
        expect(sj.get_checks(type)).to eq(false)
      end
    end

    it 'uses static configs if no _cmd variety' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        {
          'lint' => ['lint_foo'],
          'unit' => ['unit_foo'],
        },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      %w{lint unit}.each do |type|
        expect(sj.get_checks(type)).to eq(["#{type}_foo"])
      end
    end
  end

  context '#run_check' do
    it 'amends diff if linter autocorrects and user says yes' do
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(SugarJar::Git).to receive(:repo_root).and_return('root')
      expect(Dir).to receive(:chdir).with('root').and_yield
      expect(sj).to receive(:get_checks).with('lint').
        and_return(['lint_foo'])
      expect(SugarJar::Util).to receive(:which_nofail).with('lint_foo').
        exactly(2).times.and_return('lint_foo')
      so = double({ :stdout => 'some lint output', :error? => false })
      expect(Mixlib::ShellOut).to receive(:new).exactly(2).time.
        with('lint_foo').and_return(so)
      expect(so).to receive(:run_command).exactly(2).times.and_return(so)
      expect(sj).to receive(:dirty?).and_return(true)
      so2 = double({ 'stdout' => 'some diff output' })
      expect(sj).to receive(:git).with('diff').and_return(so2)
      expect($stdout).to receive(:print)
      expect($stdin).to receive(:gets).and_return("a\n")
      expect(sj).to receive(:qamend).with('-a')
      expect(sj).to receive(:dirty?).and_return(false)
      sj.run_check('lint', true)
    end

    it 'quits if linter autocorrects and user says no' do
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(SugarJar::Git).to receive(:repo_root).and_return('root')
      expect(Dir).to receive(:chdir).with('root').and_yield
      expect(sj).to receive(:get_checks).with('lint').
        and_return(['lint_foo'])
      expect(SugarJar::Util).to receive(:which_nofail).with('lint_foo').
        and_return('lint_foo')
      so = double({ :stdout => 'some lint output', :error? => false })
      expect(Mixlib::ShellOut).to receive(:new).with('lint_foo').
        and_return(so)
      expect(so).to receive(:run_command).and_return(so)
      expect(sj).to receive(:dirty?).and_return(true)
      so2 = double({ 'stdout' => 'some diff output' })
      expect(sj).to receive(:git).with('diff').and_return(so2)
      expect($stdout).to receive(:print)
      expect($stdin).to receive(:gets).and_return("q\n")
      expect(sj).to receive(:exit).with(1) do
        raise SystemExit, 1
      end
      expect do
        sj.run_check('lint', true)
      end.to raise_error(SystemExit)
    end

    it 'returns false if the check fails' do
      sj = SugarJar::Commands.new({ 'no_change' => true })
      %w{lint unit}.each do |type|
        cmd = "#{type}_foo"
        expect(SugarJar::Git).to receive(:repo_root).and_return('root')
        expect(Dir).to receive(:chdir).with('root').and_yield
        expect(sj).to receive(:get_checks).with(type).and_return([cmd])
        expect(SugarJar::Util).to receive(:which_nofail).with(cmd).
          and_return(cmd)
        so = double(
          { :stdout => '', :error? => true, :format_for_exception => '' },
        )
        expect(Mixlib::ShellOut).to receive(:new).with(cmd).and_return(so)
        expect(so).to receive(:run_command).and_return(so)
        expect(sj).to receive(:dirty?).and_return(false) if type == 'lint'
        expect(sj.run_check(type, true)).to eq(false)
      end
    end

    it 'handles hash format checks' do
      sj = SugarJar::Commands.new({ 'no_change' => true })
      %w{lint unit}.each do |type|
        name = "#{type}_foo"
        cmd = "#{name}.sh"
        expect(SugarJar::Git).to receive(:repo_root).and_return('root')
        expect(Dir).to receive(:chdir).with('root').and_yield
        expect(sj).to receive(:get_checks).with(type).
          and_return([{ 'name' => name, 'command' => cmd }])
        expect(SugarJar::Util).to receive(:which_nofail).with(cmd).
          and_return("/some/path/#{cmd}")
        so = double({ :stdout => 'some output', :error? => false })
        expect(Mixlib::ShellOut).to receive(:new).
          with(cmd).and_return(so)
        expect(so).to receive(:run_command).and_return(so)
        expect(sj).to receive(:dirty?).and_return(false) if type == 'lint'
        sj.run_check(type, true)
      end
    end
  end
end
