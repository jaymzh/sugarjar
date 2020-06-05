require_relative 'lib/sugarjar/version'

Gem::Specification.new do |spec|
  spec.name = 'sugarjar'
  spec.version = SugarJar::VERSION
  spec.summary = 'A git/github helper script'
  spec.authors = ['Phil Dibowitz']
  spec.email = ['phil@ipom.com']
  spec.license = 'Apache-2.0'
  spec.homepage = 'https://github.com/jaymzh/sugarjar'
  docs = %w{README.md LICENSE}
  spec.extra_rdoc_files = docs
  spec.files =
    Dir.glob('lib/sugarjar/*.rb') +
    Dir.glob('bin/*.rb') +
    docs

  spec.add_dependency 'mixlib-log'
  spec.add_dependency 'mixlib-shellout'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'mdl'
  spec.add_development_dependency 'rubocop'
end
