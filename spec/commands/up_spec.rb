require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:sj) do
    SugarJar::Commands.new({ 'no_change' => true })
  end

  context '#rebase' do
    it 'uses remote tracked branch, if it exists' do
      expect(sj).to receive(:fetch_upstream)
      expect(sj).to receive(:current_branch).and_return('foo')
      expect(sj).to receive(:tracked_branch).with(:fallback => false).
        and_return('upstream/main')
      expect(sj).to receive(:git_nofail).with('rebase', 'upstream/main')
      sj.send(:rebase)
    end

    it 'uses local tracked branch, if it exists' do
      expect(sj).to receive(:fetch_upstream)
      expect(sj).to receive(:current_branch).and_return('foo')
      expect(sj).to receive(:tracked_branch).with(:fallback => false).
        and_return('bar')
      expect(sj).to receive(:git_nofail).with('rebase', 'bar')
      sj.send(:rebase)
    end

    it 'uses most-main if no tracked branch' do
      expect(sj).to receive(:fetch_upstream)
      expect(sj).to receive(:current_branch).and_return('foo')
      expect(sj).to receive(:tracked_branch).with(:fallback => false).
        and_return(nil)
      expect(sj).to receive(:all_remotes).and_return(%w{upstream origin})
      expect(sj).to receive(:all_local_branches).at_least(1).times.
        and_return(%w{main foo})
      expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
      expect(sj).to receive(:git_nofail).with('rebase', 'upstream/main')
      sj.send(:rebase)
    end

    it 'warns about potentially incorrect tracked branches' do
      expect(sj).to receive(:fetch_upstream)
      expect(sj).to receive(:current_branch).and_return('foo')
      expect(sj).to receive(:tracked_branch).with(:fallback => false).
        and_return('origin/foo')
      expect(sj).to receive(:all_remotes).and_return(%w{upstream origin})
      expect(sj).to receive(:all_local_branches).at_least(1).times.
        and_return(%w{main foo})
      expect(SugarJar::Log).to receive(:warn).with(/rebasing on the wrong/)
      expect(sj).to receive(:git_nofail).with('rebase', 'origin/foo')
      sj.send(:rebase)
    end
  end
end
