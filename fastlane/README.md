fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios prepare

```sh
[bundle exec] fastlane ios prepare
```

Prepare iOS signing with automatic signing

### ios build

```sh
[bundle exec] fastlane ios build
```

Build iOS IPA (development export by default)

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Upload iOS artifact to Diawi

### ios distribute

```sh
[bundle exec] fastlane ios distribute
```

Prepare + build + upload iOS IPA to Diawi (path: bypasses fresh build output)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
