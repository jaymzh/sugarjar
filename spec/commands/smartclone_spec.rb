require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:opts) do
    { 'no_change' => true, 'github_user' => 'myuser' }
  end
  context '#smartclone' do
    let(:sj) do
      SugarJar::Commands.new(opts)
    end

    context 'repo is in our own org' do
      let(:repo) do
        'git@github.com:myuser/repo.git'
      end

      it 'uses git' do
        repo = 'git@github.com:myuser/repo.git'
        sj.instance_variable_set(:@forge_user, opts['github_user'])
        expect(sj).to_not receive(:forge)
        expect(sj).to receive(:git).with('clone', repo, 'repo')
        sj.smartclone(repo)
      end

      it 'passes additional arguments to git' do
        sj.instance_variable_set(:@forge_user, opts['github_user'])
        expect(sj).to_not receive(:forge)
        expect(sj).to receive(:git).with('clone', repo, 'somedir',
                                         '--something')
        sj.smartclone(repo, 'somedir', '--something')
      end
    end

    context 'repo is not in our own org' do
      context 'github' do
        let(:opts) do
          {
            'no_change' => true,
            'github_user' => 'myuser',
            'forge_type' => 'github',
          }
        end

        let(:repo) do
          'git@github.com:somethingelse/repo.git'
        end

        it 'uses forge and sets upstream' do
          expect(sj).to receive(:forge).with(
            'repo', 'fork', '--clone', repo, 'repo'
          )
          expect(Dir).to receive(:chdir).with('repo').and_yield
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo)
        end

        it 'passes additional arguments to gh repo fork' do
          expect(sj).to receive(:forge).with(
            'repo', 'fork', '--clone', repo, 'somedir', '--something'
          )
          expect(Dir).to receive(:chdir).with('somedir').and_yield
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo, 'somedir', '--something')
        end
      end

      context 'gitlab' do
        let(:opts) do
          {
            'no_change' => true,
            'github_user' => 'myuser',
            'forge_type' => 'gitlab',
          }
        end

        let(:repo) do
          'git@gitlab.com:somethingelse/repo.git'
        end

        let(:shell_out) do
          double('shell_out')
        end

        it 'uses forge and sets upstream' do
          expect(sj).to receive(:forge_nofail).with(
            'repo', 'fork', 'somethingelse/repo', '--clone=false'
          ).and_return(shell_out)
          expect(shell_out).to receive(:error?).and_return(false)
          expect(sj).to receive(:git).with('clone', repo, 'repo')
          expect(Dir).to receive(:chdir).with('repo').exactly(2).times.and_yield
          expect(sj).to receive(:git).with('remote', 'rename', 'origin',
                                           'upstream')
          expect(sj).to receive(:forked_repo).and_return(
            'git@gitlab.com:myuser/repo.git',
          )
          expect(sj).to receive(:git).with(
            'remote', 'add', 'origin', 'git@gitlab.com:myuser/repo.git'
          )
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo)
        end

        it 'ignores error 409 from "glab repo fork"' do
          expect(sj).to receive(:forge_nofail).with(
            'repo', 'fork', 'somethingelse/repo', '--clone=false'
          ).and_return(shell_out)
          expect(shell_out).to receive(:error?).and_return(true)
          expect(shell_out).to receive(:stderr).and_return(' 409 ')
          expect(sj).to receive(:git).with('clone', repo, 'repo')
          expect(Dir).to receive(:chdir).with('repo').exactly(2).times.and_yield
          expect(sj).to receive(:git).with('remote', 'rename', 'origin',
                                           'upstream')
          expect(sj).to receive(:forked_repo).and_return(
            'git@gitlab.com:myuser/repo.git',
          )
          expect(sj).to receive(:git).with(
            'remote', 'add', 'origin', 'git@gitlab.com:myuser/repo.git'
          )
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo)
        end

        it 'passes additional arguments to git clone' do
          expect(sj).to receive(:forge_nofail).with(
            'repo', 'fork', 'somethingelse/repo', '--clone=false'
          ).and_return(shell_out)
          expect(shell_out).to receive(:error?).and_return(false)
          expect(sj).to receive(:git).with('clone', repo, 'somedir',
                                           '--something')
          expect(Dir).to receive(:chdir).with('somedir').exactly(2).
            times.and_yield
          expect(sj).to receive(:git).with('remote', 'rename', 'origin',
                                           'upstream')
          expect(sj).to receive(:forked_repo).and_return(
            'git@gitlab.com:myuser/repo.git',
          )
          expect(sj).to receive(:git).with(
            'remote', 'add', 'origin', 'git@gitlab.com:myuser/repo.git'
          )
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo, 'somedir', '--something')
        end
      end
    end
  end
end
