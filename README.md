# SugarJar

[![Lint](https://github.com/jaymzh/sugarjar/workflows/Lint/badge.svg)](https://github.com/jaymzh/sugarjar/actions?query=workflow%3ALint)
[![Unittest](https://github.com/jaymzh/sugarjar/workflows/Unittests/badge.svg)](https://github.com/jaymzh/sugarjar/actions?query=workflow%3AUnittests)
[![DCO](https://github.com/jaymzh/sugarjar/workflows/DCO%20Check/badge.svg)](https://github.com/jaymzh/sugarjar/actions?query=workflow%3A%22DCO+Check%22)

Welcome to SugarJar - a git/github helper. The only requirements are Ruby,
`git`, and [gh](https://cli.github.com/).

SugarJar is inspired by [arcanist](https://github.com/phacility/arcanist), and
its replacement at Facebook, JellyFish. Many of the features they provide for
the Phabricator workflow this aims to bring to the GitHub workflow.

In particular there are a lot of helpers for using a squash-merge workflow that
is poorly handled by the standard toolsets.

If you miss Mondrian or Phabricator - this is the tool for you!

If you don't, there's a ton of useful stuff for everyone!

## Installation

Sugarjar is packaged in a variety of Linux distributions - see if it's on the
list here, and if so, use your package manager (or `gem`) to install it:

[![Packaging status](https://repology.org/badge/vertical-allrepos/sugarjar.svg?exclude_unsupported=1)](https://repology.org/project/sugarjar/versions)

If you are using a Linux distribution version that is end-of-life'd, click the
above image, it'll take you to a page that lists unsupported distro versions
as well (they'll have older SugarJar, but they'll probably still have some
version).

Ubuntu users, Ubuntu versions prior to 24.x cannot be updated, so if you're on
an older Ubuntu please use [this
PPA](https://launchpad.net/~michel-slm/+archive/ubuntu/sugarjar) from our
Ubuntu package maintainer.

For MacOS users, we recommend using Homebrew - SugarJar is now in Homebrew Core.

Finally, if none of those work for you, you can clone this repo and run it
directly from there.

## Auto cleanup squash-merged branches

It is common for a PR to go back and forth with a variety of nits, lint fixes,
typos, etc. that can muddy history. So many projects will "squash and merge"
when they accept a pull request. However, that means `git branch -d <branch>`
doesn't work. Git will tell you the branch isn't fully merged. You can, of
course `git branch -D <branch>`, but that does no safety checks at all, it
forces the deletion.

Enter `sj bclean` - it determines if the contents of your branch has been merge
and safely deletes if so.

``` shell
sj bclean
```

Will delete a branch, if it has been merged, **even if it was squash-merged**.

You can pass it a branch if you'd like (it defaults to the branch you're on):
`sj bclean <branch>`.

But it gets better! You can use `sj bcleanall` to remove all branches that have
been merged:

```shell
$ git branch
* argparse
  master
  feature
  hubhost
$ git bcleanall
Skipping branch argparse - there are unmerged commits
Reaped branch feature
Reaped branch hubhost
```

## Smarter clones and remotes

There's a pattern to every new repo we want to contribute to. First we fork,
then we clone the fork, then we add a remote of the upstream repo. It's
monotonous. SugarJar does this for you:

```shell
sj smartclone jaymzh/sugarjar
```

(also `sj sclone`)

This will:

* Make a fork of the repo, if you don't already have one
* Clone your fork
* Add the original as an 'upstream' remote

Note that it takes short names for repos. No need to specify a full URL,
just a $org/$repo.

Like `git clone`, `sj sclone` will accept an additional argument as the
destination directory to clone to. It will also pass any other unknown options
to `git clone` under the hood.

## Work with stacked branches more easily

It's important to break changes into reviewable chunks, but working with
stacked branches can be confusing. SugarJar provides several tools to make this
easier.

First, and foremost, is `feature` and `subfeature`. Regardless of stacking, the
way to create a new feature bracnh with sugarjar is with `sj feature` (or `sj
f` for short):

```shell
$ sj feature mynewthing
Created feature branch mynewthing based on origin/main
```

A "feature" in SugarJar parliance just means that the branch is always created
from "most_main" - this is usually "upstream/main", but SJ will figure out
which remote is the "upstream", even if it's "origin", and then will determine
the primary branch ("main" or for older repos "master"). It's also smart enough
to fetch that remote first to make sure you're working on the latest HEAD.

When you want to create a stacked PR, you can create "subfeature", which, at
its core is just a branch created from the current branch:

```shell
$ sj subfeature dependentnewthing
Created feature branch dependentnewthing based on mynewthing
```

If you create branches like this then sugarjar can now make several things
much easier:

* `sj up` will rebase intelligently
* After an `sj bclean` of a branch earlier in the tree, `sj up` will update
  the tracked branch to "most_main"

There are two commands that will show you the state of your stacked branches:

* `sj binfo` - shows the current branch and its ancestors up to your primary branch
* `sj smartlist` (aka `sj sl`) - shows you the whole tree.

To continue with the example above, my `smartlist` might look like:

```text
$ sj sl
* 59c0522 (HEAD -> dependentnewthing) anothertest
* 6ebaa28 (mynewthing) test
o 7a0ffd0 (tag: v1.1.2, origin/main, origin/HEAD, main) Version bump (#160)
```

This is simple. Now lets make a different feature stack:

```text
$ sj feature anotherfeature
Created feature branch anotherfeature based on origin/main
# do stuff
$ sj subfeature dependent2
Created feature branch dependent2 based on anotherfeature
# do stuff
```

The `smartlist` will now show us this tree, and it's a bit more interesting:

```text
$ sj sl
* af6f143 (HEAD -> dependent2) morestuff
* 028c7f4 (anotherfeature) stuff
| * 59c0522 (dependentnewthing) anothertest
| * 6ebaa28 (mynewthing) test
|/
o 7a0ffd0 (tag: v1.1.2, origin/main, origin/HEAD, main) Version bump (#160)
```

Now, what happens if I make a change to `mynewthing`?

```text
$ sj co mynewthing
Switched to branch 'mynewthing'
Your branch is ahead of 'origin/main' by 1 commit.
  (use "git push" to publish your local commits)
$ echo 'randomchange' >> README.md
$ git commit -a -m change
[mynewthing d33e082] change
 1 file changed, 1 insertion(+)
$ sj sl
* d33e082 (HEAD -> mynewthing) change
| * af6f143 (dependent2) morestuff
| * 028c7f4 (anotherfeature) stuff
| | * 59c0522 (dependentnewthing) anothertest
| |/
|/|
* | 6ebaa28 test
|/
o 7a0ffd0 (tag: v1.1.2, origin/main, origin/HEAD, main) Version bump (#160)
```

We can see here now that `dependentnewthing`, is based off a commit that _used_
to be `mynewthing`, but `mynewthing` has moved. But SugarJar will handle this
all correctly when we ask it to update the branch:

```text
$ sj co dependentnewthing
Switched to branch 'dependentnewthing'
Your branch and 'mynewthing' have diverged,
and have 1 and 1 different commits each, respectively.
  (use "git pull" if you want to integrate the remote branch with yours)
$ sj up
dependentnewthing rebased on mynewthing
$ sj sl
* 93ed585 (HEAD -> dependentnewthing) anothertest
* d33e082 (mynewthing) change
* 6ebaa28 test
| * af6f143 (dependent2) morestuff
| * 028c7f4 (anotherfeature) stuff
|/
o 7a0ffd0 (tag: v1.1.2, origin/main, origin/HEAD, main) Version bump (#160)
```

Now, lets say that `mynewthing` gets merged and we use `bclean` to clean it all
up, what happens then?

```text
$ sj up
The brach we were tracking is gone, resetting tracking to origin/main
dependentnewthing rebased on origin/main
```

### Creating Stacked PRs with subfeatures

When dependent branches are created with `subfeature`, when you create a PR,
SugarJar will automatically set the 'base' of the PR to the parent branch. By
default it'll prompt you about this, but you can set `pr_autostack` to `true`
in your config to tell it to always do this (or `false` to never do this):

```text
$ sj spr
Autofilling in PR from commit message
It looks like this is a subfeature, would you like to base this PR on mynewthing? [y/n] y
...
```

## Have a better lint/unittest experience!

Ever made a PR, only to find out later that it failed tests because of some
small lint issue? Not anymore! SJ can be configured to run things before
pushing. For example,in the SugarJar repo, we have it run Rubocop (ruby lint)
and Markdownlint "on_push". If those fail, it lets you know and doesn't push.

You can configure SugarJar to tell it how to run both lints and unittests for
a given repo and if one or both should be run prior to pushing.

The details on the config file format is below, but we provide three commands:

```shell
git lint
```

Run all linters.

```shell
git unit
```

Run all unittests.

```shell
git smartpush # or spush
```

Run configured push-time actions (nothing, lint, unit, both), and do not
push if any of them fail.

## Better push defaults

In addition to running pre-push tests for you `smartpush` also picks smart
defaults for push. So if you `sj spush` with no arguments, it uses the
`origin` remote and the same branch name you're on as the remote branch.

## Cleaning up your own history

Perhaps you contribute to a project that prefers to use merge commits, so you
like to clean up your own history. This is often difficult to get right - a
combination of rebases, amends and force pushes. We provide two commands here
to help.

The first is pretty straight forward and is basically just an alias: `sj
amend`. It will amend whatever you want to the most recent commit (just an
alias for `git commit --amend`). It has a partner `qamend` (or `amendq` if you
prefer) that will do so without prompting to update your commit message.

So now you've rebased or amended, pushing becomes challenging. You can `git push
--force`, but everyone knows that's incredibly dangerous. Is there a better
way? There is! Git provides `git push --force-with-lease` - it checks to make
sure you're up-to-date with the remote before forcing the push. But man that
command is a mouthful! Enter `sj fpush`. It has all the smarts of `sj
smartpush` (runs configured pre-push actions), but adds `--force-with-lease` to
the command!

## Better feature branches

When you want to start a new feature, you want to start developing against
latest. That's why `sj feature` defaults to creating a branch against what we
call "most master". That is, `upstream/master` if it exists, otherwise
`origin/master` if that exists, otherwise `master`. You can pass in an
additional argument to base it off of something else.

```shell
$ git branch
  master
  test1
  test2
* test2.1
  test3
$ sj feature test-branch
Created feature branch test-branch based on origin/master
$ sj feature dependent-feature test-branch
Created feature branch dependent-feature based on test-branch
```

Additionally you can specify a `feature_prefix` in your config which will cause
`feature` to create branches prefixed with your `feature_prefix` and will also
cause `co` to checkout branches with that prefix. This is useful when organizations
use branch-based workflows and branches need to be prefixed with e.g. `$USER/`.

For example, if your prefix was `user/`, then `sj feature foo` would create
`user/foo`, and `sj co foo` would switch to `user/foo`.

## Smartlog

Smartlog will show you a tree diagram of your branches! Simply run `sj
smartlog` or `sj sl` for short.

![smartlog screenshot](https://github.com/jaymzh/sugarjar/blob/main/smartlog.png)

## Pulling in suggestions from the web

When someone 'suggests' a change in the GitHub WebUI, once you choose to commit
them, your origin and local branches are no longer in-sync. The
`pullsuggestions` command will attempt to merge in any remote commits to your
local branch. This command will show a diff and ask for confirmation before
attempting the merge and  - if allowed to continue - will use a fast-forward
merge.

## And more!

See `sj help` for more commands!

## Configuration

Sugarjar will read in both a system-level config file
(`/etc/sugarjar/config.yaml`) and a user-level config file
`~/.config/sugarjar/config.yaml`, if they exist. Anything in the user config
will override the system config, and command-line options override both. The
yaml file is a straight key-value pair of options without their '--'. For
example:

```yaml
log_level: debug
github_user: jaymzh
```

In addition, the environment variable `SUGARJAR_LOGLEVEL` can be defined to set
a log level. This is primarily used as a way to turn debug on earlier in order to
troubleshoot configuration parsing.

## Repository Configuration

Sugarjar looks for a `.sugarjar.yaml` in the root of the repository to tell it
how to handle repo-specific things. Currently there options are:

* `lint` - A list of scripts to run on `sj lint`. These should be linters like
  rubocop or pyflake. Linters will be run from the root of the repo.
* `lint_list_cmd` - A command to run which will print out linters to run, one
  per line. Takes precedence over `lint`. The command (and the resulting
  linters) will be run from the root of the repo.
* `unit` - A list of scripts to run on `sj unit`. These should be unittest
  runners like rspec or pyunit. Test will be run from the root of the repo.
* `unit_list_cmd` - A command to run which will print out the unit tests to
  run, one more line. Takes precedence over `unit`. The command (and the
  resulting unit tests) will be run from the root of the repo.
* `on_push` - A list of types (`lint`, `unit`) of checks to run before pushing.
  It is highly recommended this is only `lint`. The goal here is to allow for
  the user to get quick stylistic feedback before pushing their branch to avoid
  the push-fix-push-fix loop.
* `commit_template` - A path to a commit template to set in the `commit.template`
  git config for this repo. Should be either a fully-qualified path, or a path
  relative to the repo root.
* `include_from` - This will read an additional repoconfig file and merge it
  into the one being read. The value should be relative to the root of the
  repo. This will not error if the file does not exist, it is intended for
  organizations to allow users to optionally extend a default repo config.
* `overwrite_from` - Same as `include_from`, but completely overwrites the
  base configuration if the file is found.

Example configuration:

```yaml
lint:
  - scripts/lint
unit:
  - scripts/unit
on_push:
  - lint
commit_template: .commit-template.txt
```

### Commit Templates

While GitHub provides a way to specify a pull-request template by putting the
right file into a repo, there is no way to tell git to automatically pick up a
commit template by dropping a file in the repo. Users must do something like:
`git config commit.template <file>`. Making each developer do this is error
prone, so this setting will automatically set this up for each developer.

## Enterprise GitHub

Like `gh`, SugarJar supports GitHub Enterprise. In fact, we provide extra
features just for it.

You can set `github_host` in your global or user config, but since most
users will also have a few opensource repos, you can override it in the
Repository Config as well.

So, for example you might have:

```yaml
github_host: gh.sample.com
```

In your `~/.config/sugarjar/config.yaml`, but if the `.sugarjar.yaml` in your
repo has:

```yaml
github_host: github.com
```

Then we will configure `gh` to talk to github.com when in that repo.

## FAQ

**Why the name SugarJar?**

It's mostly a backronym. Like jellyfish, I wanted two letters that were on home
row on different sides of the keyboard to make it easy to type. I looked at the
possible options that where there and not taken and tried to find one I could
make an appropriate name out of. Since this utility adds lots of sugar to git
and github, it seemed appropriate.

**I'd like to package SugarJar for my favorite distro/OS, is that OK?**

Of course! But I'd appreciate you emailing me to give me a heads up. Doing so
will allow me to make sure it shows up in the Repology badge above.

**What platforms does it work on?**

Since it's Ruby, it should work across all platforms, however, it's developed
and primarily tested on Linux as well as regularly used on Mac. I've not tested
it on Windows, but I'll happily accept patches for Windows compatibility.

**How do I get tab-completion?**

If the package for your OS/distro didn't set it up manually, you should find
that `sugarjar_completion.bash` is included in the package, and you can simply
source that in your dotfiles, assuming you are using bash.

**What happens now that Sapling is released?**

SugarJar isn't going anywhere anytime soon. This was meant to replace arc/jf,
which has now been open-sourced as [Sapling](https://sapling-scm.com/), so I
highly recommend taking a look at that!

Sapling is a great tool and solves a variety of problems SugarJar will never be
able to. However, it is a significant workflow change, that won't be
appropriate for all users or use-cases. Similarly there are workflows and tools
that Sapling breaks. So worry not, SugarJar will continue to be maintained and
developed
