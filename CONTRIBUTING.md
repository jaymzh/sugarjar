# Contributing to SugarJar

We welcome contributions! Contributions come in a variety of forms: clear bug
reports, code, or spreading the word about this project.

If you'd like to contribute code, here's how.

Simply use SugarJar to make a fork and setup your repo:

```shell
sj sclone jaymzh/sugarjar
```

Make a branch for your change:

```shell
sj feature mychange
```

Make whatever changes you want, commit with a clear commit message, and a DCO.

We require [Developer Certificate of Origin
(DCO)](https://developercertificate.org/) via a 'signed-off-by:` line in your
commit (the `git commit -s` does this for you). The Chef community has a lot of
great documentation on this which you can find
[here](https://docs.chef.io/community_contributions/#developer-certification-of-origin-dco).

```shell
git commit -as
```

Make a pull request:

```shell
sj spush
sj pull-request
```
