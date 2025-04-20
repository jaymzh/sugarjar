require_relative '../lib/sugarjar/util'

class Test
  include SugarJar::Util
end

describe 'SugarJar::Utils' do
  let(:util) do
    Test.new
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
        expect(util.extract_org(url)).to eq('org')
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
        expect(util.extract_repo(url)).to eq('repo')
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
        expect(util.forked_repo(url, 'test')).
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
        expect(util.canonicalize_repo(url)).to eq(url)
      end
    end

    # gh
    url = 'org/repo'
    it "canonicalizes short name #{url}" do
      expect(util.send(:canonicalize_repo, url)).
        to eq('git@github.com:org/repo.git')
    end
  end
end
