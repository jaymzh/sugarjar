Gem::Specification.new do |spec|
  spec.name = 'sugarjar'
  spec.version = '0.0.1'
  spec.summary = 'A git/github helper script'
  spec.authors = ['Phil Dibowitz']
  spec.email = ['phil@ipom.com']

  spec.add_dependency 'mixlib-log'
  spec.add_dependency 'mixlib-shellout'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'mdl'
  spec.add_development_dependency 'rubocop'
end
