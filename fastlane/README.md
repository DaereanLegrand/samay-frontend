# Samay — fastlane (iOS + Android)

> Scaffolded by **M-17** (iOS, phase 4.3) and extended by **M-18** (Android,
> phase 4.3). **Placeholders only — no real Apple/Google/Firebase credentials
> anywhere in this repo** (AGENT-RULES §4, DEPLOYMENT-PLACEHOLDER.md placeholder
> policy). The lanes **fail fast** until every placeholder below is replaced by a
> real value **outside the repo** (CI secrets / developer env).

## What this is

Four lanes (two per platform), invoked by the Makefile **only** (M-15 contract):

| Make target | Exact command | Lane | What it does |
|---|---|---|---|
| `make ios-beta` | `bundle exec fastlane ios beta_testflight` | `beta_testflight` | builds the IPA (export method `ad-hoc` per §3.3) and uploads to TestFlight via App Store Connect API key |
| `make ios-release` | `bundle exec fastlane ios release_appstore` | `release_appstore` | builds the IPA (export method `app-store`) and submits to App Store Connect via `deliver` |
| `make android-alpha` | `bundle exec fastlane android alpha_firebase` | `alpha_firebase` | builds the release APK and distributes it to Firebase App Distribution testers (`alpha-testers` group, MVP §10) |
| `make android-release` | `bundle exec fastlane android release_play` | `release_play` | builds the release app bundle and uploads it to Google Play (track `internal`) via `supply` |

Lane names are pinned by `test/opt-008-makefile-static.sh` §2/§2b and the Makefile
stub greps — renaming a lane breaks the gate.

## Placeholder contract (DEPLOYMENT-PLACEHOLDER.md §3.3)

| Env var | Placeholder value (the "not configured" marker) | Used by |
|---|---|---|
| `IOS_EXPORT_METHOD` | `app-store` (release) / `ad-hoc` (internal); also valid: `development`, `enterprise` | both lanes |
| `APP_STORE_CONNECT_API_KEY_ID` | `AAAAAAAAAA` (10×`A`) | both lanes |
| `APP_STORE_CONNECT_API_ISSUER_ID` | `00000000-0000-0000-0000-000000000000` | both lanes |
| `APP_STORE_CONNECT_API_KEY` | `fastlane/keys/AppStoreConnect_AAAAAAAAAA.p8` (path only — file must NOT exist) | both lanes |
| `MATCH_GIT_URL` | `git@github.com:samay-app/samay-match.git` (placeholder repo — do not create) | both lanes (Match) |
| `MATCH_PASSWORD` | `CHANGE_ME` | both lanes (Match) |
| `TEAM_ID` | `XXXXXXXXXX` (matches `DEVELOPMENT_TEAM` placeholder in `ios/Runner.xcodeproj/project.pbxproj`) | both lanes + Appfile |
| `APPLE_ID` / `FASTLANE_USER` | `CHANGE_ME` | Appfile / fastlane auth |

`fastlane/Appfile` defaults: `app_identifier "com.qallariy.samay"` (verified in
the Xcode project), `team_id` from `$TEAM_ID`, `apple_id` from `$APPLE_ID`.

### Android placeholders (§3.3)

| Env var | Placeholder value (the "not configured" marker) | Used by |
|---|---|---|
| `ANDROID_KEYSTORE_PATH` | `android/app/keystores/release-keystore.jks` (path only — the keystores dir must NOT exist; M-27 wires the gradle `signingConfigs` to read this path) | release signing (M-27) |
| `ANDROID_KEYSTORE_ALIAS` | `samay-release` | release signing (M-27) |
| `ANDROID_KEYSTORE_PASSWORD` | `CHANGE_ME` | release signing (M-27) |
| `ANDROID_KEY_ALIAS_PASSWORD` | `CHANGE_ME` | release signing (M-27) |
| `FIREBASE_API_TOKEN` | `CHANGE_ME` | `alpha_firebase` |
| `PLAY_SERVICE_ACCOUNT_JSON` | `fastlane/keys/google-play-service-account.json` (path only — file must NOT exist) | `release_play` (`supply`) |

## Fail-fast guard

Both iOS and both Android lanes call `assert_credentials_configured!` before
doing anything: if any credential is unset or still equals its §3.3
placeholder, the lane aborts with

```
credentials not configured (placeholders): APP_STORE_CONNECT_API_KEY_ID, ...
```

and nothing is built or uploaded. `IOS_EXPORT_METHOD` outside the valid enum
also aborts. The Android lanes guard on the **full** Android credential set
(keystore path/alias/passwords + Firebase token + Play service account), so a
release-shaped build can never run with placeholder signing. Once a path
credential is real (`.p8` / Play JSON), the guard also verifies the file
actually exists. This makes it impossible to accidentally run a "placeholder
lane".

## Credentials to fill before real use

Checklist (first TestFlight / first release) — mirror of
`<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` §3.4 + §6 rows R20/R21:

- [ ] Create an App Store Connect API key (App Store Connect → Users and Access → Keys, App Manager role) and download the `.p8`
- [ ] Put the `.p8` at `$APP_STORE_CONNECT_API_KEY` (e.g. `fastlane/keys/AppStoreConnect_<KEY_ID>.p8` — gitignored, never committed)
- [ ] Export `APP_STORE_CONNECT_API_KEY_ID` / `APP_STORE_CONNECT_API_ISSUER_ID` (CI secrets or shell env)
- [ ] Create the Match repo (`git@github.com:samay-app/samay-match.git` is a placeholder — use a private repo, never the app repo) and export `MATCH_GIT_URL` + a strong `MATCH_PASSWORD`
- [ ] Replace `TEAM_ID` (real 10-char Apple team ID) in the env **and** in `ios/Runner.xcodeproj/project.pbxproj` `DEVELOPMENT_TEAM` (currently the `XXXXXXXXXX` placeholder)
- [ ] Set `APPLE_ID` (or `FASTLANE_USER`) to the App Store Connect Apple ID
- [ ] Export `SUPABASE_URL` + `SUPABASE_ANON_KEY` for the build dart-defines (M-13/M-21 contract; unset vars are simply not passed to `flutter build …`)
- [ ] **Android:** generate the release keystore (`keytool -genkeypair -v -keystore <secret-store path> -alias samay-release -keyalg RSA -keysize 2048 -validity 10000`) — keep the `.jks` OUT of the repo; export `ANDROID_KEYSTORE_PATH` / `ANDROID_KEYSTORE_ALIAS` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS_PASSWORD`; M-27 wires the gradle `signingConfigs` to read them
- [ ] **Android:** create a Firebase project + App Distribution tester group; export `FIREBASE_API_TOKEN` (Firebase CLI login:ci token) — §6 R23
- [ ] **Android:** create the Google Play service account (Google Cloud Console → IAM & Admin → Service Accounts) with Play Console access; download its key JSON to `$PLAY_SERVICE_ACCOUNT_JSON` (e.g. `fastlane/keys/google-play-service-account.json` — gitignored, never committed); export the path — §6 R24
- [ ] `bundle install` once (writes `Gemfile.lock` — committed by M-19)
- [ ] Re-run `bash test/opt-008-makefile-static.sh` (gate) + `make secrets-check` (M-13) before the first real run

## Signing / Match notes (iOS)

- `ios/Runner.xcodeproj/project.pbxproj`: `CODE_SIGN_STYLE = Manual`,
  `DEVELOPMENT_TEAM = XXXXXXXXXX` (placeholder), empty
  `PROVISIONING_PROFILE_SPECIFIER`. The lanes call
  `match(git_url:, type: <export>, app_store_connect_api_key:)` — Match
  provisions certificates + profiles for the real team and can drive
  `PROVISIONING_PROFILE_SPECIFIER`; the pbxproj `DEVELOPMENT_TEAM` placeholder
  is replaced when real credentials land (store-prep step).
- `match` `type:` is mapped from the export method: `app-store → appstore`,
  `ad-hoc → adhoc` (fastlane match vocabulary: `appstore` / `adhoc` /
  `development` / `enterprise`).

## Signing (Android)

- `android/app/build.gradle.kts` `release` buildType currently signs with the
  **debug** key (`signingConfig = signingConfigs.getByName("debug")`,
  build.gradle.kts:37) — fine for local `flutter run --release`, never for a
  store upload. The §3.3 keystore env vars above are the contract **M-27**
  (gradle owner) wires into `signingConfigs` once real credentials exist.
- **Never** create `android/app/keystores/` or any `.jks` in the repo — the
  keystore is generated at release time and kept in a secret store; only its
  *path* is the contract (`$ANDROID_KEYSTORE_PATH`). `test/opt-008-makefile-static.sh`
  §2b greps that `fastlane/` and `android/` contain no `.jks`/`.p8`/private-key
  material and that `android/app/keystores/` is absent.
- `flutter build apk`/`appbundle --release` IS the `gradle assembleRelease` /
  `gradle bundleRelease` shape from §3.3 with the Flutter toolchain (dart-defines
  incl.) wired in — the lanes use the flutter form for consistency with the iOS
  lanes and the M-13 dart-define contract.

## Dev notes

- Never run `bundle exec fastlane` with the placeholders still set — the
  guard blocks it by design.
- `flutter build ipa --release --export-method <method>` produces the IPA; the
  lane picks the single IPA under `build/ios/ipa/`.
- The AltServer dev-sideload path (`make install TARGET=ios`) stays for local
  devices until real credentials exist (MKE-05).
- `bundle install` needs network + gem resolution — run it with
  `make bundle-install` once, then everything goes through `bundle exec`
  (the Makefile targets already do).
