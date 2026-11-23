# TODO — samay-frontend (slim-prod)

> This file is repo-scoped.

> **🔴 SCROLL TO THE END.** The live section is
> `UNCOMMITTED WORK IN PROGRESS — READ THIS FIRST`: uncommitted feature work in
> this repo **and** in `Admin/infra`, plus the Google Play blockers that must be
> cleared before `make deploy TARGET=all`. Everything above that section is the
> historical record.

## Branch purpose

`slim-prod` is the minimal production app: **games only**. Features removed here
are re-added progressively on later branches; history is preserved in the
original commits and may be fully squashed at release.

## What shipped on this branch

- **No nav bar.** `lib/core/router/main_shell.dart` and the six-tab shell are
  gone. The root (`GamesHomeScreen`) is the vertical finger-tracked deck
  (`GamesDeck`): the current game is the centred card, the previous one sits
  behind/below, the next behind/above; dragging vertically cycles, tapping
  opens. Each card shows only the game name (centred, one word per line for
  short names, never truncated) and a circular symbol-only play button in its
  bottom-right corner (play triangle, no label). Title lines alternate: odd
  lines take a soft pastel picked at random per game, even lines are a white
  outline. The invite badge shows while a partida awaits an answer. The header is just the `samay` wordmark. Everything else (social,
  packs, notifications, profile, settings, sign-in) opens from the header menu
  sheet.
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

---

# ⚠️ UNCOMMITTED WORK IN PROGRESS — READ THIS FIRST

> Written 2026-11-22. **Committed 2026-11-23.** The `Admin/infra` tree was
> already clean (`tools/release-secrets.sh` landed in `3674eba`); only the
> frontend feature work was outstanding and is now committed.

## State of the two working trees

| Repo | Branch | State |
|---|---|---|
| `Samay/frontend` | `slim-prod` | feature work committed 2026-11-23 |
| `Admin/infra` | `main` | clean — `tools/release-secrets.sh` committed in `3674eba` |

Uncommitted in `Samay/frontend`: `Makefile`, `AGENTS.md`, `fastlane/Fastfile`,
`fastlane/metadata/en-US/release_notes.txt`, `pubspec.yaml` (+6),
`docs/design/DESIGN.md`, `docs/history/phase-16/2026-11-19_games-deck-restored.md`,
plus the whole local-games feature: `lib/features/minigames/local/{charades_decks,
local_group_providers,local_group_store,local_roster}.dart`,
`lib/features/minigames/screens/{local_bottle_screen,local_charades_screen,
local_leaderboard_screen,local_lobby_screen}.dart`,
`lib/features/minigames/widgets/bottle_board.dart`, and the router/l10n/deck edits.

Gates at time of writing: `flutter analyze` clean, `flutter test` 102/102,
`make check` clean (incl. secrets gate), `make -n` expansion of
`deploy`/`publish`/`build` verified.

## What was built this session (uncommitted)

1. **Games-first root deck** restored, card content reduced to name + circular
   play button; pastel/outline alternating title; whitened pastels.
2. **Pass-the-phone lobby** (`local_lobby_screen.dart`): `− n +` stepper (floor 2),
   one name per seat with "pasa el teléfono…", save-group step, roster with
   tap-to-rename + X + 3-line drag handle (reorder = turn order), segmented
   rounds/duration with a separate "Personalizado" numeric row, 3-segment step
   progress bar.
3. **Local play screens:** prompt games (`local_match_screen.dart`), charadas
   forehead-tilt game with Peruvian decks + tile/haptic/timer
   (`local_charades_screen.dart`, `local/charades_decks.dart`), botella with the
   real spinning animation extracted to a shared `widgets/bottle_board.dart`.
4. **Local leaderboard** from the persisted match history
   (`local_leaderboard_screen.dart`), entry in the header menu.
5. **Release pipeline restored to one command:** `RELEASE_SECRETS` points at
   `../../Admin/infra/tools/release-secrets.sh`; `deploy` fetches the vault once,
   builds, publishes, wipes (one passphrase prompt). `ENV=testing` is now
   store-grade, equal to `staging`/`prod`.
6. **Fixed a pre-existing release bug:** `require-release-material` had a leading
   `@` that expands mid-recipe → `@[: command not found`; every release build
   would have failed.
7. **Fixed Android flavor/upload mismatch:** `ENV=testing` builds the `dev`
   flavor (AGP reserves `test*`) and `Fastfile:prebuilt_android_aab` now maps
   `testing → dev`, otherwise the upload looks for `testingRelease/`.
8. **Fixed tracked-file deletion hazard:** the `dev` flavor's
   `google-services.json` is git-tracked; the release cleanup now backs it up and
   restores it instead of `rm -f`.
9. `pubspec.yaml` → `1.0.0+6` (build 5 was consumed by `401b0c2`).

`Admin/infra/tools/release-secrets.sh` was promoted from the stale 101-line copy
to the maintained 222-line version (currently 264 lines after the additions),
plus: `env apple` emits `TEAM_ID` (else
`fastlane/Appfile:5` injects `XXXXXXXXXX`), testing-only Firebase fallback
(gated so prod/staging can never ship the testing Firebase project), keychain
reuse (skips the throwaway keychain when an `Apple Distribution` identity is
already in the login keychain), idempotent keychain setup.

## NEXT SESSION — resume here

### Step 0 — done (2026-11-23)

Frontend feature work committed and the fast gates repaired:
`tools/pre-commit.sh` called a non-existent `make secrets-check` and a
backend-owned `tools/check_ports.sh` (now conditional); `opt-008` asserted
`guard-release` rejects `ENV=testing`, which is now a store-grade release env.
`make hooks` installed.

Then, both platforms, one command (asks for the vault passphrase once):

```sh
make deploy TARGET=all ENV=testing TRACK=internal
```

iOS needs no console work beyond adding `onepunchman2506@gmail.com` as an
internal tester. **Android has hard blockers — see below.**

### Android blockers (Google Play) — do these BEFORE `TARGET=all`

The Play API cannot create an app. Verified this session:

- `applicationId` is `com.qallariy.samay` for every flavor
  (`android/app/build.gradle.kts:72`).
- `android/app/src/dev/google-services.json` → project `samay-testing`, and its
  **only** OAuth client is `client_type: 3` (web). **No Android client at all.**
- No Play App Signing SHA-1 is recorded in the repo or the vault
  (`KEY-ACQUISITION.md:260` requires upload SHA-1 **and** Play SHA-1).

**1. Confirm the app exists in Play Console.** If `com.qallariy.samay` is absent:
Play Console → Create app (es-419, App, Free). The package name is fixed on the
first upload.

**2. Upload the first AAB by hand — this cannot be automated.**

```sh
make build TARGET=android ENV=testing
# → build/app/outputs/bundle/devRelease/app-dev-release.aab
```

Play Console → Test and release → Testing → Internal testing → Create new
release → upload that `.aab` → accept **Play App Signing** → Save → Start
rollout. Reason: fastlane/supply docs state you must upload at least one build
manually first, and the Play signing key does not exist until the first bundle
arrives.

**3. Copy the Play signing SHA-1.** App integrity → App signing key certificate.
Register **both** fingerprints (upload key + Play key) on the Android OAuth
client for `com.qallariy.samay` in the `samay-testing` GCP project. Without this,
Google Sign-In fails with `DEVELOPER_ERROR (10)` on every Play-installed build.

**4. Invite the service account.** Play Console → Users and permissions → the
`client_email` from `play-upload-service-account.json` → App permissions → the
app → *Release to testing tracks*. Also confirm
`androidpublisher.googleapis.com` is enabled in the **same** Cloud project as
that service account (401 otherwise, regardless of role).

**5. Add internal testers.** Internal testing → Testers → list with
`onepunchman2506@gmail.com` → Save.

**6. Pre-flight the credential chain without uploading.** After any `fetch`
(the RAM disk is mounted), prove the service account can reach Play:

```sh
fastlane run validate_play_store_json_key \
  json_key:/Volumes/SamayRAM/play-upload-service-account.json
```

A green result means SA + API enablement + Play permission are all correct, so
the only remaining unknown is the app/track state.

**7. Only then:** `make deploy TARGET=all ENV=testing TRACK=internal`.

### Known risk on the Android upload

- `versionCode` = 6. If 6 was ever uploaded, Play rejects it; bump to `+7`.
- `fastlane/metadata/android/en-US/changelogs/1.txt` is stale (version code 1).
  Add `default.txt` or rename to `6.txt`. Cosmetic today because
  `track_play` passes `skip_upload_metadata: true` (changelogs only upload
  alongside metadata), but it will bite the first time metadata is uploaded.

### Optional small fixes, not yet done

- `fastlane android track_play`: pass `package_name: "com.qallariy.samay"`
  explicitly instead of letting supply infer it from the AAB.
- Record the Play signing SHA-1 in the vault
  (`qallariy/samay/signing/android/play-signing-sha1`) so the
  `KEY-ACQUISITION.md` requirement is mechanical.

### Deploy path reference (as built)

| Env | Vault profile | Backend | Android flavor |
|---|---|---|---|
| `testing` | `testing-apple` / `testing-android` | `samay-api-testing.qallariy.lat` | `dev` |
| `staging` | `staging-apple` / `staging-android` | `samay-api-staging.qallariy.lat` | `staging` |
| `prod` | `apple` / `android` | `samay-api.qallariy.lat` | `prod` |

`ENV=testing` is store-grade: same signed path, `APP_ENV=dev` (IAP enabled;
testing has no RevenueCat keys, so `RC=true` would hard-fail — leave `RC=false`).

Note: `samay-testing.qallariy.lat` does **not** resolve; the API host is
`samay-api-testing.qallariy.lat` (vault + `.env` agree). Change the vault entry
`qallariy/samay/testing/public/supabase-url` if that hostname is meant to change.
