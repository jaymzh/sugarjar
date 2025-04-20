require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:sj) do
    SugarJar::Commands.new({ 'no_change' => true, 'github_user' => 'myuser' })
  end

  context '#smartclone' do
    it 'uses git if the repo is in our own org' do
      repo = 'git@github.com:myuser/repo.git'
      expect(sj).to_not receive(:ghcli)
      expect(sj).to receive(:git).with('clone', repo, 'repo')
      sj.smartclone(repo)
    end

    it 'uses gh if the repo is not in our own org and sets upstream' do
      repo = 'git@github.com:somethingelse/repo.git'
      expect(sj).to receive(:ghcli).with(
        'repo', 'fork', '--clone', repo, 'repo'
      )
      expect(Dir).to receive(:chdir).with('repo').and_yield
      expect(sj).to receive(:main_branch).and_return('main')
      expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
      sj.smartclone(repo)
    end

    it 'passes additional arguments to git clone' do
      repo = 'git@github.com:myuser/repo.git'
      expect(sj).to_not receive(:ghcli)
      expect(sj).to receive(:git).with('clone', repo, 'somedir', '--something')
      sj.smartclone(repo, 'somedir', '--something')
    end

    it 'passes additional arguments to gh repo fork' do
      repo = 'git@github.com:somethingelse/repo.git'
      expect(sj).to receive(:ghcli).with(
        'repo', 'fork', '--clone', repo, 'somedir', '--something'
      )
      expect(Dir).to receive(:chdir).with('somedir').and_yield
      expect(sj).to receive(:main_branch).and_return('main')
      expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
      sj.smartclone(repo, 'somedir', '--something')
    end
  end
end
