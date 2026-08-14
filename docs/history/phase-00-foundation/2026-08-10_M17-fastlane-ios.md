# 2026-08-10 — M-17: fastlane iOS scaffold — Fastfile lanes, Appfile, Gemfile, README, gate

**Agent:** M-17 (Phase 4.3 — fastlane track, iOS + Gemfile; sole agent this run)
**Role:** (1) `Gemfile` (fastlane + cocoapods, MKE-10 — lockfile deferred to M-19);
(2) `fastlane/Appfile` (app_identifier / team_id / apple_id placeholders);
(3) `fastlane/Fastfile` — `platform :ios` with `beta_testflight` +
`release_appstore` per the M-15 lane-name contract (DEPLOYMENT-PLACEHOLDER.md
§3.3), fail-fast placeholder guard, Match referenced via env; (4) `fastlane/README.md`
(usage, placeholder-contract table, credentials checklist); (5) `test/opt-008-makefile-static.sh`
§2b extension (lane/Appfile/Gemfile assertions + no-real-credential-shape scan);
(6) `.gitignore` (`fastlane/keys/`); (7) daily log + TODO.md + categories +
DEPLOYMENT-PLACEHOLDER.md updates (MKE-05/MKE-10, §6 R20/R21).
**Campaign:** Samay 180-agent orchestration; Juega untouched (read-only reference),
NO commits, NO bundle/fastlane runs, NO network ops — verification is parse-only
(`ruby -c`) + the static gate + `make -n` dry-run.

---

## What was built

### 1. `Gemfile` (new — mission lock list; FILE-OWNERSHIP row says M-19, mission overrides)

- Juega pattern verbatim: `source "https://rubygems.org"`, `ruby ">= 3.0"`,
  `gem "fastlane"`, `gem "cocoapods"` (MKE-10).
- Header comment documents: `make bundle-install` is the gate; **Gemfile.lock is
  intentionally NOT created/committed** — generating it requires `bundle install`
  (network + gem resolution), which this track deliberately does not run; M-19
  commits the lockfile after the first real `bundle install` (MKE-10 fix contract).

### 2. `fastlane/Appfile` (new)

- `app_identifier("com.qallariy.samay")` — verified in
  `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`, 4 configs).
- `team_id(ENV.fetch("TEAM_ID", "XXXXXXXXXX"))` — §3.3 placeholder, matches the
  pbxproj `DEVELOPMENT_TEAM = XXXXXXXXXX` (verified, all Runner configs Manual).
- `apple_id(ENV.fetch("APPLE_ID", "CHANGE_ME"))` — §3.3 placeholder (`apple_id` is a
  valid Appfile DSL method, verified against the fastlane docs).
- All values env-read; the Fastfile guard aborts until the placeholders are real.

### 3. `fastlane/Fastfile` (new)

- `default_platform(:ios)` + `platform :ios do` with exactly the two contract lanes:
  - `beta_testflight` — export method default `ad-hoc` (§3.3 contract), build →
    `upload_to_testflight(api_key:, ipa:)` via the App Store Connect API key.
  - `release_appstore` — export method default `app-store`, build →
    `deliver(api_key:, ipa:, skip_metadata:, skip_screenshots:, force:)`.
- **Fail-fast guard** `assert_credentials_configured!`: every credential env var must
  be set AND differ from its §3.3 placeholder (`AAAAAAAAAA`,
  `00000000-0000-0000-0000-000000000000`, `fastlane/keys/AppStoreConnect_AAAAAAAAAA.p8`,
  `git@github.com:samay-app/samay-match.git`, `CHANGE_ME`, `XXXXXXXXXX`), and the .p8
  file must exist once the path is real — otherwise
  `UI.user_error!("credentials not configured (placeholders): …")`. This makes an
  accidental placeholder-lane run impossible.
- `export_method_for(default)` validates `$IOS_EXPORT_METHOD` against the §3.3 enum
  (`app-store`/`ad-hoc`/`development`/`enterprise`).
- **Match** `ensure_matching_signing(export_method, api_key)`: `match(git_url:
  ENV["MATCH_GIT_URL"], type: <mapped>, app_store_connect_api_key:, readonly: false)`
  — referenced per §3.3 but provably unreachable while placeholders are set
  (documented-not-executed). Export-method → match-type mapping: `app-store → appstore`,
  `ad-hoc → adhoc`.
- `build_ios_ipa(export_method)` runs `flutter build ipa --release --export-method <m>`
  with `SUPABASE_URL`/`SUPABASE_ANON_KEY` dart-define passthrough (M-13/M-21 contract;
  unset vars are simply not passed) and discovers the single IPA under
  `build/ios/ipa/`.
- Constants + methods only at top level (no executable fastlane code) — parse-safe.

### 4. `fastlane/README.md` (new)

- Make-target ↔ exact-command ↔ lane table (`make ios-beta` / `make ios-release`).
- The §3.3 placeholder-contract table (env var, placeholder value, used-by).
- Fail-fast guard explanation; "Credentials to fill before real use" checklist
  referencing DEPLOYMENT-PLACEHOLDER.md §3.4/§6 R20-R21.
- Signing/Match notes: pbxproj `CODE_SIGN_STYLE = Manual`, `DEVELOPMENT_TEAM =
  XXXXXXXXXX` placeholder, empty `PROVISIONING_PROFILE_SPECIFIER` — Match manages
  certs/profiles once real.

### 5. `.gitignore` (new entry — outside the mission lock list but directly serving it)

- `fastlane/keys/` ignored — the §3.3 .p8 path stays path-only; real `.p8` files
  (future `fastlane/keys/AppStoreConnect_<KEY_ID>.p8`) can never be committed.

### 6. `test/opt-008-makefile-static.sh` — §2b (extended; §2 LIVE probes auto-skip)

New §2b asserts: Fastfile declares `platform :ios` + both `lane :beta_testflight` /
`lane :release_appstore` + the "credentials not configured" guard literal; Appfile
carries `com.qallariy.samay` + `XXXXXXXXXX`; Gemfile declares `gem "fastlane"` +
`gem "cocoapods"`; `fastlane/` contains NO private-key material (`-----BEGIN` /
`BEGIN … PRIVATE KEY`), NO Apple app-specific-password shape (`[a-z]{4}-` ×4);
`fastlane/keys/AppStoreConnect_AAAAAAAAAA.p8` does NOT exist; §3.3 placeholder
literals pinned (`AAAAAAAAAA`, the Match repo URL, `CHANGE_ME`). Header NOTE
extended for M-17.

### 7. Docs (locked per mission)

- `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`: header "Last verified" → M-17; §3 intro
  (fastlane/ + Gemfile exist now, `.github/` still pending); §3.3 M-17 LANDED block;
  §6 R20/R21 flipped ✅ (placeholders wired; replacement stays a release-time ops
  action); §7 M-17 verification addendum.
- `docs/to-fix/categories/14-MAKEFILE-CICD.md`: MKE-05 (iOS lanes landed; AltServer
  stays dev-only until real creds) + MKE-10 (Gemfile landed; `Gemfile.lock` → M-19).
- `docs/to-fix/TODO.md`: M-17 workstream block (newest-first, M-15 precedent).

---

## Decisions made and why

- **Fail-fast guard compares against the §3.3 placeholder values themselves**
  (not just presence): a dev who exports the placeholder literals must get the same
  hard error as a missing var — the guard's message is the documented contract
  ("credentials not configured (placeholders)").
- **Match is referenced but guarded:** §3.3 says "documented, not executed". The
  guard runs BEFORE the match call in both lanes, so with placeholder env the lane
  aborts before Match can even be reached — the placeholder repo URL can never be
  touched.
- **`beta_testflight` defaults to `ad-hoc`** — unusual for TestFlight, but it is the
  §3.3 contract ("ad-hoc (internal)") and the mission repeats it; `$IOS_EXPORT_METHOD`
  override is accepted (full enum), documented in README for the real first upload.
- **dart-define passthrough in `build_ios_ipa`:** the app reads `SUPABASE_URL` /
  `SUPABASE_ANON_KEY` via `const String.fromEnvironment` (I-34) — a lane-built IPA
  without them would fail at startup (by design). Unset vars are skipped, matching
  the define-free-dev convention.
- **`Gemfile.lock` NOT committed (documented):** generating it requires
  `bundle install` (network). M-19's mission is to commit the lockfile; the Gemfile
  comment + TODO.md + README all say so — no ambiguity about the handoff.
- **`ruby -c` is a valid syntax gate:** it parses without executing, so fastlane's
  own loader (`require "fastlane"` never appears in these files anyway) and the
  `UI`/action constants inside method bodies are irrelevant to the parse. Full
  fastlane-run verification remains blocked on real credentials (by design).

## MISTAKE / gotcha

- **Gotcha (checked, not hit):** opt-008 §2b's app-specific-password regex
  `[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}` must not false-positive on the §3.3 issuer-ID
  placeholder (`00000000-0000-…` is digits-only — safe) or `git@github.com:…`
  (no 4-4-4-4 group). Verified with the actual files before landing the gate.
- **Gotcha (documented):** `match` `type:` uses `appstore`/`adhoc` (fastlane match
  vocabulary), while `flutter build ipa --export-method` uses `app-store`/`ad-hoc`
  and §3.3 uses `app-store`/`ad-hoc` — the mapping helper bridges them; a future dev
  must not pass an export method straight into `match(type:)`.
- **Gotcha (repo state):** `make ios-beta` LIVE now passes both stub gates
  (Fastfile exists + lane grep) and would run `bundle exec fastlane` → bundler error
  (no gems/lockfile). That is the M-15-designed progression (each blocker has its own
  clear message); opt-008's LIVE probes auto-skip, and `make -n` always resolves.

## Commands run (reproducibility)

```bash
export AGENT_NAME="M-17-fastlane-ios"
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME" --timeout 300   # ×10 files (list below)
tools/agent_lock.sh list                     # 10 locks held by M-17-fastlane-ios

# Syntax (parse-only — never executes, no bundler/fastlane/network):
ruby -c fastlane/Fastfile                    # Syntax OK
ruby -c fastlane/Appfile                     # Syntax OK
ruby -c Gemfile                              # Syntax OK

# Static gate (extended)
bash test/opt-008-makefile-static.sh         # exit 0 — §2b green (lanes/Appfile/Gemfile/credential-scan)

# Make contract dry-runs
make -n ios-beta                             # resolves: bundle exec fastlane ios beta_testflight
make -n ios-release                          # resolves: bundle exec fastlane ios release_appstore

# Secrets gate (untracked files are not scanned today; literals match no P1-P6 pattern)
make secrets-check                           # PASS (unchanged)

tools/agent_lock.sh release <path> --owner "$AGENT_NAME"                  # ×10, all released
```

## Verification

- [x] `ruby -c fastlane/Fastfile` → **Syntax OK**; `ruby -c fastlane/Appfile` →
      Syntax OK; `ruby -c Gemfile` → Syntax OK. Method: parse-only syntax check —
      `ruby -c` does not execute the file, so fastlane's loader is not involved and
      no bundler/network/credentials are needed. This is the pragmatic equivalent of
      fastlane's own parse step without installing anything.
- [x] `bash test/opt-008-makefile-static.sh` → **exit 0**: §1 `make -n` resolves all
      45 targets; §2 stub contract (unchanged) with LIVE probes auto-skipped; **§2b
      green** (2 lanes + platform :ios + guard literal, Appfile id/team, Gemfile
      fastlane+cocoapods, zero private-key material, zero app-specific-password
      shapes, ASC key file absent, placeholder literals pinned); §3 migrate-check
      RED/GREEN probes; §4 deploy placeholders; §5 `bash -n` self.
- [x] `make -n ios-beta ios-release` resolve to `bundle exec fastlane ios
      beta_testflight` / `… release_appstore`.
- [x] `make secrets-check` PASS — the new files' placeholder literals hit no P1-P6
      pattern (`sb_publishable_*`/`sb_service_role`/`sb_secret_*`/`your_supabase`/
      `APPLE_PASSWORD=`); `fastlane/keys/` is gitignored; `.p8` never created.
- [x] `bundle exec fastlane` / `bundle install` NOT run (no network, no credentials —
      AGENT-RULES §0.3; the fail-fast guard exists precisely so that state is safe).
- [x] Lock evidence: 10 files acquired + released by `M-17-fastlane-ios`.
- [x] No commits; no `git add`; Juega untouched (read-only); no containers; no
      network ops.

## Lock list (acquire → release, owner `M-17-fastlane-ios`)

1. `Gemfile` — new
2. `fastlane/Fastfile` — new
3. `fastlane/Appfile` — new
4. `fastlane/README.md` — new
5. `test/opt-008-makefile-static.sh` — §2b extension
6. `docs/to-fix/TODO.md` — M-17 workstream block
7. `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` — header, §3 note, §3.3 block, R20/R21, §7
8. `docs/to-fix/categories/14-MAKEFILE-CICD.md` — MKE-05/MKE-10 statuses
9. `docs/history/phase-00-foundation/2026-08-10_M17-fastlane-ios.md` — this log
10. `.gitignore` — `fastlane/keys/` (mission-adjacent: the .p8 path-only contract)

## Issues found / handoffs (reported, NOT fixed — out of scope)

1. **Handoff M-19:** commit `Gemfile.lock` after the first real `bundle install`
   (`make bundle-install`) — the Gemfile, TODO.md, and README all document this.
   NOTE: FILE-OWNERSHIP.md rows for M-17 (`fastlane/Fastfile`+`Appfile`) and M-19
   (`Gemfile` + `fastlane/README.md`) are now stale — the mission assigned
   `Gemfile` + `fastlane/README.md` to M-17; M-19's remaining deliverable is the
   lockfile. Orchestrator should refresh the ownership map.
2. **Handoff M-18 (Android):** implement `platform :android` + `lane :alpha_firebase`
   / `lane :release_play` in the same file — the Makefile stub greps and opt-008 §2
   pin those names; the file is already guarded by opt-008 §2b's credential scan.
   Reuse the `assert_credentials_configured!` shape with the §3.3 Android
   placeholders (keystore path/alias/passwords, `FIREBASE_API_TOKEN`,
   `PLAY_SERVICE_ACCOUNT_JSON`).
3. **Handoff (release-time ops, §6 R20/R21):** the first real TestFlight run needs
   the ASC `.p8` (downloaded, not committed), the Match repo + password, the real
   team ID in env AND in the pbxproj `DEVELOPMENT_TEAM` (currently `XXXXXXXXXX`),
   and `APPLE_ID` — see fastlane/README.md checklist.
4. **Flagged (not a bug):** `beta_testflight`'s contract-default export method is
   `ad-hoc`; Apple's TestFlight normally expects `app-store`-exported IPAs. The lane
   accepts `IOS_EXPORT_METHOD=app-store` for the real first upload — contract allows
   the full enum. Not changed: the §3.3 table is the contract.
5. **Flagged (M-15 handoff #5 unchanged):** `run_all_backend.sh`'s header lists only
   opt-001..006 — opt-007/008 (and now §2b) are auto-discovered members; cosmetic,
   D-05/I-01 re-verification scope.

## Sources consulted

- Repo: `Makefile` (M-15 stub targets + lane-name contract), `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`
  (§3.3 placeholder table = the M-17 contract, §6 R20/R21, §3.4 checklist),
  `docs/to-fix/categories/14-MAKEFILE-CICD.md` (MKE-05/MKE-10), `docs/process/{AGENT-RULES,FILE-OWNERSHIP}.md`,
  `ios/Runner.xcodeproj/project.pbxproj` (bundle id `com.qallariy.samay`,
  `CODE_SIGN_STYLE = Manual`, `DEVELOPMENT_TEAM = XXXXXXXXXX`),
  `test/opt-008-makefile-static.sh` (§2/§3 RED-probe patterns), `docs/history/…/2026-08-10_M15-makefile-final.md`
  (log/lock/report format), `tools/check_secrets.sh` (P1-P6 patterns — new files must
  stay clear), `.env.example` (env conventions).
- Juega (read-only): `/Users/daerean/Codes/apps/Juega/fastlane/{Fastfile,Appfile}` +
  `Gemfile` — structure + `app_store_connect_api_key(...)` call shape; no secrets
  copied.
- fastlane docs — Appfile DSL (`apple_id`, `team_id`, `app_identifier`):
  <https://docs.fastlane.tools/advanced/Appfile/>
- fastlane docs — `app_store_connect_api_key`, `upload_to_testflight` (pilot), `deliver`,
  `match` (`type:` vocabulary): <https://docs.fastlane.tools/actions/upload_to_testflight/>,
  <https://docs.fastlane.tools/actions/deliver/>, <https://docs.fastlane.tools/actions/match/>
- Ruby — `ruby -c` parse-only semantics: <https://docs.ruby-lang.org/en/master/Ruby.html>
