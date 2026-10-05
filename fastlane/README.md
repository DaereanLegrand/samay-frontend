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

### ios adhoc_local

```sh
[bundle exec] fastlane ios adhoc_local
```

Build a signed ad-hoc IPA for on-device installs (the reference app pattern: make build TARGET=ios-adhoc → make install TARGET=ios-adhoc). No store upload. Signs with the developer's enrolled team from $IOS_DEVELOPMENT_TEAM (gitignored .env.local) and the installed provisioning profile for com.qallariy.samay; the tracked pbxproj keeps its §3.3 placeholders — team + profile specifier are patched for this build and restored crash-safely.

### ios beta_testflight

```sh
[bundle exec] fastlane ios beta_testflight
```

Build the IPA (export method ad-hoc per §3.3) and upload to TestFlight via App Store Connect

### ios release_appstore

```sh
[bundle exec] fastlane ios release_appstore
```

Build the IPA (export method app-store per §3.3) and submit to App Store Connect (deliver)

----


## Android

### android alpha_firebase

```sh
[bundle exec] fastlane android alpha_firebase
```

Build the release APK and distribute it to Firebase App Distribution testers (§3.3, MVP §10)

### android release_play

```sh
[bundle exec] fastlane android release_play
```

Build the release app bundle and upload it to Google Play via supply (§3.3)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
