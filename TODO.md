# TODO — samay-frontend (slim-prod)

> Live cross-cutting state lives in `<private-ops-repo>/STATUS.md`. This file is
> repo-scoped only.

## Branch purpose

`slim-prod` is the minimal production app: **games only**. Features removed here
are re-added progressively on later branches; history is preserved in the
original commits and may be fully squashed at release.

## What shipped on this branch

- **No nav bar.** `lib/core/router/main_shell.dart` and the six-tab shell are
  gone. The root (`GamesHomeScreen`) is a plain vertical LIST of the four games
  — all visible at once, one tap each (the finger-tracked carousel deck was
  removed: it clipped the game names and hid three of the four games).
  Everything else (social, packs, notifications, profile, settings, sign-in)
  opens from the header menu sheet.
- **One tap to first play.** Onboarding is a single affirmative button
  ("aceptar y jugar") — no checkbox, with inline tappable Terms/Privacy links.
  The game page's primary CTA ("jugar ahora") deals round 1 immediately with
  two default seats; names are corrected mid-match from the header players
  sheet, so nothing is typed before playing.
- **No permission dialog on first run.** FCM/push is not initialised at boot
  (`Info.plist` sets `FirebaseMessagingAutoInitEnabled=false` and
  `FirebaseAppDelegateProxyEnabled=false`); `PushService.activate()` runs from
  `PushNotificationListener` only after onboarding AND only on the second
  launch. `permission_handler` was removed (unused after the QR scanner left).
- **Guest-first auth.** `signInAnonymously` + `bootstrap_profile` (one atomic
  RPC that records the 18+/terms acceptance and creates the guest `users` row).
  Apple/Google **link** onto the guest (`linkIdentityWithIdToken` → same uid) and
  then `confirm_my_account`.
- **Single-device play.** `lib/features/minigames/local/` is a pure-Dart engine
  (judge/subject rotation, no-repeat prompts, done/skip scoring, scoreboard) with
  33 unit tests in `test/local_match_test.dart`. The screen
  (`local_match_screen.dart`) reuses the shared design widgets, loads its bank
  through `localMatchPackProvider` (cache-first, one network fetch on a cold
  cache) and persists finished matches to the `minigame_summary_cache` box.
- **QR multi-device.** The lobby renders `samay://join/<CODE>` with `qr_flutter`;
  `join_scanner_screen.dart` scans it (bare codes and `/j/<CODE>` https links
  also parse), and `leave_minigame_session` backs the participant leave action.
- **Prompt packs.** `prompt_pack_service.dart` + `packs_repository.dart`
  (encrypted `prompt_pack_cache` box, stale-while-revalidate) and the catalogue
  screen with lock states for paid packs.
- **Removed features** (dirs deleted, not stubbed): events, chat, feed, photos,
  shards, cosmetics, rankings, subscriptions-as-a-feature (the paywall lives in
  `features/packs`).

## Verified

- `flutter analyze` clean (whole repo), `flutter test` 98/98.
- `flutter build ios --simulator` and `flutter build apk --debug --flavor dev`
  both succeed.
- On device (iPhone 18 Pro, local stack): onboarding → deck → menu → game page →
  single-device match played 5/5 rounds with correct judge/subject rotation and
  a final scoreboard.

## Known issues

- **iOS simulator without code signing:** `HiveService.init` fails with
  `PlatformException(-34018, "A required entitlement is not present")`, so the
  encrypted caches (including `prompt_pack_cache`) do not persist on a
  `--no-codesign` simulator build. The app degrades safely (boot continues,
  packs still fetch over the network), but offline play needs a properly signed
  build to exercise. Not a code defect.
- The single-device screen swallows a pack-load failure into its start-button
  snackbar; if offline debugging is needed, add a log line in `_loadPack`.

## Next (not on this branch)

Re-add, in order: chat, events, feed/photos, rankings, shards/wagers. The
backend keeps the tables (client grants revoked in `300_slim/05_removed.sql`), so
each re-add is a GRANT plus the feature code.
