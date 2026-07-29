require_relative '../../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:opts) do
    { 'no_change' => true, 'github_user' => 'myuser', 'use_forks' => true }
  end
  context '#smartclone' do
    let(:sj) do
      SugarJar::Commands.new(opts)
    end

    let(:forge_type) { 'github' }
    let(:forge_double) do
      instance_double(SugarJar::Forge, :type => forge_type)
    end

    before do
      allow(SugarJar::Git).to receive(:in_repo?).and_return(false)
      allow(sj).to receive(:forge).and_return(forge_double)
    end

    context 'repo is in our own org' do
      let(:repo) do
        'git@github.com:myuser/repo.git'
      end

      it 'uses git' do
        expect(forge_double).to_not receive(:run)
        expect(forge_double).to_not receive(:run_nofail)
        expect(sj).to receive(:git).with('clone', repo, 'repo')
        sj.smartclone(repo)
      end

      it 'passes additional arguments to git' do
        expect(forge_double).to_not receive(:run)
        expect(forge_double).to_not receive(:run_nofail)
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
            'host_configs' => {
              'default' => {
                'use_forks' => true,
              },
              'github.com' => {
                'user' => 'myuser',
              },
            },
          }
        end

        let(:repo) do
          'git@github.com:somethingelse/repo.git'
        end

        it 'uses forge and sets upstream' do
          expect(forge_double).to receive(:run).with(
            'repo', 'fork', '--clone', repo, 'repo',
            '--fork-name', 'repo'
          )
          expect(Dir).to receive(:chdir).with('repo').and_yield
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo)
        end

        it 'passes additional arguments to gh repo fork' do
          expect(forge_double).to receive(:run).with(
            'repo', 'fork', '--clone', repo, 'somedir',
            '--fork-name', 'repo', '--something'
          )
          expect(Dir).to receive(:chdir).with('somedir').and_yield
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo, 'somedir', '--something')
        end

        context 'with no_fork set' do
          let(:opts) do
            {
              'no_change' => true,
              'github_user' => 'myuser',
              'forge_type' => 'github',
              'use_forks' => false,
            }
          end

          it 'bypasses fork' do
            expect(forge_double).to_not receive(:run)
            expect(forge_double).to_not receive(:run_nofail)
            expect(sj).to receive(:git).with('clone', repo, 'repo')
            sj.smartclone(repo)
          end
        end
      end

      context 'gitlab' do
        let(:forge_type) { 'gitlab' }
        let(:opts) do
          {
            'no_change' => true,
            'host_configs' => {
              'default' => {
                'use_forks' => true,
              },
              'gitlab.com' => {
                'user' => 'myuser',
              },
            },
          }
        end

        let(:repo) do
          'git@gitlab.com:somethingelse/repo.git'
        end

        let(:shell_out) do
          double('shell_out')
        end

        it 'uses forge and sets upstream' do
          expect(forge_double).to receive(:run_nofail).with(
            'repo', 'fork', 'somethingelse/repo', '--name', 'repo',
            '--clone=false'
          ).and_return(shell_out)
          expect(shell_out).to receive(:error?).and_return(false)
          expect(sj).to receive(:git).with('clone', repo, 'repo')
          expect(Dir).to receive(:chdir).with('repo').exactly(2).times.and_yield
          expect(sj).to receive(:git).with('remote', 'rename', 'origin',
                                           'upstream')
          expect(sj).to receive(:git).with(
            'remote', 'add', 'origin', 'git@gitlab.com:myuser/repo.git'
          )
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo)
        end

        it 'ignores error 409 from "glab repo fork"' do
          expect(forge_double).to receive(:run_nofail).with(
            'repo', 'fork', 'somethingelse/repo', '--name', 'repo',
            '--clone=false'
          ).and_return(shell_out)
          expect(shell_out).to receive(:error?).and_return(true)
          expect(shell_out).to receive(:stderr).and_return(' 409 ')
          expect(sj).to receive(:git).with('clone', repo, 'repo')
          expect(Dir).to receive(:chdir).with('repo').exactly(2).times.and_yield
          expect(sj).to receive(:git).with('remote', 'rename', 'origin',
                                           'upstream')
          expect(sj).to receive(:git).with(
            'remote', 'add', 'origin', 'git@gitlab.com:myuser/repo.git'
          )
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo)
        end

        it 'passes additional arguments to git clone' do
          expect(forge_double).to receive(:run_nofail).with(
            'repo', 'fork', 'somethingelse/repo', '--name', 'repo',
            '--clone=false'
          ).and_return(shell_out)
          expect(shell_out).to receive(:error?).and_return(false)
          expect(sj).to receive(:git).with('clone', repo, 'somedir',
                                           '--something')
          expect(Dir).to receive(:chdir).with('somedir').exactly(2).
            times.and_yield
          expect(sj).to receive(:git).with('remote', 'rename', 'origin',
                                           'upstream')
          expect(sj).to receive(:git).with(
            'remote', 'add', 'origin', 'git@gitlab.com:myuser/repo.git'
          )
          expect(sj).to receive(:main_branch).and_return('main')
          expect(sj).to receive(:git).with('branch', '-u', 'upstream/main')
          sj.smartclone(repo, 'somedir', '--something')
        end

        context 'with no_fork set' do
          let(:opts) do
            {
              'no_change' => true,
              'github_user' => 'myuser',
              'forge_type' => 'github',
              'use_forks' => false,
            }
          end

          it 'bypasses fork' do
            expect(forge_double).to_not receive(:run)
            expect(forge_double).to_not receive(:run_nofail)
            expect(sj).to receive(:git).with('clone', repo, 'repo')
            sj.smartclone(repo)
          end
        end
      end
    end
  end
end
