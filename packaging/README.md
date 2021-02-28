This is mostly notes to myself.

Use fedpkg to get a srpm:

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
