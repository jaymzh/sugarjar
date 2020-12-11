require_relative 'lib/sugarjar/version'

Gem::Specification.new do |spec|
  spec.name = 'sugarjar'
  spec.version = SugarJar::VERSION
  spec.summary = 'A git/github helper script'
  spec.authors = ['Phil Dibowitz']
  spec.email = ['phil@ipom.com']
  spec.license = 'Apache-2.0'
  spec.homepage = 'https://github.com/jaymzh/sugarjar'
  spec.required_ruby_version = '>= 2.6.0'
  docs = %w{README.md LICENSE Gemfile sugarjar.gemspec}
  spec.extra_rdoc_files = docs
  spec.executables << 'sj'
  spec.files =
    Dir.glob('lib/sugarjar/*.rb') +
    Dir.glob('bin/*') +
    docs

  spec.add_dependency 'mixlib-log'
  spec.add_dependency 'mixlib-shellout'
  spec.add_dependency 'pastel'
end
