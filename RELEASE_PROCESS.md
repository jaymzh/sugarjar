# Rolling a release

## Optionally, update Gemfile.lock

* Update gems with `bundle update --all`
* Test to make sure we work with all new deps

## Prep the release

* Update version number in `lib/sugarjar/version.rb`
* Update the `CHANGELOG.md`
* Create a PR, get it merged

## Tag the release

* version='0.0.X'
* Add a tag: `git tag -a v${version?} -m "version ${version?}" -s`
* Push the tag: `git push origin --tags`

## Publish a gem

* Build a gem: `gem build sugarjar.gemspec`
* Push the gem: `gem push sugarjar-${version?}.gem`

## Publish Fedora builds

See [packaging/README.md](packaging/README.md).

## Notify Debian/Ubuntu packager

Ping Michel Lind

## Update Homebrew

Open a PR against the [Homebrew
Formula](https://github.com/Homebrew/homebrew-core/blob/master/Formula/s/sugarjar.rb).
