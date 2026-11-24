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
  (`onboardingStart`) — no checkbox, with inline tappable Terms/Privacy links.
  The game page's primary CTA (`minigamesPlayNow`) deals round 1 immediately with
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

Uncommitted in `Samay/frontend`: nothing — the whole feature landed in `2bdc6e5`,
followed by `ea82106` (changelogs + explicit Play package), `c10c865`/`faf0206`
(the `$(MAKE)` dry-run guard), `b7e9a71`, `da78785`, and `c8ffb53`
(fastlane 2.242.0 + `1.0.0+7`). Superseded by this line: everything below is a
historical record.

Gates at that time: `flutter analyze` clean, `flutter test` 102/102,
`make check` clean (incl. secrets gate), `make -n` expansion of
`deploy`/`publish`/`build` verified.

## What was built in that session

1. **Games-first root deck** restored, card content reduced to name + circular
   play button; pastel/outline alternating title; whitened pastels.
2. **Pass-the-phone lobby** (`local_lobby_screen.dart`): `− n +` stepper (floor 2),
   one name per seat with the pass-the-device prompt (`minigamesLocalPassTo`),
   save-group step, roster with tap-to-rename + X + 3-line drag handle
   (reorder = turn order), segmented rounds/duration with a separate
   custom-value row (`minigamesLobbyCustom`), 3-segment step progress bar.
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

iOS needs no console work beyond adding `onepunchman2506@gmail.com` to the
`Internal Test Group`. Android state is below — the old "hard blockers" were
mostly already satisfied.

### Android state (Google Play)

Settled 2026-11-23 — most of the old blocker list was already done:

- [x] **App exists and Play App Signing is enrolled.** `Admin/infra/STATUS.md`
  records H6 (`deploy TARGET=android ENV=staging TRACK=beta` → "approved; Play
  Open Testing live"), so the first AAB was hand-uploaded in October. **Do not
  create the app or hand-upload a first bundle again** — Play would reject it.
- [x] Android OAuth client for Play builds: `samay-testing-android-play` created
  with the app-signing SHA-1 extracted from the Play-signed APK:

  ```
  BB:FC:5D:DB:95:BE:D6:3C:9A:9F:B2:D4:7B:5A:89:33:77:0E:F5:9D
  ```

  (`apksigner verify --print-certs` on the v2 universal APK; the existing
  `samay-testing-android-debug` client holds the debug keystore SHA-1 and is
  what `make dev` needs — leave it alone.) The client ID it returned is not
  used anywhere: the app authenticates via package + signature, and
  `serverClientId` is the web client (`auth_service.dart:126`).
- [ ] Record that SHA-1 in the vault
  (`qallariy/samay/testing/public/google-oauth-android-sha1`) and, for H8, on
  the `samay-staging` Android client.
- [ ] Google Sign-In on a Play-installed build is the real proof; untested.

**Remaining manual steps** (the Play API still cannot do these):

**1. Confirm the service account is still invited.** Users and permissions →
`play-upload@samay-510205…` → *Release to testing tracks*; and that
`androidpublisher.googleapis.com` is enabled in the **same** Cloud project
(401 otherwise, regardless of role).

**2. Add internal testers.** Internal testing → Testers → `onepunchman2506@gmail.com`.

**3. Pre-flight the credential chain without uploading.** After any `fetch`
(the RAM disk is mounted):

```sh
# The RAM disk is per-run, so capture the path from THE SAME invocation that
# fetched it (deploy prints it) rather than minting a fresh tag here.
fastlane run validate_play_store_json_key \
  json_key:/Volumes/SamayRAM-*/play-upload-service-account.json
```

**4. Then:** `make deploy TARGET=all ENV=testing TRACK=internal`.

Android has never been reached in a run: the iOS lane failed first on
2026-11-23, so `testing-android` → `TRACK=internal` is still untested end to end.

### Known risk on the Android upload

- ~~`versionCode` = 6~~ — done 2026-11-23: bumped to `1.0.0+7`. Build 6 is on
  App Store Connect (iOS), so a repeat upload needs the new number regardless.
- ~~`fastlane/metadata/android/en-US/changelogs/1.txt` is stale~~ — done
  2026-11-23: `changelogs/6.txt` added for `en-US` and `es-419`.

### Small fixes — done 2026-11-23

- `track_play` passes `package_name: "com.qallariy.samay"` explicitly.
- `make -n deploy|publish` no longer executes the recipe (the `$(MAKE)` line was
  run even under `-n`, unlocking the vault on a dry run); both guard on the `n`
  flag and `opt-008` asserts it.
- `tools/pre-commit.sh` called a non-existent `make secrets-check` and a
  backend-owned `tools/check_ports.sh`; `opt-008` asserted `guard-release`
  rejects `ENV=testing` (now store-grade). All three repaired; `make hooks`
  installed.

### Still operator-only

- Record the Play signing SHA-1 in the vault
  (`qallariy/samay/signing/android/play-signing-sha1`) so the
  `KEY-ACQUISITION.md` requirement is mechanical.

### Worldwide release — NOT YET (France currently excluded)

Current state: App Store availability is **Peru only**, and the App Encryption
Documentation question "Is your app going to be available for distribution in
France?" is answered **No**. That answer suppresses the French declaration, so
no documentation is uploaded today.

Revisit all of this before widening availability beyond Peru.

**Encryption documentation (Apple reference: *Export compliance documentation for
encryption*).** Both branches ship the same crypto, so this does not change with
`slim-prod` vs `main`:

| Crypto in use | Required documentation |
|---|---|
| Only what Apple's OS provides | none |
| Industry-standard algorithm NOT provided by Apple's OS | **French encryption declaration** (France only) |
| Proprietary / not accepted by IEEE, IETF, ITU | CCATS **and** French declaration |

Samay is the middle row: `cryptography: ^2.9.0` is pure Dart (no
`cryptography_flutter` bridge), so AES-256-GCM / X25519 / Ed25519 / HKDF run
in-app, not in CryptoKit (`lib/crypto/e2ee_primitives.dart`). Expected work:

- [ ] Answer the France question **Yes** and upload the French encryption
      declaration in App Store Connect.
- [ ] No CCATS: nothing proprietary ships (`docs/security/SECURITY.md` §4 approves
      only standard constructions; RSA/MD5/SHA-1/RC4/3DES/ECB are banned).
- [ ] Confirm whether the French regime also requires an ANSSI notification, or
      whether Apple's upload alone satisfies it. Not verified.
- [ ] `ios/Runner/Info.plist`: keep `ITSAppUsesNonExemptEncryption` **absent**
      while France is in scope. Setting `false` asserts "no documentation
      required" and would suppress the French-declaration flow. It is only
      appropriate for a Peru-only release.

**EU/EEA obligations that are NOT encryption** (must be settled before shipping
to France, since France is EU):

- [ ] **GDPR Article 27 EU representative.** Qallariy Wasi E.I.R.L. is a Peruvian
      controller offering services to EU users, so an EU-based representative is
      likely required. Legal review, not a code change.
- [x] DSA trader status (already recorded in `Admin/infra/STATUS.md`).
- [ ] Store metadata: only `en-US` and `es-419` exist. Not a blocker, but a
      French store listing with no `fr-FR` metadata is a poor experience.
- [ ] Re-check age rating per country: the current rating is 18+ via override for
      a drinking-game app; some EU markets classify alcohol content differently.

**Other markets** (apply the same exercise when widening):

- [ ] Play Console country list is separate from App Store availability; widen
      both together or the storefronts diverge.
- [ ] China mainland requires a separate filing and a local entity; not planned.
- [ ] Korea has its own compliance block in App Store Connect.

### Verified locally 2026-11-23

- `flutter build apk --debug --flavor dev` and `flutter build ios --simulator`
  both succeed with the new `sensors_plus` plugin.
- `dart analyze` clean, `flutter test` 102/102, pre-commit 4/4, secrets PASS,
  `opt-008` all green.
- No store credential exists on this host: the ASC `.p8` and the Play service
  account JSON are vault-only, so steps 2/3/6 below need the passphrase.

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
