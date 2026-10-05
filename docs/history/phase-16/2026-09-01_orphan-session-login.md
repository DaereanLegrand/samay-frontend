# 2026-09-01 — Orphan sessions land on login (funnel can't appear out of nowhere)

## What happened

Android + Waydroid apps were reinstalled and the backend was reset. On next
launch the restored (persisted) auth session had an authenticated user with NO
`users` row (the backend wipe deleted all profiles). The app booted the user
straight into the birthdate (age gate) screen instead of the login screen —
a poor fallback. E2EE prekey publish also spammed `23503` FK violations
(`e2ee_identity_keys.user_id` → `users.id`) because there was no profile row
to attach the keys to.

## Root cause

`AuthNotifier._resolveInitialState()` (app-start session restore) treated a
profile-less authenticated session as a legitimate pre-profile state and
returned `AuthState(authenticated: true, hasProfile: false)`. The
funnel-completion gate added in commit `1985119` then silently redirected any
authenticated-without-profile user to `/auth/age-gate` (the birthdate screen).
So the funnel — which is only meant to be entered EXPLICITLY (OTP → age gate →
privacy/terms → profile setup) — appeared implicitly out of nowhere.

## Fix

- `_resolveInitialState` now detects an **orphan session**: authenticated user
  with no `users` row on restore → sign out → land on the login screen. The
  signup funnel can only be reached by explicitly walking OTP → age gate, never
  by a restored session.
- `AuthGuard` funnel-scoped gate: the funnel steps (`verify` / `ageGate` /
  `privacyTerms` / `profileSetup`) are STRICTLY signup-process screens:
  - unauthenticated → only pre-auth routes + `signup` (contact) + `verify`
    (reached BEFORE the code verifies) are visible; every post-verify funnel
    step redirects to login;
  - authenticated → funnel steps are allowed only while `hasProfile == false`
    (signup-in-progress); a fully-registered user is redirected to the feed.
  Under no circumstance can the age gate appear outside the signup process.
- The signup entry points are unchanged: contact → OTP (push, unauthenticated)
  → age gate (push, authenticated, no profile) → privacy/terms → profile setup
  → feed.

## Follow-up — feed flash + splash (2026-09-02)

The first orphan-gate fix left a one-frame **feed flash** on cold start: the
`initialSession` auth event fires mid-restore and published
`AsyncData(authenticated, hasProfile:false)` BEFORE `_resolveInitialState`'s
orphan gate ran — the guard then redirected login → feed for one frame
(mounting the realtime/friends-cache listeners → `UnauthorizedError` storms +
`E2EE prekey publish failed: No authenticated user`).

- The orphan gate was extracted into `_orphanGate(user, state)` and now also
  guards the `initialSession` / `signedIn` / `tokenRefreshed` auth-event paths
  in `_onAuthStateChange` — a restored profile-less session is signed out at
  the FIRST auth event, before the router ever sees it. No feed flash.
- Added a **boot splash**: `VSplashWordmark` — "Samay" alone (VDisplayText,
  monochrome Playfair white, size 64) slowly pulsating (α 0.55 ↔ 1.0 on a
  `splashPulse` 2s easeInOut repeat), black field, nothing else. Mounted
  ABOVE `MaterialApp` in `_SamayRoot` (app.dart) while
  `authStateProvider.isLoading`, fading out on `SamayDurations.fast`. Reduced
  motion → static full-α wordmark (no ticker). The splash doubles as the
  previously-absent loading state for the restore window, so the router never
  shows a partial screen under it.
- `samay_durations.dart` gains the `splashPulse` token.

## Follow-up — splash crash + native launch (2026-09-02)

First splash attempt crashed the app on device:

**MISTAKE:** the splash was mounted above `MaterialApp` with only a `Stack` —
`RichText` (the `VDisplayText` wordmark) requires a `Directionality` ancestor,
which only MaterialApp/WidgetsApp provide. Boot → `No Directionality widget
found` crash.

Fix: `_SamayRoot` now wraps the whole layer in `Material(color:
scaffoldBackgroundColor)` + `Directionality(ltr)` (Text needs it) + a
`MediaQuery` so the pulse honors reduced-motion; `VSplashWordmark` is now a
proper `Scaffold(backgroundColor: discoBlack)` with the wordmark centered.
Wordmark is lowercase **"samay"** (matches the `welcomeSamay` "vive" lowercase
voice).

Native launch screen (industry standard): the Android window that appears
while the process starts previously flashed WHITE (default Flutter
launch_background). Now:
- `android/.../drawable/launch_background.xml` → flat `@color/launch_background`
  (#000000, discoBlack) — brand background, no white flash, no static logo
  (the Flutter splash renders the pulsing wordmark on first frame);
- `values/styles.xml` + `values-night/styles.xml` → `Theme.Black.NoTitleBar`
  for BOTH LaunchTheme and NormalTheme, NormalTheme windowBackground = black
  (no white gap between native splash and Flutter splash);
- `values/colors.xml` → adds `launch_background` #000000;
- iOS `LaunchScreen.storyboard` background → black (the bundled LaunchImage is
  a transparent 1×1 PNG, so it stays clean).

Build verified: `flutter build apk --debug` ✓, `dart analyze lib/` clean.

## Follow-up — FINAL: one native splash, icon only, no text (2026-09-02)

The double-splash saga ended with the requirement: **exactly ONE splash screen**
— the NATIVE launch screen, showing a SMALLER version of the app icon, with NO
text. The Flutter splash (`VSplashWordmark`) is deleted.

**Why two splashes appeared:**
- **Android API 31+**: the OS draws a system splash with the app icon
  (`android:icon`) regardless of `windowBackground` → "one only icon".
- **Flutter splash**: `_SamayRoot` showed the pulsing icon+"samay" with a
  min-display hold → "icon and below samay". Two surfaces.
- **iOS**: my earlier composite `LaunchImage` was INVERTED (CoreGraphics
  bottom-left origin put "samay" ABOVE the icon) → "samay on top of icon",
  then the Flutter splash below it → two.

**Final state (single native splash, icon only, smaller):**
- **Flutter**: `lib/shared/widgets/v_splash_wordmark.dart` DELETED; `lib/app.dart`
  reverted to the original plain `ConsumerWidget` (no splash layer, no
  min-display hold, no Directionality wrapper); `splashPulse` token removed
  from `samay_durations.dart`; the `app_icon_foreground.png` Flutter asset
  removed from `pubspec.yaml`. The app boots straight into the router.
- **Android**:
  - `drawable/launch_background.xml` + `drawable-v21/launch_background.xml` →
    plain black (`@color/launch_background`), no bitmap — a SOLID color so the
    launch window and the OS system splash never double-draw.
  - `drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/launch_image.png` → icon-only,
    transparent bg, no text. Artwork is ~45% of the density canvas (e.g. 54px
    art on a 120px mdpi canvas, 216px on a 480px xxxhdpi canvas) so the OS
    splash renders the icon noticeably small — matching the iOS size (96pt).
    This was the final sizing fix after the user reported the Android icon
    was still too big.
  - `values-v31/styles.xml` (NEW): API 31+ `LaunchTheme` sets
    `android:windowSplashScreenBackground`=black and
    `android:windowSplashScreenAnimatedIcon`=@drawable/launch_image — the OS
    splash shows the single smaller icon on black. NormalTheme window black.
  - `values-night/styles.xml`: NormalTheme windowBackground → black
    (was `?android:colorBackground`).
  - `values/colors.xml`: `launch_background` #000000.
- **iOS**: `LaunchImage` imageset → icon-only (96/192/288 px, transparent bg),
  storyboard black + centered icon, no text, no composite.

## Follow-up — launch-image generator (2026-09-02)

`tools/launch_gen.dart` (NEW): deterministic Dart script that derives every
native splash image from `assets/icons/app_icon_foreground.png` (the icon
source generated by `tools/icon_gen.dart`). One command:

```bash
dart run tools/launch_gen.dart   # after re-generating the icon
```

Reads the 1024×1024 RGBA icon source; writes:
- Android system-splash icons, artwork at ~45% of the density canvas:
  `drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/launch_image.png`
  (120px/54 art → 480px/216 art);
- iOS launch images (full-canvas, `contentMode=center`):
  `LaunchImage.png` 96, `@2x` 192, `@3x` 288.

Pure Dart, no deps (minimal PNG decoder + premultiplied-alpha box-filter
scaler + icon_gen's PNG encoder); byte-identical across runs (verified).
So a future icon change is: `dart run tools/icon_gen.dart` →
`dart run tools/launch_gen.dart` → rebuild. The splash assets are derived, not
hand-edited.

Build verified: `flutter build apk --debug` ✓, `dart analyze lib/` clean.

## MISTAKE

The funnel-completion gate (1985119) was wrong to make the app **restore path**
redirect to the age gate. Session restore and the explicit signup funnel are
different concerns; the age gate is only legitimate when the user walked OTP →
age gate in THIS session. A backend reset (or account deletion) makes a
restored profile-less session an orphan, not a mid-funnel user.

## Commands

```bash
dart analyze lib/core/providers/auth_provider.dart lib/core/router/auth_guard.dart
```

## Files

- `lib/core/providers/auth_provider.dart` — orphan-session gate in `_resolveInitialState` + `_onAuthStateChange` (`_orphanGate`)
- `lib/core/router/auth_guard.dart` — funnel redirect removed (guard-only)
- `lib/shared/widgets/v_splash_wordmark.dart` — DELETED (Flutter splash removed)
- `lib/app.dart` — reverted to plain ConsumerWidget (no splash layer)
- `lib/core/theme/samay_durations.dart` — `splashPulse` token removed
- `pubspec.yaml` — `app_icon_foreground.png` Flutter asset removed
- `android/app/src/main/res/drawable/launch_background.xml`, `drawable-v21/launch_background.xml` — plain black
- `android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/launch_image.png` — icon-only, smaller, no text
- `android/app/src/main/res/values-v31/styles.xml` — NEW: system-splash icon-only + black
- `android/app/src/main/res/values/styles.xml`, `values-night/styles.xml` — Theme.Black + black window
- `android/app/src/main/res/values/colors.xml` — `launch_background` #000000
- `ios/Runner/Base.lproj/LaunchScreen.storyboard` — black background
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{,@2x,@3x}.png` — icon-only
