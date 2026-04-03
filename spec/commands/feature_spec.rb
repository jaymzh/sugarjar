require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:sj) do
    SugarJar::Commands.new({ 'no_change' => true })
  end

  before(:each) do
    expect(sj).to receive(:assert_in_repo!).and_return(true)
  end

  context '#feature' do
    context 'with no specified base' do
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

      it 'checks out a release branch properly' do
        branch = 'v2-branch'
        upstream_release = 'upstream/v2-branch'
        expect(sj).to receive(:all_remotes).and_return(%w{origin upstream})
        expect(sj).to receive(:fprefix).with(branch).and_return(branch)
        expect(sj).to receive(:release_branches).and_return(['v2-branch'])
        expect(sj).to receive(:all_local_branches).at_least(1).times.
          and_return(['main'])
        expect(sj).to receive(:git).with('fetch', 'upstream')
        expect(sj).to receive(:git).
          with('checkout', '-b', branch, upstream_release)
        expect(sj).to receive(:git).with('branch', '-u', upstream_release)
        sj.feature(branch)
      end
    end

    context 'with specified base' do
      it 'creates a branch based on requested local branch with args' do
        branch = 'foo'
        base = 'bar'
        expect(sj).to receive(:all_local_branches).at_least(1).times.
          and_return(['main', base])
        expect(sj).to receive(:fprefix).with(branch).and_return(branch)
        expect(sj).to receive(:fprefix).with(base).and_return(base)
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

      it 'creates a subfeature based on the proper upstream release' do
        base = 'v2-branch'
        upstream_release = 'upstream/v2-branch'
        branch = 'my-v2-work'
        expect(sj).to receive(:all_remotes).and_return(%w{origin upstream})
        expect(sj).to receive(:fprefix).with(branch).and_return(branch)
        expect(sj).to receive(:release_branches).and_return(['v2-branch'])
        expect(sj).to receive(:all_local_branches).at_least(1).times.
          and_return(['main'])
        expect(sj).to receive(:git).with('fetch', 'upstream')
        expect(sj).to receive(:git).
          with('checkout', '-b', branch, upstream_release)
        expect(sj).to receive(:git).with('branch', '-u', upstream_release)
        sj.feature(branch, base)
      end
    end
  end
end
