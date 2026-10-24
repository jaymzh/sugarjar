---
name: sugarjar
description: "Use when working with git repositories via SugarJar (sj). Covers
sj sclone, feature/subfeature branches, smartpush, amend, fpush, pull requests,
bclean, and rebasing. Use for any git workflow where SugarJar is available or
recommended. Load this skill then the user mentions commit, push, open a PR, or
clean up branches."
---

# SugarJar Workflow Skill

This skill guides AI agents when using
[SugarJar](https://github.com/jaymzh/sugarjar) (`sj`) — a git +
GitHub/GitLab/Forgejo helper — for day-to-day development.

## Intro information

In any repo, it's worth checking for a `.sugarjar.yaml` file and seeing if
SugarJar has been setup with specifics for this repo.

It's also worth checking `~/.config/sugarjar/config.yaml` to see if the user
has SugarJar setup for themselves.

Those two files will always give you bearings.

Note that in a SugarJar workflow, the "tracked" branch for git is always the
branch we plan to merge TO (usually 'upstream/main' or similar). In most cases
SugarJar will dynamically determine the "most upstream" remote and the "most
main" branch, and things like `sj up` will rebase on that. To make things
cleaner, the tracked branch in git is set to this, and if it's detected to not
be, SugarJar will prompt the user suggesting they change it.

The branch one is pushing to, which other workflows sometimes use as the
"tracked branch" SugarJar determines dynamically for `spush`, `fpush`, `sync`,
and `fsync` - but is not itself set in git as a branch property.

## Setting up Sugarjar for a new user

If the user has not configured SugarJar globally, suggest setting up
`~/.config/sugarjar/config.yaml`. Configure a host_configs section for whatever
forges they routinely use, and set a default. For example:

```yaml
default_forge_host: github.com
host_configs:
  default:
    use_forks: true
  github.com:
    user: someuser
  gitlab.com:
    user: someuser
  gitlab.gnome.com:
    user: slightlydifferentuser
```

When being used in a branch-based system instead of a fork-based system,
suggest adding `feature_prefix` to the username followed by a slash (or
whatever is common practice) on the relevant host and setting `use_forks` to
`false` for that host. For example:

```yaml
default_forge_host: gitlab.mycompany.com
host_configs:
  default:
    use_forks: true
  gitlab.mycompany.com:
    user: mylastname.myfirstname
    feature_prefix: mylastname.myfirstname/
    use_forks: false
  github.com:
    user: someuser
  gitlab.com:
    user: someuser
  gitlab.gnome.com:
    user: slightlydifferentuser
```

## Cloning a new repository

When asked to clone a new repository, change directories into wherever the user
keeps their git clones and do `sj sclone <repo>`.

Short-names can be used with `sclone`, if `default_forge_host` has been set,
e.g. `sj sclone company/group/repo`.

## Development

### Creating feature branches

Always create feature branches with `sj feature` (or `sj f`). This ensures the
branch is based on "most main" (typically `upstream/main` or `origin/main`) and
that the remote is fetched first.

```bash
# Create a feature branch off main
sj feature my-feature-name

# Create a feature branch based on another branch
sj feature my-feature-name base-branch-name
```

**NOTE**: The branch name will be prefixed with the `feature_prefix` in the
configuration, so if the `feature_prefix` is `myuser/`, then `sj feature
my-feature-name` will create a branch called `myuser/my-feature-name`. However,
the tab-completion for sugarjar will enable ignoring the prefix in the
tab-completion, so `sj checkout my<tab>` will complete `myuser/my-feature-name`
properly.

### Creating stacked branches (subfeatures)

For dependent changes (stacked PRs), use `sj subfeature` (or `sj sf`). This
creates a branch based on the **current branch** instead of main.

```bash
# Create a subfeature branch off the current branch
sj subfeature dependent-feature-name
```

SugarJar will automatically detect this parent/child relationship and:

- Set the PR base to the parent branch when creating PRs
- Rebase correctly with `sj up`

### Checking out existing branches

Use `sj co` (checkout) which is SugarJar-aware and respects `feature_prefix` if
configured.

```bash
sj co branch-name
```

### Running linters and unit tests

Whenever writing code for a user, if the repo has linters and/or unit tests
configured for sugarjar, they are the best way to check your work.

By default, SugarJar doesn't want to run "checkers" (linters or unittests) on
dirty repos. However, an AI agent routinely checks its work before it's ready
to commit or pass control back to the user, and there are special options in
SugarJar to enable this.

AI Agents should always run linters with `sj lint --ignore-dirty
--autocorrect-action ignore`. This will run the linters on dirty repos, and not
prompt about linters that changed the repo. Most linters don't error out if
they were able to fix the repo, so the exit code is not much help - but
SugarJar will note when the linter modified the repo. When the repo is
modified, look at the diff, and decide whether to keep the fixes.

Unit tests are easier as they don't autocorrect, so you can simply run `sj unit
--ignore-dirty`.

## Making Changes

Agents should not amend or push or create pull requests for the user unless
asked.

### Amending commits

In places where amend-based workflows are used, `sj amend` is incredibly
helpful.

Use `sj amend` as a safer alias for `git commit --amend`:

```bash
# Amend the most recent commit (interactive)
sj amend

# Amend without prompting for commit message update
sj qamend
```

After amending or rebasing, **do not use `git push --force`**. Use `sj fpush`
instead.

## Pushing Changes

### Smart push

`sj smartpush` (or `sj spush`) is the default way to push. It:

- Runs configured pre-push checks (lint/unit tests) if configured
- Uses smart defaults (pushes current branch to matching branch name on
  `origin`)

```bash
sj spush
```

### Force push with lease

After rebasing or amending, always use `sj fpush` instead of `git push
--force`:

```bash
sj fpush
```

This adds `--force-with-lease` which verifies you are up-to-date with the
remote before forcing, preventing accidental overwrites of others' work.

## Pull Requests

### Creating PRs

Use `sj spr` (smart pull request) to create PRs. This will:

- Autofill PR title/description from commit messages
- For subfeatures, automatically suggest basing the PR on the parent branch
- Use the correct forge host

```bash
sj spr
```

If this is a subfeature, SugarJar will prompt:

```text
It looks like this is a subfeature, would you like to base this PR on parent-branch? [y/n]
```

The user can configure `pr_autostack: true` in their config to auto-answer
"yes" to this prompt.

### Pulling in web UI suggestions

If someone adds suggestions via the forge web UI and the user commits them,
the local and remote branches diverge. Use:

```bash
sj pullsuggestions
```

This will attempt to fast-forward merge remote suggestions into the local
branch after showing a diff and asking for confirmation.

## Syncing and Rebasing

### Updating a branch

Use `sj up` to intelligently rebase:

```bash
sj up
```

`sj up` will:

- Rebase the current branch onto its tracking branch
- For subfeatures, rebase onto the parent branch
- If a parent branch was deleted (e.g., after `bclean`), rebase onto "most
  main" instead

### Syncing across workstations

If the user works on multiple machines and has pushed changes from another
workstation:

```bash
sj sync
```

This pulls changes from the push target branch and rebases local changes on
top. In the event of conflict, you can use `sj fsync` to forcefully sync to the
remote branch.

## Cleanup

### Cleaning merged branches

After a PR is merged (including squash-merged), clean up the local branch:

```bash
# Clean the current branch
sj bclean

# Clean a specific branch
sj bclean branch-name

# Clean all merged branches
sj bcleanall
```

`sj bclean` safely detects squash-merged branches and deletes them, unlike `git
branch -d` which fails on squash-merged branches.

### Remote cleanup

To clean up remote branches that have been merged:

```bash
sj rbclean    # Clean current branch's remote
sj rbcleanall # Clean all merged remote branches
```

**Note:** Remote branch cleanup is experimental and cannot differentiate
between merged feature branches and merged release branches.

### Global cleanup

To clean both local and remote merged branches:

```bash
sj gbclean    # Clean current branch everywhere
sj gbcleanall # Clean all merged branches everywhere
```

## Inspecting State

### Branch info

```bash
sj binfo      # Show current branch and ancestors up to main
sj smartlog   # Or sj sl - show tree of all branches
```

## Pre-push Checks

If a repository has `.sugarjar.yaml` configured with linters or unit tests, `sj
spush` and `sj fpush` will run them automatically. If they fail, the push is
aborted.

To run checks manually:

```bash
sj lint       # Run all configured linters
sj unit       # Run all configured unit tests
```

## Error Handling

### "Branch is not fully merged"

If `git branch -d` fails because a branch was squash-merged, use `sj bclean`
instead.

### "Failed to push some refs"

If a regular push fails after amending/rebasing:

- **Do not** suggest `git push --force`
- Use `sj fpush` instead

### "There is no tracking information"

If `sj up` or `sj sync` complains about missing tracking information, it'll
likely give you the command to fix it, but usually it's `git branch -u
origin/main` (or `origin/master` when a repo's upstream uses `master`).

### Forge host errors

If `sj sclone` or `sj spr` fails with authentication or host errors:

1. Verify the user has configured the right `default_forge_host`
1. Check that `gh` or `glab` CLI is authenticated for the relevant host
1. Suggest running `glab auth login --hostname <hostname>`

### Subfeature PR base is wrong

If a subfeature PR was created with the wrong base branch:

1. Check that the branch was created with `sj subfeature`, not `sj feature`
1. The PR base can be manually changed in the GitLab UI
1. Ensure `pr_autostack` is configured if the user wants automatic behavior

## Workflow Summary

A typical SugarJar workflow:

```bash
# Clone a repo
sj sclone mycompany/mygroup/myrepo

# Create a feature branch
sj feature my-change

# Make changes, commit
git add .
git commit -s -m "feat: my awesome change"

# Push and create PR
sj spush
sj spr

# After PR is merged, clean up
sj bclean

# Or if you need to amend after review
sj amend
sj fpush
```

For stacked changes:

```bash
sj feature bottom-change
# ... commit ...
sj subfeature top-change
# ... commit ...
sj spush
sj spr  # Will prompt to base on bottom-change

# Later, after bottom-change merges
sj up   # Rebases top-change onto main
sj bclean bottom-change
```
