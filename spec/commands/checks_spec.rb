require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  context '#get_checks_from_command' do
    it 'returns nil if no list_cmd exists' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return({})
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj.get_checks_from_command('lint')).to eq(nil)
      expect(sj.get_checks_from_command('unit')).to eq(nil)
    end

    it 'runs the commands if they exist and returns the results' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        {
          'lint_list_cmd' => 'get_lint_commands',
          'unit_list_cmd' => 'get_unit_commands',
        },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      %w{lint unit}.each do |type|
        cmd = "get_#{type}_commands"
        expect(File).to receive(:exist?).with(cmd).and_return(true)
        so = double(
          {
            :error? => false,
            :stdout => "#{type}_one\n#{type}_two\n",
          },
        )
        expect(Mixlib::ShellOut).to receive(:new).and_return(so)
        expect(so).to receive(:run_command).and_return(so)
        expect(sj.get_checks_from_command(type)).
          to eq(["#{type}_one", "#{type}_two"])
      end
    end
  end

  context '#get_checks' do
    it 'defaults to _command variety' do
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

    it 'returns false if _command does not exist' do
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

    it 'returns false if _command fails' do
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

    it 'uses static configs if no _command variety' do
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
      expect(SugarJar::Util).to receive(:repo_root).and_return('root')
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
      sj.run_check('lint')
    end

    it 'quits if linter autocorrects and user says no' do
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(SugarJar::Util).to receive(:repo_root).and_return('root')
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
        sj.run_check('lint')
      end.to raise_error(SystemExit)
    end

    it 'returns false if the check fails' do
      sj = SugarJar::Commands.new({ 'no_change' => true })
      %w{lint unit}.each do |type|
        cmd = "#{type}_foo"
        expect(SugarJar::Util).to receive(:repo_root).and_return('root')
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
        expect(sj.run_check(type)).to eq(false)
      end
    end
  end
end
