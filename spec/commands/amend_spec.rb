require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:sj) do
    SugarJar::Commands.new({ 'no_change' => true, 'github_user' => 'myuser' })
  end

  context '#amend' do
    it 'calls git ammend properly when no additional args are passed' do
      git = '/usr/bin/git'
      allow(sj).to receive(:assert_in_repo!)
      allow(sj).to receive(:which).with('git').and_return(git)

      expect(sj).to receive(:system).with(git, 'commit', '--amend').
        and_return(true)

      expect(sj).to receive(:exit).with(true)
      sj.amend
    end

    it 'calls git ammend with additional args' do
      git = '/usr/bin/git'
      allow(sj).to receive(:assert_in_repo!)
      allow(sj).to receive(:which).with('git').and_return(git)

      expect(sj).to receive(:system).with(git, 'commit', '--amend', '-s').
        and_return(true)

      expect(sj).to receive(:exit).with(true)
      sj.amend('-s')
    end
  end

  context '#qamend' do
    it 'calls git ammend properly when no additional args are passed' do
      allow(sj).to receive(:assert_in_repo!)

      so = double({ 'stdout' => 'some output' })
      expect(sj).to receive(:git).with('commit', '--amend', '--no-edit').
        and_return(so)

      sj.qamend
    end

    it 'calls git ammend with additional args' do
      git = '/usr/bin/git'
      allow(sj).to receive(:assert_in_repo!)
      allow(sj).to receive(:which).with('git').and_return(git)

      so = double({ 'stdout' => 'some output' })
      expect(sj).to receive(:git).with('commit', '--amend', '--no-edit', '-s').
        and_return(so)

      sj.qamend('-s')
    end
  end
end
