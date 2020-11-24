# SugarJar Changelog

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
