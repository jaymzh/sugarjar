# Homebrew Packaging Notes

## Prep PR

* Edit
  `/usr/local/Homebrew/Library/Taps/homebrew/homebrew-core/Formula/s/sugarjar.rb`
  modifying the version and the sha. See [previous
  example](https://github.com/Homebrew/homebrew-core/pull/162477)
* Commit, make the title "sugarjar $VERSION"

## Test

Do a install from source:

```shell
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --build-from-source sugarjar
```

Then test:

```shell
brew test sugarjar
brew audit --strict sugarjar
```

## Make PR

The real upstream has to be called `origin` in Homebrew, so push to our
forked remote:

```shell
git push jaymzh <branchname>
```

And make the PR from the webUI.
