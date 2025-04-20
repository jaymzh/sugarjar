require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:sj) do
    SugarJar::Commands.new({ 'no_change' => true })
  end

  context '#checkout' do
    it 'attempts to checkout the branch with no feature prefix' do
      branch = 'foo'
      allow(sj).to receive(:assert_in_repo!)
      expect(sj).to receive(:all_local_branches).and_return(['main', branch])
      so = double({ 'stdout' => '', 'stderr' => '' })
      expect(sj).to receive(:git).with('checkout', branch).and_return(so)
      sj.checkout(branch)
    end

    it 'attempts to checkout the branch with feature prefix, if it exists' do
      sj = SugarJar::Commands.new(
        { 'no_change' => true, 'feature_prefix' => 'fp/' },
      )
      branch = 'foo'
      allow(sj).to receive(:assert_in_repo!)
      expect(sj).to receive(:all_local_branches).at_least(1).times.
        and_return(['main',
                    "fp/#{branch}"])
      so = double({ 'stdout' => '', 'stderr' => '' })
      expect(sj).to receive(:git).with('checkout',
                                       "fp/#{branch}").and_return(so)
      sj.checkout(branch)
    end

    it 'will checkout non-prefixed branch if prefixed branch does not exist' do
      sj = SugarJar::Commands.new(
        { 'no_change' => true, 'feature_prefix' => 'fp/' },
      )
      branch = 'foo'
      allow(sj).to receive(:assert_in_repo!)
      expect(sj).to receive(:all_local_branches).at_least(1).times.
        and_return(['main', branch])
      so = double({ 'stdout' => '', 'stderr' => '' })
      expect(sj).to receive(:git).with('checkout', branch).and_return(so)
      sj.checkout(branch)
    end
  end
end
