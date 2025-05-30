require_relative 'lib/sugarjar/version'

Gem::Specification.new do |spec|
  spec.name = 'sugarjar'
  spec.version = SugarJar::VERSION
  spec.summary = 'A git/github helper script'
  spec.authors = ['Phil Dibowitz']
  spec.email = ['phil@ipom.com']
  spec.license = 'Apache-2.0'
  spec.homepage = 'https://github.com/jaymzh/sugarjar'
  spec.required_ruby_version = '>= 3.2'
  docs = %w{
    README.md
    LICENSE
    Gemfile
    sugarjar.gemspec
    CONTRIBUTING.md
    CHANGELOG.md
  } + Dir.glob('examples/*')
  spec.extra_rdoc_files = docs
  spec.executables << 'sj'
  spec.files =
    Dir.glob('lib/sugarjar/*.rb') +
    Dir.glob('lib/sugarjar/commands/*.rb') +
    Dir.glob('bin/*') +
    Dir.glob('extras/*')

  spec.add_dependency 'deep_merge'
  spec.add_dependency 'mixlib-log'
  spec.add_dependency 'mixlib-shellout'
  spec.add_dependency 'pastel'
  spec.metadata = {
    'rubygems_mfa_required' => 'true',
    'bug_tracker_uri' => 'https://github.com/jaymzh/sugarjar/issues',
    'changelog_uri' =>
      'https://github.com/jaymzh/sugarjar/blob/main/CHANGELOG.md',
    'homepage_uri' => 'https://github.com/jaymzh/sugarjar',
    'source_code_uri' => 'https://github.com/jaymzh/sugarjar',
  }
end
