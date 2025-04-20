# For Ruby packages, Debian autopkgtest runs in an environment where
# gem2deb-test-runner removes the lib directory from the source tree, so
# the specs have to be able to load the installed copy instead.
#
# add '../lib' to the front of the path, so that when requiring modules, the
# ones in '../lib' are still going to be used if available, but we can fall
# back to an installed module
#
# See https://wiki.debian.org/Teams/Ruby/Packaging/Tests#Case_eight:_autopkgtest_failure
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'sugarjar/commands'

describe 'SugarJar::Commands' do
  let(:sj) do
    SugarJar::Commands.new({ 'no_change' => true })
  end

  context '#set_commit_template' do
    it 'Does nothing if not in repo' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        { 'commit_template' => '.commit_template.txt' },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj).to receive(:in_repo?).and_return(false)
      expect(SugarJar::Log).to receive(:debug).with(/Skipping/)
      sj.send(:set_commit_template)
    end

    it 'Errors out of template does not exist' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        { 'commit_template' => '.commit_template.txt' },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj).to receive(:in_repo?).and_return(true)
      expect(sj).to receive(:repo_root).and_return('/nonexistent')
      expect(File).to receive(:exist?).
        with('/nonexistent/.commit_template.txt').and_return(false)
      expect(SugarJar::Log).to receive(:fatal).with(/exist/)
      expect { sj.send(:set_commit_template) }.to raise_error(SystemExit)
    end

    it 'Does not set the template if it is already set' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        { 'commit_template' => '.commit_template.txt' },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj).to receive(:in_repo?).and_return(true)
      expect(sj).to receive(:repo_root).and_return('/nonexistent')
      expect(File).to receive(:exist?).
        with('/nonexistent/.commit_template.txt').and_return(true)
      so = double('shell_out')
      expect(so).to receive(:error?).and_return(false)
      expect(so).to receive(:stdout).and_return(".commit_template.txt\n")
      expect(sj).to receive(:git_nofail).and_return(so)
      expect(SugarJar::Log).to receive(:debug).with(/already/)
      sj.send(:set_commit_template)
    end

    it 'warns (and sets) if overwriting template' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        { 'commit_template' => '.commit_template.txt' },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj).to receive(:in_repo?).and_return(true)
      expect(sj).to receive(:repo_root).and_return('/nonexistent')
      expect(File).to receive(:exist?).
        with('/nonexistent/.commit_template.txt').and_return(true)
      so = double('shell_out')
      expect(so).to receive(:error?).and_return(false)
      expect(so).to receive(:stdout).and_return(".not_commit_template.txt\n")
      expect(sj).to receive(:git_nofail).and_return(so)
      expect(sj).to receive(:git).with(
        'config', '--local', 'commit.template', '.commit_template.txt'
      )
      expect(SugarJar::Log).to receive(:warn).with(/^Updating/)
      sj.send(:set_commit_template)
    end

    it 'sets the template when none is set' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        { 'commit_template' => '.commit_template.txt' },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj).to receive(:in_repo?).and_return(true)
      expect(sj).to receive(:repo_root).and_return('/nonexistent')
      expect(File).to receive(:exist?).
        with('/nonexistent/.commit_template.txt').and_return(true)
      so = double('shell_out')
      expect(so).to receive(:error?).and_return(true)
      expect(sj).to receive(:git_nofail).and_return(so)
      expect(sj).to receive(:git).with(
        'config', '--local', 'commit.template', '.commit_template.txt'
      )
      expect(SugarJar::Log).to receive(:debug).with(/^Setting/)
      sj.send(:set_commit_template)
    end
  end

  context '#fprefix' do
    it 'Adds prefixes when needed' do
      sj = SugarJar::Commands.new(
        { 'no_change' => true, 'feature_prefix' => 'someuser/' },
      )
      expect(sj).to receive(:all_local_branches).and_return(['/nonexistent'])
      expect(sj.send(:fprefix, 'test')).to eq('someuser/test')
    end

    it 'Does not add prefixes when not needed' do
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj.send(:fprefix, 'test')).to eq('test')
    end
  end

  context '#extract_org' do
    [
      # ssh
      'git@github.com:org/repo.git',
      # http
      'http://github.com/org/repo.git',
      # https
      'https://github.com/org/repo.git',
      # gh
      'org/repo',
    ].each do |url|
      it "extracts the org from #{url}" do
        expect(sj.send(:extract_org, url)).to eq('org')
      end
    end
  end

  context '#extract_repo' do
    [
      # ssh
      'git@github.com:org/repo.git',
      # http
      'http://github.com/org/repo.git',
      # https
      'https://github.com/org/repo.git',
      # gh
      'org/repo',
    ].each do |url|
      it "extracts the repo from #{url}" do
        expect(sj.send(:extract_repo, url)).to eq('repo')
      end
    end
  end

  context '#forked_repo' do
    [
      # ssh
      'git@github.com:org/repo.git',
      # http
      'http://github.com/org/repo.git',
      # https
      'https://github.com/org/repo.git',
      # hub
      'org/repo',
    ].each do |url|
      it "generates correct URL from #{url}" do
        expect(sj.send(:forked_repo, url, 'test')).
          to eq('git@github.com:test/repo.git')
      end
    end
  end

  context '#canonicalize_repo' do
    [
      # ssh
      'git@github.com:org/repo.git',
      # http
      'http://github.com/org/repo.git',
      # https
      'https://github.com/org/repo.git',
    ].each do |url|
      it "keeps fully-qualified URL #{url} the same" do
        expect(sj.send(:canonicalize_repo, url)).to eq(url)
      end
    end

    # gh
    url = 'org/repo'
    it "canonicalizes short name #{url}" do
      expect(sj.send(:canonicalize_repo, url)).
        to eq('git@github.com:org/repo.git')
    end
  end
end
