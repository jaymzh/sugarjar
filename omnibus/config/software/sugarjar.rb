require_relative '../../../lib/sugarjar/version'

name 'sugarjar'
dependency 'ruby'
license :project_license
default_version "v#{SugarJar::VERSION}"
source :path => "#{Omnibus::Config.project_root}/../",
       :options => { :exclude => ['omnibus'] }

build do
  env = with_standard_compiler_flags(with_embedded_path)
  delete "#{name}-*.gem"
  bundle 'install --without test integration tools maintenance', :env => env
  gem "build #{name}.gemspec", :env => env
  gem "install #{name}-*.gem --no-document", :env => env

  block do
    appbundle 'sugarjar', :lockdir => project_dir, :gem => 'sugarjar',
                          :env => env
  end
end
