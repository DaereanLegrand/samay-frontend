# 2026-08-10 — M-18: fastlane Android lanes — platform :android, alpha_firebase + release_play, gate, docs

**Agent:** M-18 (Phase 4.3 — fastlane track, Android lanes; sole agent this run)
**Role:** (1) extend `fastlane/Fastfile` (M-17's file) with `platform :android` +
`lane :alpha_firebase` + `lane :release_play` per the M-15 lane-name contract
(DEPLOYMENT-PLACEHOLDER.md §3.3) — ONE parametrized fail-fast credential guard;
(2) signing: lanes FAIL FAST on keystore placeholders, NO `android/app/keystores/`
created, no `.jks`; gradle `signingConfigs` wiring = M-27 handoff; (3) extend
`test/opt-008-makefile-static.sh` §2b (Android lane names, `platform :android`,
placeholder literals, no `.jks`/`.p8`/private-key material in `fastlane/` or
`android/`, keystores dir absent); (4) update `fastlane/README.md` (android table
+ checklist + signing notes); (5) daily log + TODO.md + DEPLOYMENT-PLACEHOLDER.md
§6 R22-R24 + §3.3/§7 updates.
**Campaign:** Samay 180-agent orchestration; Juega untouched (read-only reference),
NO commits, NO bundle/fastlane runs, NO network ops — verification is parse-only
(`ruby -c`) + the static gate + `make -n` dry-run.

---

## What was built

### 1. `fastlane/Fastfile` (extended — M-17's file, locked per mission)

- **Header:** now documents both platforms + the 4 pinned lane names; new
  SIGNING (Android) paragraph — release buildType signs with the DEBUG key today
  (`android/app/build.gradle.kts:37`), the §3.3 keystore envs are the contract
  M-27 wires into `signingConfigs`; `android/app/keystores/` must stay absent.
- **`REQUIRED_ANDROID_CREDENTIAL_ENV`** (new constant, §3.3 verbatim):
  `ANDROID_KEYSTORE_PATH = android/app/keystores/release-keystore.jks`,
  `ANDROID_KEYSTORE_ALIAS = samay-release`, `ANDROID_KEYSTORE_PASSWORD` +
  `ANDROID_KEY_ALIAS_PASSWORD = CHANGE_ME`, `FIREBASE_API_TOKEN = CHANGE_ME`,
  `PLAY_SERVICE_ACCOUNT_JSON = fastlane/keys/google-play-service-account.json`.
- **ONE parametrized guard:** `assert_credentials_configured!(creds = REQUIRED_CREDENTIAL_ENV)`.
  iOS call sites unchanged (default arg); Android lanes pass
  `REQUIRED_ANDROID_CREDENTIAL_ENV`. The iOS-only `.p8` existence check became a
  generic per-credential FILE check map (`.p8` for ASC, Play service-account
  JSON) that only applies to credentials present in the passed hash and only
  once the env value is real (placeholder paths stay path-only, never created).
  `ANDROID_KEYSTORE_PATH` is deliberately NOT file-checked: the keystore is
  generated + kept in a secret store at release time, never in the repo.
  Message literal unchanged: `credentials not configured (placeholders): …`
  (pinned by opt-008 §2b).
- **`dart_defines` helper extracted** from `build_ios_ipa` (behavior identical);
  shared by the new `build_android_artifact(artifact)` (`apk` →
  `build/app/outputs/flutter-apk/app-release.apk`, `appbundle` →
  `build/app/outputs/bundle/release/app-release.aab`, with existence checks).
- **`platform :android`** with the two contract lanes:
  - `alpha_firebase` — guard (full Android set) → `build_android_artifact("apk")`
    → `firebase_app_distribution(apk_path:, firebase_cli_token:
    ENV["FIREBASE_API_TOKEN"], groups: "alpha-testers")` (MVP §10).
  - `release_play` — guard (full Android set) → `build_android_artifact("appbundle")`
    → `supply(track: "internal", aab:, json_key: ENV["PLAY_SERVICE_ACCOUNT_JSON"],
    skip_upload_metadata/screenshots/images/apk: true)`.
  `default_platform(:ios)` unchanged (additive platform block).

### 2. `test/opt-008-makefile-static.sh` — §2b extended (locked per mission)

- Header NOTE: M-18 line documenting the extension.
- §2b now covers both platforms: title/comment updated; after the iOS checks,
  asserts `platform :android` + `lane :alpha_firebase` / `lane :release_play` +
  the three Android placeholder literals (`android/app/keystores/release-keystore.jks`,
  `samay-release`, `fastlane/keys/google-play-service-account.json`).
- Credential-material scan extended beyond `fastlane/`:
  - `find fastlane/ android/ -name '*.jks' -o -name '*.p8'` → zero hits;
  - private-key-material grep (`-----BEGIN` / `BEGIN … PRIVATE KEY`) now also
    over `android/` (this is what .p8 and Play JSON content look like);
  - `fastlane/keys/google-play-service-account.json` must NOT exist;
  - `android/app/keystores/` directory must NOT exist.

### 3. `fastlane/README.md` (locked per mission)

- Title → "fastlane (iOS + Android)"; usage table + both Android rows
  (`make android-alpha` / `make android-release` ↔ exact commands ↔ lanes).
- New "Android placeholders (§3.3)" table (6 env vars).
- Fail-fast guard section: parametrized helper, full-set Android guard, path-file
  existence checks.
- "Credentials to fill before real use" checklist: 3 Android items (keystore
  generation OUT of the repo, Firebase token, Play service-account JSON).
- New "Signing (Android)" section: debug-key signing today (build.gradle.kts:37),
  M-27 `signingConfigs` handoff, never-create-`.jks` rule (gate-enforced), and
  the flutter-build-equals-gradle note.

### 4. Docs (locked per mission)

- `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`: header "Last verified" → M-18; §3 intro
  (both fastlane halves exist, `.github/` still pending); §3.3 new M-18 LANDED
  block after M-17's; §6 R22/R23/R24 flipped ✅ (placeholders wired; keystore
  generation/account creation stays a release-time ops action + M-27); §7 M-18
  verification addendum.
- `docs/to-fix/TODO.md`: M-18 workstream block (newest-first, before M-17's).

### 5. `docs/history/phase-00-foundation/2026-08-10_M18-fastlane-android.md` (this log)

---

## Decisions made and why

- **One parametrized guard, not a second copy:** the mission requires "keep ONE
  helper, parametrized". `assert_credentials_configured!(creds = REQUIRED_CREDENTIAL_ENV)`
  keeps M-17's iOS call sites byte-identical (default argument) while the Android
  lanes pass their own hash — no behavior drift between platforms, one
  "credentials not configured (placeholders)" contract literal.
- **Both Android lanes guard on the FULL 6-variable set (incl. keystore):** the
  mission's signing directive says the lanes must fail fast while keystore envs
  are unset/CHANGE_ME — so `alpha_firebase` does not get a laxer
  Firebase-token-only guard. A release-shaped build (both lanes build
  `--release`) can never run with placeholder signing, even though the gradle
  release buildType today signs with the debug key.
- **`flutter build apk/appbundle --release` instead of the raw `gradle`
  action:** §3.3 says "`supply`/`gradle bundleRelease`" — the flutter form IS
  `gradle assembleRelease/bundleRelease` with the Flutter toolchain wired in, and
  it lets both platforms share the M-13 dart-defines passthrough (extracted
  `dart_defines` helper) exactly like M-17's `build_ios_ipa`. Documented in
  README + log so a future dev doesn't "fix" it into a raw gradle call.
- **`ANDROID_KEYSTORE_PATH` never file-checked:** unlike the `.p8`/Play JSON,
  the keystore must NEVER exist in the repo (gate-enforced) — it lives in a
  secret store; only its path is the contract for M-27's `signingConfigs`.
- **No `android/app/keystores/` created, no `.jks` committed:** per the
  directive "no keystore credentials"; the §3.3 path stays path-only.
- **opt-008 §2b checks stay grep-based (no bundler/fastlane):** consistent with
  M-15/M-17 — static, hermetic, zero network.

## MISTAKE / gotcha

- **Gotcha (checked, not hit):** the new `find` gate
  `find "$REPO/fastlane" "$REPO/android" -name '*.jks' -o -name '*.p8'` relies on
  find's start-point-global expression semantics (each start point gets the whole
  `-o` expression) — verified the precedence is correct on BSD find (macOS) and
  that no false positive fires on the current tree (no such files exist).
- **Gotcha (guarded):** the `.p8`/Play-JSON file-existence check must NOT fire
  while the env value still equals the §3.3 placeholder path (the file is
  absent by design) — the parametrized guard skips any credential already in the
  `missing` (unset-or-placeholder) list before file-checking.
- **Handoff clarity:** the mission's lock list does NOT include the category
  file `docs/to-fix/categories/14-MAKEFILE-CICD.md` (D-03's) — status flips
  there stay D-03's at re-verification, per the M-11/M-13/M-15 precedent.

## Commands run (reproducibility)

```bash
export AGENT_NAME="M-18-fastlane-android"
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME" --timeout 120   # ×6 files (list below)
tools/agent_lock.sh list                     # 6 locks held by M-18-fastlane-android

# Syntax (parse-only — never executes, no bundler/fastlane/network):
ruby -c fastlane/Fastfile                    # Syntax OK

# Static gate (extended §2b)
bash test/opt-008-makefile-static.sh         # exit 0 — all checks green

# Make contract dry-runs
make -n android-alpha                        # resolves: bundle exec fastlane android alpha_firebase
make -n android-release                      # resolves: bundle exec fastlane android release_play

# Secrets gate (no new patterns; placeholder literals match no P1-P6 shape)
make secrets-check                           # PASS (unchanged)

# Credential-material assertions (independent of the gate)
find fastlane android -name '*.jks' -o -name '*.p8'   # (no output)
ls android/app/keystores                     # No such file or directory (absent)
grep -rE 'BEGIN.*PRIVATE KEY' fastlane android        # (no hits)

tools/agent_lock.sh release <path> --owner "$AGENT_NAME"                  # ×6, all released
```

## Verification

- [x] `ruby -c fastlane/Fastfile` → **Syntax OK** (parse-only; fastlane's loader
      is never involved, no bundler/network/credentials needed — same rationale
      as M-17).
- [x] `bash test/opt-008-makefile-static.sh` → **exit 0**: §1 `make -n` all 45
      targets; §2 stub contract; **§2b green** — iOS half unchanged
      (platform :ios, both iOS lanes, guard literal, Appfile, Gemfile,
      fastlane-only scans) + the new Android half (platform :android, both
      Android lanes, 3 Android placeholder literals, no `.jks`/`.p8` files in
      fastlane/ or android/, no private-key material in android/, Play JSON
      absent, `android/app/keystores/` absent); §3 migrate-check probes; §4
      deploy placeholders; §5 `bash -n` self.
- [x] `make -n android-alpha android-release` resolve to `bundle exec fastlane
      android alpha_firebase` / `… release_play` (M-15 stub contract satisfied).
- [x] `make secrets-check` PASS — no tracked-file hits from the new literals
      (path/alias/CHANGE_ME match no P1-P6 pattern); `fastlane/keys/` is
      gitignored; `.jks`/`.p8`/JSON never created.
- [x] `bundle exec fastlane` / `bundle install` NOT run (no network, no
      credentials — AGENT-RULES §0.3; the fail-fast guard exists precisely so
      that state is safe).
- [x] Lock evidence: 6 files acquired + released by `M-18-fastlane-android`.
- [x] No commits; no `git add`; Juega untouched (read-only); no containers; no
      network ops.

## Lock list (acquire → release, owner `M-18-fastlane-android`)

1. `fastlane/Fastfile` — platform :android + both lanes + parametrized guard (M-17's file, extended)
2. `fastlane/README.md` — android table + checklist + signing notes (M-17's file, extended)
3. `test/opt-008-makefile-static.sh` — §2b Android half + credential-material scan extension
4. `docs/to-fix/TODO.md` — M-18 workstream block
5. `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` — header, §3 note, §3.3 M-18 block, R22-R24, §7 addendum
6. `docs/history/phase-00-foundation/2026-08-10_M18-fastlane-android.md` — this log

## Issues found / handoffs (reported, NOT fixed — out of scope)

1. **Handoff M-19:** commit `Gemfile.lock` after the first real `bundle install`
   (`make bundle-install`) — unchanged from M-17; FILE-OWNERSHIP rows for M-17
   (`Fastfile`+`Appfile`) and M-19 (`Gemfile`+`README.md`) are stale per M-17's
   report; M-19's remaining deliverable is the lockfile. NOTE: `fastlane/README.md`
   is now M-18-edited too — orchestrator should refresh the ownership map.
2. **Handoff M-27 (gradle):** wire `android/app/build.gradle.kts` `signingConfigs`
   to read the §3.3 env vars (`ANDROID_KEYSTORE_PATH` = the path-only contract
   `android/app/keystores/release-keystore.jks`, `ANDROID_KEYSTORE_ALIAS`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS_PASSWORD`) and replace the
   debug signing of the release buildType (line 37). The Fastfile guard already
   fails fast until all four are real — gradle must NEVER fall back to debug
   signing when the env is unset (mirror the fail-fast contract).
3. **Handoff M-22 (release.yml):** use the SAME lane names — `fastlane android
   alpha_firebase` + `fastlane android release_play` (and the iOS pair) — with
   the §6 secret names as `${{ secrets.* }}` references only.
4. **Handoff (release-time ops, §6 R22-R24):** the first Play/Firebase run needs
   the keystore generated OUTSIDE the repo (kept in a secret store), the real
   Firebase CLI token, and the Play service-account JSON at the gitignored
   `fastlane/keys/` path — see fastlane/README.md checklist.
5. **Flagged (not a bug):** `alpha_firebase` guards on the FULL Android
   credential set (incl. keystore), so it cannot run until release signing creds
   exist even though App Distribution could technically accept a debug-signed
   APK. Deliberate per the mission's signing directive (never attempt a real
   signed build with placeholders); can be relaxed to Firebase-token-only once
   real signing exists (contract change would need §3.3 + opt-008 updates).
6. **Unchanged from M-15/M-17:** category-file status flips are D-03's;
   `run_all_backend.sh` header member list cosmetic.

## Sources consulted

- Repo: `fastlane/Fastfile` + `fastlane/README.md` + `fastlane/Appfile` (M-17's
  iOS shape — the guard/helper/lane pattern reused), `Gemfile` (M-19 handoff),
  `Makefile` (M-15 stub contract — the lane-name pins), `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`
  (§3.3 Android placeholder table = the contract, §6 R22-R24, §3.2, §7),
  `test/opt-008-makefile-static.sh` (§2b M-17 block — extended), `android/app/build.gradle.kts`
  (namespace/applicationId `com.qallariy.samay`, minSdk `flutter.minSdkVersion`,
  release buildType signs with the DEBUG key at line 37), `docs/history/…/2026-08-10_M17-fastlane-ios.md`
  (log/lock/report format + guard rationale), `docs/to-fix/categories/14-MAKEFILE-CICD.md`
  (MKE-05/MKE-10 context), `tools/check_secrets.sh` (P1-P6 — new literals stay
  clear), AGENTS.md, `docs/process/{AGENT-RULES,FILE-OWNERSHIP}.md`.
- Juega (read-only): `/Users/daerean/Codes/apps/Juega/fastlane/Fastfile` — Android
  lane shape reference (firebase_app_distribution / supply patterns); no secrets
  copied.
- fastlane docs — `firebase_app_distribution` (`apk_path`, `firebase_cli_token`,
  `groups`): <https://docs.fastlane.tools/actions/firebase_app_distribution/>
- fastlane docs — `supply` (`track`, `aab`, `json_key`, skip flags):
  <https://docs.fastlane.tools/actions/supply/>
- fastlane docs — lanes/platforms: <https://docs.fastlane.tools/advanced/lanes/>
- Ruby — `ruby -c` parse-only semantics: <https://docs.ruby-lang.org/en/master/Ruby.html>
