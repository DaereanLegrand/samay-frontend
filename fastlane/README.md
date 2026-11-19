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

Build a signed ad-hoc IPA for on-device installs (make build TARGET=ios-adhoc → make install TARGET=ios-adhoc). No store upload. Signs with the developer's enrolled team from $IOS_DEVELOPMENT_TEAM (gitignored .env.local) and the installed provisioning profile for com.qallariy.samay; the tracked pbxproj keeps its §3.3 placeholders — team + profile specifier are patched for this build and restored crash-safely.

### ios track_internal

```sh
[bundle exec] fastlane ios track_internal
```

Upload the built IPA to TestFlight internal testers (TRACK=internal)

### ios track_external

```sh
[bundle exec] fastlane ios track_external
```

Upload the built IPA to TestFlight external testers (TRACK=external; set TESTFLIGHT_EXTERNAL_GROUPS)

### ios track_prod

```sh
[bundle exec] fastlane ios track_prod
```

Submit the built IPA to the App Store (TRACK=prod; App Store Connect review)

----


## Android

### android track_play

```sh
[bundle exec] fastlane android track_play
```

Upload the built AAB to a Google Play track ($TRACK: internal|alpha|beta|production)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
