# require 'spec_helper'
require_relative '../lib/sugarjar/commands'

describe 'SugarJar::Commands' do
  context 'set_commit_template' do
    it 'Does nothing if not in repo' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        { 'commit_template' => '.commit_template.txt' },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj).to receive(:in_repo).and_return(false)
      expect(SugarJar::Log).to receive(:debug).with(/Skipping/)
      sj.send(:set_commit_template)
    end

    it 'Errors out of template does not exist' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        { 'commit_template' => '.commit_template.txt' },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj).to receive(:in_repo).and_return(true)
      expect(sj).to receive(:repo_root).and_return('/nonexistent')
      expect(File).to receive(:exist?)
        .with('/nonexistent/.commit_template.txt').and_return(false)
      expect(SugarJar::Log).to receive(:fatal).with(/exist/)
      expect { sj.send(:set_commit_template) }.to raise_error(SystemExit)
    end

    it 'Does not set the template if it is already set' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        { 'commit_template' => '.commit_template.txt' },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj).to receive(:in_repo).and_return(true)
      expect(sj).to receive(:repo_root).and_return('/nonexistent')
      expect(File).to receive(:exist?)
        .with('/nonexistent/.commit_template.txt').and_return(true)
      so = double('shell_out')
      expect(so).to receive(:error?).and_return(false)
      expect(so).to receive(:stdout).and_return(".commit_template.txt\n")
      expect(sj).to receive(:hub_nofail).and_return(so)
      expect(SugarJar::Log).to receive(:debug).with(/already/)
      sj.send(:set_commit_template)
    end

    it 'warns (and sets) if overwriting template' do
      expect(SugarJar::RepoConfig).to receive(:config).and_return(
        { 'commit_template' => '.commit_template.txt' },
      )
      sj = SugarJar::Commands.new({ 'no_change' => true })
      expect(sj).to receive(:in_repo).and_return(true)
      expect(sj).to receive(:repo_root).and_return('/nonexistent')
      expect(File).to receive(:exist?)
        .with('/nonexistent/.commit_template.txt').and_return(true)
      so = double('shell_out')
      expect(so).to receive(:error?).and_return(false)
      expect(so).to receive(:stdout).and_return(".not_commit_template.txt\n")
      expect(sj).to receive(:hub_nofail).and_return(so)
      expect(sj).to receive(:hub).with(
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
      expect(sj).to receive(:in_repo).and_return(true)
      expect(sj).to receive(:repo_root).and_return('/nonexistent')
      expect(File).to receive(:exist?)
        .with('/nonexistent/.commit_template.txt').and_return(true)
      so = double('shell_out')
      expect(so).to receive(:error?).and_return(true)
      expect(sj).to receive(:hub_nofail).and_return(so)
      expect(sj).to receive(:hub).with(
        'config', '--local', 'commit.template', '.commit_template.txt'
      )
      expect(SugarJar::Log).to receive(:debug).with(/^Setting/)
      sj.send(:set_commit_template)
    end
  end
end
