# Rolling a release

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

## Publish omnibus builds

* From omnibus directory, prep: `bundle install --binstubs`

Then from inside each VM:

  ```shell
  # ubuntu-2204 not done because there were vagrant+ssl+netssh issues that
  # don't allow the box to come up, but 2004 packages are identical
  #
  # centos-7 requires building with older ruby (see config/projects/sugarjar.rb)
  # so we did it for 0.0.11 but probably will drop it going forward
  #
  # centos-stream-9 doesn't yet have a bento box (see
  # https://github.com/chef/bento/issues/1391)
  #
  # Fedora has official packages now, so we don't build for that.
  distros="ubuntu-1804 ubuntu-2004 debian-11 centos-stream-8"
  for d in $distros; do
    bundle exec kitchen converge default-$d && \
      bundle exec kitchen login default-$d && \
      bundle exec kitchen destroy default-$d
  done
  ```

1. Do a build...
    (for fedora you'll need to `sudo dnf install rpm-build`)

    ```shell
    .  load-omnibus-toolchain.sh
    [ -e .bundle ] && sudo chown -R vagrant:vagrant .bundle
    cd sugarjar/omnibus
    bundle install
    bin/omnibus build sugarjar && \
      bin/omnibus clean sugarjar # required so next build works
    ```

1. Grab/rename the package out of sugarjar/omnibus/pkg

* Build on a mac

  ```shell
  cd sugarjar/omnibus
  bundle install --binstubs
  # make /opt/sugarjar and chown it to your user
  bin/omnibus build sugarjar && bin/omnibus clean sugarjar
  ```

## Publish Fedora builds

See `packaging/README.md`.
