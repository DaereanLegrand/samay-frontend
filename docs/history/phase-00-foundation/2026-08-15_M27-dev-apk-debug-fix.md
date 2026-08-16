# 2026-08-15 — Makefile: dev apk builds are DEBUG (build-install android/waydroid fix)

Reported: `make build-install TARGET=android` and `TARGET=waydroid` both failed.

## Root cause (NOT the Makefile gate)
Both targets run `flutter build apk`, which always assembles the **release**
variant. Samay's `android/app/build.gradle.kts` (M-27, 2026-08-10) made release
signing fail-fast: `signingConfig = null` + a `GradleException` on
`assembleRelease`/`bundleRelease` unless the four §3.3 `ANDROID_KEYSTORE_*`
envs are set AND the `.jks` exists (which it deliberately never does in-repo).
So the keystore requirement has nothing to do with a PROD flag — it is
Gradle-level, unconditional on the release build type.

Juega's equivalent `flutter build apk` works because its
`android/app/build.gradle.kts` falls back to the debug key when no keystore
exists (`release.signingConfig = if (hasSigning) release else debug`).

Bonus gotcha found: even with a real keystore, a release-signed APK cannot
`adb install -r` over the debug-signed apps already on the <build-host>'s
emulator/waydroid (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`).

## Fix (user chose B: debug APK for dev)
- `Makefile`: `BUILD_MODE ?= debug`; `APK` is now
  `build/app/outputs/flutter-apk/app-$(BUILD_MODE).apk`; the apk branch of
  `build` runs `flutter build apk --$(BUILD_MODE)`.
- M-27 posture UNTOUCHED: the gradle guard still kills `assembleRelease`/
  `bundleRelease` without the keystore; real release/AAB packaging goes
  through fastlane/M-22, never this target. opt-008 §6 assertions (no
  debug-signing of release, guard present) still pass.
- The tunnel doc example path was updated to `app-debug.apk`.

## Verified
- `bash test/opt-008-makefile-static.sh` — all checks pass (incl. the new
  `flutter build apk --debug` line resolving in `make -n`).
- `make build TARGET=android` → `assembleDebug` success, `app-debug.apk`.
- `make install TARGET=android` (<build-host> LAN tunnel) → Success.
- `make install TARGET=waydroid` (waydroid tunnel, IP <local-lan-ip>) →
  Success.
- `make build-install TARGET=android` and `TARGET=waydroid` — both end-to-end
  Success.
- Both devices: `dumpsys package com.qallariy.samay` versionName 1.0.0,
  launchable.

## MISTAKE
- None this round; the earlier chat session's `flutter drive` attempts left a
  crash-recovery banner in the app state ("La app se recuperó de un cierre
  inesperado") on the simulators — harmless, dismissed by tapping OK.

## Commands
- make build TARGET=android / make install TARGET=android
- make build-install TARGET=android | make build-install TARGET=waydroid
