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

Jump to what you're most interested in:

* [Common Use-cases](#common-use-cases)
   * [Auto Cleanup Squash-merged branches](#auto-cleanup-squash-merged-branches)
   * [Smarter clones and remotes](#smarter-clones-and-remotes)
   * [Work with stacked branches more easily](#work-with-stacked-branches-more-easily)
   * [Creating Stacked PRs with subfeatures](#creating-stacked-prs-with-subfeatures)
   * [Have a better lint/unittest experience!](#have-a-better-lintunittest-experience)
   * [Better push defaults](#better-push-defaults)
   * [Cleaning up your own history](#cleaning-up-your-own-history)
   * [Better feature branches](#better-feature-branches)
   * [Smartlog](#smartlog)
   * [Sync work across workstations](#sync-work-across-workstations)
   * [Pulling in suggestions from the web](#pulling-in-suggestions-from-the-web)
   * [And more!](#and-more)
* [Installation](#installation)
* [Configuration](#configuration)
* [Repository Configuration](#repository-configuration)
   * [Commit Templates](#commit-templates)
* [Enterprise GitHub](#enterprise-github)
* [FAQ](#faq)

## Common Use-cases

### Auto cleanup squash-merged branches

It is common for a PR to go back and forth with a variety of nits, lint fixes,
typos, etc. that can muddy history. So many projects will "squash and merge"
when they accept a pull request. However, that means `git branch -d <branch>`
doesn't work. Git will tell you the branch isn't fully merged. You can, of
course `git branch -D <branch>`, but that does no safety checks at all, it
forces the deletion.

Enter `sj lbclean` - it determines if the contents of your branch has been merge
and safely deletes if so. (Note: `lbclean` stands for "local branch clean", and
is aliased to `bclean` for both backwards-compatibility and also since it's the
most common branch-cleanup command).

![bclean screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/bclean.png)

Will delete a branch, if it has been merged, **even if it was squash-merged**.

You can pass it a branch if you'd like (it defaults to the branch you're on):
`sj bclean <branch>`.

But it gets better! You can use `sj bcleanall` to remove all branches that have
been merged:

![bcleanall screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/bcleanall.png)

There is also `sj rbclean` ("remote branch clean") (and `sj rbcleanall`) for
cleanup of remote branches. *Note*: This cannot differentiate between
PR/feature branches which have been merged and long-lived release branches that
have been merged (e.g.  if '2.0-release' is a branch and has no commits not in
main, it will be deleted).

There is even `sj gbclean` ("global branch clean") (and `sj gbcleanall`) which will
do both the local and remote cleaning.

*NOTE*: Remote branch cleaning is still experimental, use with caution!

### Smarter clones and remotes

There's a pattern to every new repo we want to contribute to. First we fork,
then we clone the fork, then we add a remote of the upstream repo. It's
monotonous. SugarJar does this for you:

![smartclone screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/sclone.png)

`sj` accepts both `smartclone` and `sclone` for this command.

This will:

* Fork the repo to your personal org (if you don't already have a fork)
* Clone your fork
* Add the original as an 'upstream' remote

Note that it takes short names for repos. No need to specify a full URL,
just a $org/$repo.

Like `git clone`, `sj smartclone` will accept an additional argument as the
destination directory to clone to. It will also pass any other unknown options
to `git clone` under the hood.

### Work with stacked branches more easily

It's important to break changes into reviewable chunks, but working with
stacked branches can be confusing. SugarJar provides several tools to make this
easier.

First, and foremost, is `feature` and `subfeature`. Regardless of stacking, the
way to create a new feature bracnh with sugarjar is with `sj feature` (or `sj
f` for short):

![feature screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/feature.png)

A "feature" in SugarJar parlance just means that the branch is always created
from "most main" - this is usually `upstream/main`, but SJ will figure out
which remote is the "upstream", even if it's `origin`, and then will determine
the primary branch (`main` or for older repos `master`). It's also smart enough
to fetch that remote first to make sure you're working on the latest HEAD.

When you want to create a stacked PR, you can create `subfeature`, which, at
its core is just a branch created from the current branch:

![subfeature screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/subfeature.png)

If you create branches like this then sugarjar can now make several things
much easier:

* `sj up` will rebase intelligently
* After an `sj bclean` of a branch earlier in the tree, `sj up` will update
  the tracked branch to "most main"

There are two commands that will show you the state of your stacked branches:

* `sj binfo` - shows the current branch and its ancestors up to your primary branch
* `sj smartlog` (aka `sj sl`) - shows you the whole tree.

To continue with the example above, my `smartlog` might look like:

![subfeature-smartlog screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/subfeature-smartlog.png)

As you can see, `mynewthing` is derived from `main`, and `dependentnewthing` is
derived from `mynewthing`.

Now lets make a different feature stack:

![subfeature-part2 screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/subfeature-part2.png)

The `smartlog` will now show us this tree, and it's a bit more interesting:

![subfeature-part2-smartlog screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/subfeature-part2-smartlog.png)

Here we can see from `main`, we have two branches: one going to `mynewthing`
and one going to `anotherfeature`. Each of those has their own dependent branch
on top.

Now, what happens if I make a change to `mynewthing` (the bottom of the first stack)?

![subfeature-part3 screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/subfeature-part3.png)

We can see here now that `dependentnewthing`, is based off a commit that _used_
to be `mynewthing` (`5086ee`), but `mynewthing` has moved. Both `mynewthing`
and `dependentnewthing` are derived from `5086ee` (the old `mynewthing`), but
`dependentnewthing` isn't (yet) based on the current `mynewthing`. But SugarJar
will handle this all correctly when we ask it to update the branch:

![subfeature-part3-rebase screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/subfeature-part3-rebase.png)

Here we see that SugarJar knew that `dependentnewthing` should be rebased onto
`mynewthing`, and it did the right thing - from main there's still the
`50806ee` _and_ the new additional change which are now both part of the
`mynewthing` branch, and `dependentnewthing` is based on that branch, this
including all 3 commits in the right order.

Now, lets say that `mynewthing` gets merged and we use `bclean` to clean it all
up, what happens then?

![subfeature-detect-missing-base screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/subfeature-detect-missing-base.png)

SugarJar detects that branch is gone and thus this branch should now be based
on the upstream main branch!

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

### Have a better lint/unittest experience!

Ever made a PR, only to find out later that it failed tests because of some
small lint issue? Not anymore! SJ can be configured to run things before
pushing. For example,in the SugarJar repo, we have it run Rubocop (ruby lint)
and Markdownlint `on_push`. If those fail, it lets you know and doesn't push.

You can configure SugarJar to tell it how to run both lints and unittests for
a given repo and if one or both should be run prior to pushing.

The details on the config file format is below, but we provide three commands:

```shell
sj lint
```

Run all linters.

```shell
sj unit
```

Run all unittests.

```shell
sj smartpush # or spush
```

Run configured push-time actions (nothing, lint, unit, both), and do not
push if any of them fail.

### Better push defaults

In addition to running pre-push tests for you `smartpush` also picks smart
defaults for push. So if you `sj spush` with no arguments, it uses the
`origin` remote and the same branch name you're on as the remote branch.

### Cleaning up your own history

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

### Better feature branches

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

### Smartlog

Smartlog will show you a tree diagram of your branches! Simply run `sj
smartlog` or `sj sl` for short.

![smartlog screenshot](https://github.com/jaymzh/sugarjar/blob/main/images/smartlog.png)

### Sync work across workstations

If you work on multiple workstations, keeping your branches in-sync can be a
pain. SugarJar provides `sync` to help with this.

For example, if you do some work on feature `foo` on machine1 and push to
`origin/foo` (intending to eventually merge to `upstream/main`), then on
machine2, you pull that branch, do more work, which you also push to
`origin/foo`, then on machine1, you can do `sj sync` to pull down the changes
from `origin/foo`. If you have local changes, that are not already on
`origin/foo`, those will be rebased on top of the changes from `origin/foo`.

It's very similar to `sj up`, but instead of rebasing on top of the tracking
branch, it rebases on top of the push target branch.

### Pulling in suggestions from the web

When someone 'suggests' a change in the GitHub WebUI, once you choose to commit
them, your origin and local branches are no longer in-sync. The
`pullsuggestions` command will attempt to merge in any remote commits to your
local branch. This command will show a diff and ask for confirmation before
attempting the merge and  - if allowed to continue - will use a fast-forward
merge.

### And more!

See `sj help` for more commands!

## Installation

Sugarjar is packaged in a variety of Linux distributions - see if it's on the
list here, and if so, use your package manager (or `gem`) to install it:

[![Packaging status](https://repology.org/badge/vertical-allrepos/sugarjar.svg?exclude_unsupported=1)](https://repology.org/project/sugarjar/versions)

If you are using a Linux distribution version that is end-of-life'd, click the
above image, it'll take you to a page that lists unsupported distro versions
as well (they'll have older SugarJar, but they'll probably still have some
version).

**Ubuntu users**: You can use [this
PPA](https://launchpad.net/~michel-slm/+archive/ubuntu/sugarjar) to get newer
versions for all supported Ubuntu releases (as well as some older versions).
Ubuntu package maintainer.

**MacOS users**: We recommend using Homebrew - we keep SugarJar updated in
Homebrew Core.

Finally, if none of those work for you, you can clone this repo and run it
directly from there.

## Configuration

Sugarjar will read in both a system-level config file
(`/etc/sugarjar/config.yaml`) and a user-level config file
(`~/.config/sugarjar/config.yaml`), if they exist. Anything in the user config
will override the system config, and command-line options override both. The
yaml file is a straight key-value pair of options without their '--'.

See [examples/sample_config.yaml](examples/sample_config.yaml) for an example
configuration file.

In addition, the environment variable `SUGARJAR_LOGLEVEL` can be defined to set
a log level. This is primarily used as a way to turn debug on earlier in order to
troubleshoot configuration parsing.

Deprecated fields will cause a warning, but you can suppress that warning by
defining `ignore_deprecated_options`, for example:

```yaml
old_option: foo
ignore_deprecated_options:
  - old_options
```

## Repository Configuration

Sugarjar looks for a `.sugarjar.yaml` in the root of the repository to tell it
how to handle repo-specific things. See
[examples/sample_repoconfig.yaml](examples/sample_repoconfig.yaml) for an
example configuration that walks through all valid repo configurations in
detail.

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

If the package for your OS/distro didn't set it up automatically, you should
find that `sugarjar_completion.bash` is included in the package, and you can
simply source that in your dotfiles, assuming you are using bash.

**What happens now that Sapling is released?**

SugarJar isn't going anywhere anytime soon. This was meant to replace arc/jf,
which has now been open-sourced as [Sapling](https://sapling-scm.com/), so I
highly recommend taking a look at that!

Sapling is a great tool and solves a variety of problems SugarJar will never be
able to. However, it is a significant workflow change, that won't be
appropriate for all users or use-cases. Similarly there are workflows and tools
that Sapling breaks. So worry not, SugarJar will continue to be maintained and
developed.
