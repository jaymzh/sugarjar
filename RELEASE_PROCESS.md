# Rolling a release

## Prep the release

* Update version number in `lib/sugarjar/version.rb`
* Update the `CHANGELOG.md`
* Create a PR, get it merged

## Tag the release

* Add a tag: `git tag -a v0.0.X -m 'version 0.0.x'
* Push the tag: `git push origin --tags`

## Publish a gem

* Build a gem: `gem build sugarjar.gemspec`
* Push the gem: `gem push sugarjar-0.0.X.gem`

## Publish omnibus builds

* From omnibus directory, prep: `bundle install`
  * For each of Ubuntu 18.04, Debian 9, CentOS7
    * `kitchen converge ubuntu-1804; kitchen login ubuntu-1804`
    * `.  load-omnibus-toolchain.sh`
    * `[ -e .bundle ] && sudo chown -R vagrant:vagrant .bundle`
    * `cd sugarjar/omnibus`
    * `bundle install`
    * `bin/omnibus build sugarjar`
    * `bin/omnibus clean sugarjar` # required so next build works
    * grab/rename the package out of sugarjar/omnibus/pkg
