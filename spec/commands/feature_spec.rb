require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:sj) do
    SugarJar::Commands.new({ 'no_change' => true })
  end

  context '#feature' do
    it 'creates a branch based on remote-most-main-branch with no args' do
      branch = 'foo'
      expect(sj).to receive(:fprefix).with(branch).and_return(branch)
      expect(sj).to receive(:all_local_branches).at_least(1).times.
        and_return(['main'])
      expect(sj).to receive(:all_remotes).and_return(%w{upstream origin})
      expect(sj).to receive(:git).with('fetch', 'upstream')
      expect(sj).to receive(:git).with(
        'checkout', '-b', branch, 'upstream/main'
      )
      expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
      sj.feature(branch)
    end

    it 'creates a branch based on requested local branch with args' do
      branch = 'foo'
      base = 'bar'
      expect(sj).to receive(:fprefix).with(branch).and_return(branch)
      expect(sj).to receive(:fprefix).with(base).and_return(base)
      expect(sj).to receive(:all_local_branches).at_least(1).times.
        and_return(['main', base])
      expect(sj).to receive(:git).with('checkout', '-b', branch, base)
      expect(sj).to receive(:git).with('branch', '-u', base)
      sj.feature(branch, base)
    end

    it 'creates a branch based on requested remote branch with args' do
      branch = 'foo'
      base = 'upstream/bar'
      expect(sj).to receive(:fprefix).with(branch).and_return(branch)
      expect(sj).to receive(:fprefix).with(base).and_return(base)
      expect(sj).to receive(:all_local_branches).at_least(1).times.
        and_return(['main'])
      expect(sj).to receive(:git).with('fetch', 'upstream')
      expect(sj).to receive(:git).with('checkout', '-b', branch, base)
      expect(sj).to receive(:git).with('branch', '-u', base)
      sj.feature(branch, base)
    end
  end
end
