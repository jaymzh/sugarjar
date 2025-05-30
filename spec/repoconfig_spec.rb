require_relative '../lib/sugarjar/repoconfig'

describe 'SugarJar::RepoConfig' do
  context '#config' do
    it 'properly reads config' do
      expected = {
        'lint' => [
          'somecommand',
          'another command',
        ],
        'unit' => [
          'test',
        ],
        'on_push' => [
          'lint',
        ],
      }
      expect(SugarJar::Util).to receive(:in_repo?).and_return(true)
      expect(SugarJar::RepoConfig).to receive(:repo_config_path).
        and_return('some_path')
      expect(SugarJar::RepoConfig).to receive(:config_file?).with('some_path').
        and_return(true)
      expect(YAML).to receive(:safe_load_file).and_return(expected)
      data = SugarJar::RepoConfig.config('whatever')
      # we gave it expected, this test basically makes sure we don't
      # break the data along the way
      expect(data).to eq(expected)
    end

    it 'merges include_from into config' do
      base = {
        'include_from' => 'additional',
        'top1' => ['entryA'],
        'top2' => {
          'top2key1' => 'a',
          'top2key2' => 'b',
        },
      }
      additional = {
        # array merge
        'top1' => ['entryB'],
        'top2' => {
          # key overwrite
          'top2key1' => 'new',
          # additional key
          'top2key3' => 'c',
        },
      }
      expected = {
        'top1' => %w{entryA entryB},
        'top2' => {
          'top2key1' => 'new',
          'top2key2' => 'b',
          'top2key3' => 'c',
        },
      }
      expect(SugarJar::Util).to receive(:in_repo?).at_least(1).times.
        and_return(true)
      allow(SugarJar::RepoConfig).to receive(:repo_config_path).
        with('base').and_return('base')
      allow(SugarJar::RepoConfig).to receive(:repo_config_path).
        with('additional').and_return('additional')
      allow(SugarJar::RepoConfig).to receive(:config_file?).
        and_return(true)
      allow(SugarJar::RepoConfig).to receive(:hash_from_file).
        with('base').and_return(base)
      allow(SugarJar::RepoConfig).to receive(:hash_from_file).
        with('additional').and_return(additional)
      data = SugarJar::RepoConfig.config('base')
      expect(data).to eq(expected)
    end

    it 'overwrites config with overwrite_from' do
      base = {
        'overwrite_from' => 'additional',
        'top1' => ['entryA'],
        'top2' => {
          'top2key1' => 'a',
          'top2key2' => 'b',
        },
      }
      additional = {
        'new' => ['thing'],
      }
      expect(SugarJar::Util).to receive(:in_repo?).at_least(1).times.
        and_return(true)
      %w{base additional}.each do |word|
        allow(SugarJar::RepoConfig).to receive(:repo_config_path).
          with(word).and_return(word)
      end
      allow(SugarJar::RepoConfig).to receive(:config_file?).
        and_return(true)
      allow(SugarJar::RepoConfig).to receive(:hash_from_file).
        with('base').and_return(base)
      allow(SugarJar::RepoConfig).to receive(:hash_from_file).
        with('additional').and_return(additional)
      data = SugarJar::RepoConfig.config('base')
      # it doesn't matter what's in 'base', we should get 'additional' back
      expect(data).to eq(additional)
    end

    it 'handles recursive includes' do
      base = {
        'include_from' => 'additional',
        'top1' => ['entryA'],
        'top2' => {
          'top2key1' => 'a',
          'top2key2' => 'b',
        },
      }
      additional = {
        # array merge
        'include_from' => 'more',
        'top1' => ['entryB'],
        'top2' => {
          # key overwrite
          'top2key1' => 'new',
          # additional key
          'top2key3' => 'c',
        },
      }
      more = {
        'other stuff' => {
          'things' => 'stuff',
        },
      }
      expected = {
        'top1' => %w{entryA entryB},
        'top2' => {
          'top2key1' => 'new',
          'top2key2' => 'b',
          'top2key3' => 'c',
        },
        'other stuff' => {
          'things' => 'stuff',
        },
      }
      expect(SugarJar::Util).to receive(:in_repo?).at_least(1).times.
        and_return(true)
      %w{base additional more}.each do |word|
        allow(SugarJar::RepoConfig).to receive(:repo_config_path).
          with(word).and_return(word)
      end
      allow(SugarJar::RepoConfig).to receive(:config_file?).
        and_return(true)
      allow(SugarJar::RepoConfig).to receive(:hash_from_file).
        with('base').and_return(base)
      allow(SugarJar::RepoConfig).to receive(:hash_from_file).
        with('additional').and_return(additional)
      allow(SugarJar::RepoConfig).to receive(:hash_from_file).
        with('more').and_return(more)
      data = SugarJar::RepoConfig.config('base')
      expect(data).to eq(expected)
    end

    it "doesn't overwrite from non-existent files" do
      base = {
        'include_from' => 'additional',
        'top1' => ['entryA'],
        'top2' => {
          'top2key1' => 'a',
          'top2key2' => 'b',
        },
      }
      additional = {
        'something' => 'else',
      }
      expect(SugarJar::Util).to receive(:in_repo?).at_least(1).times.
        and_return(true)
      %w{base additional}.each do |word|
        allow(SugarJar::RepoConfig).to receive(:repo_config_path).
          with(word).and_return(word)
      end
      allow(SugarJar::RepoConfig).to receive(:config_file?).
        with('base').and_return(true)
      allow(SugarJar::RepoConfig).to receive(:config_file?).
        with('additional').and_return(true)
      allow(SugarJar::RepoConfig).to receive(:hash_from_file).
        with('base').and_return(base)
      allow(SugarJar::RepoConfig).to receive(:hash_from_file).
        with('additional').and_return(additional)
      data = SugarJar::RepoConfig.config('base')
      expect(data).to eq(data)
    end
  end
end
