# Fedora Packaging Notes

This is mostly notes to myself.

## Refs

Some links and refs useful to keep handy

* [Sugar Jar dist-git](https://src.fedoraproject.org/rpms/rubygem-sugarjar)
* [Package Maintenance Guide](https://docs.fedoraproject.org/en-US/package-maintainers/Package_Maintenance_Guide/)
* [Machines you can use](https://fedoraproject.org/wiki/Test_Machine_Resources_For_Package_Maintainers)

## Prep

Start the vagrant machine, ssh to it (`vagrant up; vagrant ssh`)

If not already checked out, check out the dist-git:

```shell
fedpkg co rubygem-sugarjar
```

Make sure you start on the 'rawhide' branch.

If already checked out, do `fedpkg pull` to get the latest.

## Do work

Make whatever changes you want on rawhide.

If you're doing a version bump you'll need to grab both new sources and replace
the old ones. First follow the directions in the spec file to build the tarball
for the test files. Then wget the gem from the URL in the spec file. Then:

```shell
fedpkg new-sources rubygem-sugarjar-<version>-specs.tar sugarjar-<version>.gem
```

## Testing

You can do a local build (`fedpkg local`) or a mock build (`fedpkg mockbuild`).

You can, alternatively, submit a koji build:

```shell
# build a SRPM
fedpkg srpm
# make sure your krb-auth'd
krb
# Submit the koji build
koji build --scratch rawhide <srpm>
```

## Committing and pushing

First, commit your change:

```shell
fedpkg commit
```

You can push directly to master if you want (`fedpkg push`), or alternatively,
make a PR by adding your remote:

```shell
git remote add fork ssh://jaymzh@pkgs.fedoraproject.org/forks/jaymzh/rpms/rubygem-sugarjar.git
```

And push to that instead (`git push fork`), and click the link to make a PR.

Once it's pushed/merged, you can create a build:

```shell
fedpkg build
```

For Rawhide, if the build succeeds, you're done.

To build for other distros, switch branches with:

```shell
fedpkg switch-branch <f35,f36,etc.>
```

And you can just merge in rawhide (`git merge rawhide`), then build.

For non-rawhide branches, after the `build`, submit the update:

```shell
fedpkg update
```

That will push it to testing. Autokarma should push it to stable after about
a week (though you can manually push it with
`bodhi updates request <update_id> stable`).
