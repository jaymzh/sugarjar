This is mostly notes to myself.

Start the vagrant machine, ssh to it (`vagrant up; vagrant ssh`)

In the mounted repo, create the source file for the tests, see the comment in the spec file

Then in another dir (ala ~/builddir or whatever), copy the specfile and the test source file in, as well as wget the gem file from the URL in the spec file.

Use fedpkg to get a srpm (you may have to install various deps):

```shell
fedpkg --release rawhide local
```

Use koji to build:

```shell
krb
koji build --scratch rawhide <srpm>
```

Download and install the RPM

Request review [here](https://bugzilla.redhat.com/bugzilla/enter_bug.cgi?product=Fedora&format=fedora-review)

Or use fedora-create-review once you have access to the system

after requesting review you can check it yourself with:

```shell
fedora-review -b <bug>
```
