# SugarJar Changelog

## 2.0.1 (2025-05-12)

* Fix gemspec to include new library files

## 2.0.0 (2025-05-11)

* Fix smartlog when on detached head
* Drop support for `hub`, and thus also `fallthru` mode
* Fix GHE handling when using `gh`
* Support `github_host` and `github_user` in repoconfig
* Replace `version` subcommand with `debuginfo` subcommand (`--version` still
  exists)
* `smartclone`: set upstream for main branch to upstream remote when applicable
* Warn when deprecated options found in config file
* Fix handling of `--color` in some cornercases
* `subfeature` PRs: Fix bug where we would incorrectly deterine base branch
* Checks: Fix bug where we would lint even if repo was dirty causing confusing
  output
* `feature` prefixes: Fix bug where we didn't look for the prefix on the base
  branch when specified
* Better handle creating PRs to branches other than "main"
* Significantly improve unittest coverage
* Bump required Ruby to 3.2

## 1.1.3 (2025-02-20)

* smartpullrequest: When working with `gh`, bypass its attempt to push,
  bypassing unnecessary prompts and branch track mangling
* smartpullrequest: Better support for autofill
* smartpullrequest: Don't attempt to stack when in forked repo

## 1.1.2 (2024-04-25)

* Add support for 'subfeatures'
* Add support for building stacked PRs based on 'subfeatures'
* smartpullrequest: only autofill in the PR when a single commit exists between
  the base and us
* smartpullrequest: Add `--fill` option to let people opt-out of autofilling the
  PR
* smartpullrequest: State that we're autofilling the PR when we do
* feature: Fix some corner cases where feature-prefixing didn't work
* pullsuggestions: Print the diff in the correct order
* feature/subfeature: set tracked branch for the user
* subfeature: automatically update tracked branch when previous tracked branch
  disappears

## 1.1.1 (2024-02-12)

* Relax ruby requirements to allow for easier packaging
* Handle aborted rebases better
* Add bash-completion script
* Various doc updates

## 1.1.0 (2023-12-31)

* Fix include path for unittests for downstream packagers
* Bump ruby min versions
* Include Gemfile.lock for downstream packagers

## 1.0.1 (2023-12-20)

* `co` support for featureprefix
* Add `include_from` and `overwrite_from` support to repoconfig
* Support relative paths for lints/units
* `smartpr` now uses `--fill`

## 1.0.0 (2023-10-22)

* Add new "feature prefix" feature
* Implement `auto` setting for `github_cli`, default to `gh`
* Point people to Sapling
* Handle `sclone` of repos in personal orgs
* Better error when a subcommand isn't specified
* Various documentation fixes

## 0.0.11 (2022-10-06)

* Properly handle slashes in branch names (closes #101)
* Support for running a command to determine checks (linters, units) to run
* Support for using `gh` CLI instead of `hub` (experimental)
* Add new `pullsuggestions` command to pull in (accepted) suggestions from a
  GitHub code review.
* Detect mismatched primary branch names to assist with projects changing from
  `master` to `main`

## 0.0.10 (2021-12-06)

* Support 'main' as a default/primary branch
* Fix doc errors
* Handle rebase failures more gracefully, give users hints (closes #88)
* Handle SAML errors better (closes #95)
* Don't parse option args as subcommands (closes #89)

## 0.0.9 (2021-02-20)

* Fix smartclone not honoring `--github-host`
* Use SSH protocol by default on short repo names
* Handle anonymous auth failures gracefully
* Better support for autocorrecting linters

## 0.0.8 (2020-12-16)

* Colorize and simplify output
* New smartlog feature
* Doc fixes

## 0.0.7 (2020-11-23)

* Add new command `smartpullrequest` (or `smartpr` or `spr`) for creating
  pull requests (closes #51)
* Add checks for dirty repos before `smartpush`, `forcepush`, and
  `smartpullrequest`
* Add `--ignore-dirty` and `--ignore-prerun-failure` options
* Handle when git prompts for a username (closes #52)
* Always use SSH for the forked remote (closes #56)
* Better handling of various forms of repo URLs
* Fix typo of `version` in help message
* Fix typos in `README.md`

## 0.0.6 (2020-07-05)

* Add automatic commit template configuration (closes #38)
* bcleanall: Return to reasonable branch (fixes #37)
* Handle case where `hub` has no auth token (fixes #39)
* Fix crash in `smartclone`
* Improve logging
* Fix `sj unit` running lints instead of units

## 0.0.5 (2020-06-24)

* Fix global config file handling
* Better logging around lint/unit failuers
* Handle incorrect tracked branches better

## 0.0.4 (2020-06-17)

* Fix gemspec to include executables
* Add support for building omnibus releases

## 0.0.3 (2020-06-08)

* Stop rescuing NoMethodError (fixing a variety of confusing error cases)
* Fix crash when no `on_push` entry is in repo config
* Document contribution process (`CONTRIBUTING.md`)
* Document code of conduct (`CODE_OF_CONDUCT.md`)

## 0.0.2 (2020-06-06)

* Fix 'co' not accepting multiple arguments/options
* Fix README typos (#10, #11)
* Don't assume the ruby to run under
* Don't crash when no subcommands are passed in
* Don't assume paths (e.g. for hub, git)
* Fix crash for unknown method
* fix handling of empty config files

## 0.0.1 (2020-06-05)

* Initial release
