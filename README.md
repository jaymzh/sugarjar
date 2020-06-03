# SugjarJar

Welcome to SugarJar - a git/github helper. It leverages the amazing GitHub cli,
[hub](https://hub.github.com/), so you'll need that installed.

SugarJar is inspired by [arcanist](https://github.com/phacility/arcanist), and
it's replacement at Facebook, JellyFish. Many of the features they provide for
the Phabricator workflow this aims to bring to the GitHub workflow.

In particular there are a lot of helpers for using a squash-merge workflow that
is poorly handled by the standard toolsets.

## Commands

### amend

Amend the current commit. Alias for `git commit --amend`.  Accepts other
arguments such as `-a` or files.

### amendq, qamend

Same as `amend` but without changing the message. Alias for `git commit --amend
--no-edit`.

### bclean

If safe, delete the current branch. Unlike `git branch -d`, bclean can handle
squash-merged branches. Think of it as a smarter `git branch -d`.

### bcleanall

Walk all branches, and try to delete them if it's safe. See `bclean` for
details.

### binfo

Verbose information about the current branch.

### br

Verbose branch list. An alias for `git branch -v`.

### feature

Create a "feature branch." It's morally equivalent to `git checkout -b` except
it defaults to creating it based on some form of 'master' instead of your
current branch. In order of preference it will be `upstream/master`,
`origin/master`, or `master`, depending upon what remotes are available.

### forcepush, fpush

The same as `smartpush`, but uses `--force-with-lease`. This is a "safer" way
of doing force-pushes and is the recommended way to push after rebasing or
amending. Never do this to shared branches. Very convenient for keeping the
branch behind a pull-request clean.

### lint

Run any linters configured in `.sugarjar.yaml`.

### smartclone, sclone

A smart wrapper to `git clone` that handles forking and managing remotes for
you.  It will clone a git repository using hub-style short name (`$org/$repo`).
If the org of the repository is not the same as your github-user then it will
fork the repo for you to your account (if not already done) and then setup your
remotes so that `origin` is your fork and `upstream` is the upstream.

### smartpush, spush

A smart wrapper to `git push` that runs whatever is defined in `on_push` in
`.sugarjar.yml`, and only pushes if they succeed.

It will also allow you to not specify a remote or branch, and will default to
`origin` and whatever your current local branch name is.

### unit

Run any unitests configured in `.sugarjar.yaml`.

# up

Rebase the current branch on the branch it's tracking, or if it's tracking one
then, otherise `upstream/master` if it exists, or `origin/master`.

# upall

Same as `up`, but for all branches.

## User Configuration

Sugarjar will read in both a system-level config file
(`/etc/sugarjar/config.yaml`) and a user-level config file
`~/.config/sugarjar/config.yaml`, if they exist. Anything in the user config
will override the system config, and command-line options override both. The
yaml file is a straight key-value pair of options without their '--'. For
example:

```yaml
debug: true
github-user: jaymzh
```

In addition, the environment variable `SUGARJAR_DEBUG` can be defined to set
debug on. This is primarily used as a way to turn debug on earlier in order to
troubleshoot configuration parsing.

## Repository Configuration

Sugarjar looks for a `.sugarjar.yaml` in the root of the repository to tell it
how to handle repo-specific things. Currently there are only three
configurations accepted:

* lint - A list of scripts to run on `sj lint`. These should be linters like
  rubocop or pyflake.
* unit - A list of scripts to run on `sj unit`. These should be unittest
  runners like rspec or pyunit.
* on_push - A list of types (`lint`, `unit`) of checks to run before pushing.
  It is highly recommended this is only `lint`. The goal here is to allow for
  the user to get quick stylistic feedback before pushing their branch to avoid
  the push-fix-push-fix loop.

Example configuration:

```yaml
lint:
  - scripts/lint
unit:
  - scripts/unit
on_push:
  - lint
```

## FAQ

Why the name SugarJar?

It's mostly a backranym. Like jellyfish, I wanted two letters that were on
home row on different sides of the keyboard to make it easy to type. I looked
at the possible options that where there and not taken and tried to find one
I could make an appropriate name out of. Since this utility adds lots of sugar
to git and github, it seemed appropriate.

Why did you use `hub` instead of the newer `gh` CLI?

`gh` is less feature-rich (currently). I'm also considering making this optionally
act as a wrapper to `hub` the way `hub` can be a wrapper to `git`.
