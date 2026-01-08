require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:sj) do
    SugarJar::Commands.new({ 'no_change' => true })
  end

  context '#safe_to_clean?' do
    it 'Allows cleanup when cherry -v shows no delta' do
      expect(sj).to receive(:tracked_branch).with('foo').
        and_return('origin/main')
      so = double({ 'stdout' => '' })
      expect(sj).to receive(:git).with('cherry', '-v', 'origin/main', 'foo').
        and_return(so)
      expect(sj.send(:safe_to_clean?, 'foo')).to eq(true)
    end

    it 'Allows cleanup when cherry -v shows no important delta' do
      expect(sj).to receive(:tracked_branch).with('foo').
        and_return('origin/main')
      so = double({ 'stdout' => "- aabbcc0 something\n-bbccdd1 another\n" })
      expect(sj).to receive(:git).with('cherry', '-v', 'origin/main', 'foo').
        and_return(so)
      expect(sj.send(:safe_to_clean?, 'foo')).to eq(true)
    end

    it 'Does not allow cleanup when we fail to build our merge test branch' do
      branch = 'foo'
      tracked_branch = 'origin/main'
      tmp_branch = '_sugar_jar.123'

      expect(sj).to receive(:tracked_branch).and_return(tracked_branch)
      so = double({ 'stdout' => "+ aabbcc0 something\n" })
      expect(sj).to receive(:git).with('cherry', '-v', tracked_branch, branch).
        and_return(so)
      expect(Process).to receive(:pid).and_return(123)
      expect(sj).to receive(:git).with(
        'checkout', '-b', tmp_branch, tracked_branch
      )
      so2 = double({ 'error?' => true })
      expect(sj).to receive(:git_nofail).with('merge', '--squash', branch).
        and_return(so2)
      expect(sj).to receive(:cleanup_tmp_branch).
        with(tmp_branch, branch, tracked_branch)
      expect(sj.send(:safe_to_clean?, branch)).to eq(false)
    end

    it 'Does not allow cleanup when merge test branch shows delta' do
      branch = 'foo'
      tracked_branch = 'origin/main'
      tmp_branch = '_sugar_jar.123'

      expect(sj).to receive(:tracked_branch).and_return(tracked_branch)
      so = double({ 'stdout' => "+ aabbcc0 something\n" })
      expect(sj).to receive(:git).with('cherry', '-v', tracked_branch, branch).
        and_return(so)
      expect(Process).to receive(:pid).and_return(123)
      expect(sj).to receive(:git).with(
        'checkout', '-b', tmp_branch, tracked_branch
      )
      so2 = double({ 'error?' => false })
      expect(sj).to receive(:git_nofail).with('merge', '--squash', branch).
        and_return(so2)
      so3 = double({ 'stdout' => 'here is output' })
      expect(sj).to receive(:git).with('diff', '--staged').and_return(so3)
      expect(sj).to receive(:cleanup_tmp_branch).
        with(tmp_branch, branch, tracked_branch)
      expect(sj.send(:safe_to_clean?, branch)).to eq(false)
    end

    it 'Does allows cleanup when merge test branch shows no delta' do
      branch = 'foo'
      tracked_branch = 'origin/main'
      tmp_branch = '_sugar_jar.123'

      expect(sj).to receive(:tracked_branch).and_return(tracked_branch)
      so = double({ 'stdout' => "+ aabbcc0 something\n" })
      expect(sj).to receive(:git).with('cherry', '-v', tracked_branch, branch).
        and_return(so)
      expect(Process).to receive(:pid).and_return(123)
      expect(sj).to receive(:git).with(
        'checkout', '-b', tmp_branch, tracked_branch
      )
      so2 = double({ 'error?' => false })
      expect(sj).to receive(:git_nofail).with('merge', '--squash', branch).
        and_return(so2)

      so3 = double({ 'stdout' => '' })
      expect(sj).to receive(:git).with('diff', '--staged').and_return(so3)
      expect(sj).to receive(:cleanup_tmp_branch).
        with(tmp_branch, branch, tracked_branch)
      expect(sj.send(:safe_to_clean?, branch)).to eq(true)
    end

    it 'Uses the correct base for detecting delta' do
      expect(sj).to receive(:tracked_branch).with('feature/foo').
        and_return('origin/develop')
      so = double({ 'stdout' => '' })
      expect(sj).to receive(:git).
        with('cherry', '-v', 'origin/develop', 'feature/foo').
        and_return(so)
      expect(sj.send(:safe_to_clean?, 'feature/foo')).to eq(true)
    end
  end
end
