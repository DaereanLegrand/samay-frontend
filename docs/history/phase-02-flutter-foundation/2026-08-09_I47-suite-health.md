# 2026-08-09 — I-47: Suite health — last mile (TST-10 follow-up, port hygiene, isolation proof)

**Agent:** I-47 (suite-health) | **Role:** final suite-health audit + fixes — flake/slow/fragile
sweep, hermeticity verification, port-map hygiene, isolation proof | **Phase:** 02-flutter-foundation
(campaign sub-phase 4.2, post-EF-04) | **Status:** DONE

## Assignment

1. Audit for ANY flaky / slow (>10s) / fragile test: run the full suite TWICE and compare;
   investigate + fix everything found (fixed sleeps → poll-based waits; shared state → isolation;
   timeouts → bounded).
2. `test/features/auth_screens_test.dart` — verify fully hermetic; its local router used unsafe
   `state.extra as Map<String, dynamic>` casts pre-I-03 → use RouteExtras-style safe paths.
3. `test/router/app_router_test.dart` `url: 'http://localhost:54321'` → `http://127.0.0.1:54386`
   (approved Kong port); `tools/check_ports.sh --strict` must exit 0.
4. Any `debugPrint` in tests → keep; any `print(` in `lib/` → ensure zero.
5. `flutter test --concurrency=1` green (isolation proof).
6. Daily log + TODO.md (H-18 partial full-suite-green note; L-13 already ✅ EF-01).

## Plan → execution

1. **READ** — entire repo per AGENT-RULES §0: all of `lib/` (117 dart files), `test/` (60 files),
   `integration_test/` (4 flows + support/), `docs/` (planification/implementation/development/
   to-fix/agents), `pubspec.yaml`, `AGENTS.md`, Makefile, scripts. Prior daily logs (I-09, I-01,
   EF-01..EF-04, I-03).
2. **Baseline** — full suite ×2 BEFORE any edit: **764/764 pass each** (21 s / 18 s), 0 flakes,
   no per-file runtime > 10 s (per-directory timing: crypto 5.1 s, services 5.9 s, widgets 6.5 s,
   features 6.6 s — all well under the bar).
3. **RED** — `tools/check_ports.sh --strict` → **5 violations** (`localhost:54321` in 5 test
   files); `test/router/app_router_test.dart` chat assertions found stale mid-campaign (see
   Findings F-1).
4. **GREEN** — all fixes below.
5. **VALIDATE** — full suite ×2 (**951/951** each), `--concurrency=1` (**951/951**),
   `check_ports.sh --strict` exit 0, `rg "print\(" lib/` = 0, `flutter analyze` clean on all
   touched files.
6. **DOCUMENT** — this log + TODO.md.

## What was built / fixed

### 1. Port-map hygiene (5 test files) — `localhost:54321` → `127.0.0.1:54386`

All five remaining test-only `Supabase.initialize` calls referenced Juega's port 54321 — which,
per AGENTS.md, Juega's **live** stack owns (some tests' fail-closed paths were actually probing a
foreign running server). Changed to the approved Samay Kong port (never contacted — the storages
are in-memory fakes; fail-closed paths behave identically against a refused connection):

| File | Line |
|---|---|
| `test/router/app_router_test.dart` | 136 |
| `test/services/supabase_service_test.dart` | 84 |
| `test/features/profile_screens_test.dart` | 58 |
| `test/features/profile/avatar_flow_test.dart` | 77 |
| `test/providers/profile_providers_test.dart` | 49 |

The `integration_test/support/*` harness already used `127.0.0.1:54386` (I-01).

### 2. `tools/check_ports.sh` — raw-string-literal allowance (test-URL false positives)

After the URL fixes, `--strict` still failed on **one** violation: `test/meta/conventions_test.dart`
(I-48's in-flight meta-test) embeds a Dart **regex literal** `r'localhost:54321|localhost:5432(?!\d)'`
as a banned-port assertion; the awk scanner read `localhost:5432` out of it as a real reference.
Per my LOCK LIST ("only if its regex needs the test-URL allowance") I extended
`scan_references`'s awk pass: **Dart raw-string literals (`r'...'` / `r"..."`) are masked before
quote-stripping** — regex assertions about ports are never port references. Verified:
`--strict` exit 0 (mappings 19 · references 142 · OK 58 · INFO 109 · **VIOLATIONS 0**); I-48's
meta-test itself passes 5/5 (it also scans `tools/` and had flagged my own comment until
reworded without a Juega port literal).

### 3. `test/features/auth_screens_test.dart` — hermetic + RouteExtras-safe harness

- Local router rebuilt: every `state.extra as Map<String, dynamic>` / `as String?` cast replaced
  with the typed factories (`VerifyExtra.fromState`, `PrivacyTermsExtra.fromState`,
  `ProfileSetupExtra.fromState`, `AgeGateExtra.fromState`); null extras render
  `RouteErrorScreen` (same contract as the real `app_router.dart`, I-03 / NAV-04 / H-04).
- Added 2 regression tests: legacy-map extras still reach the screens through `RouteExtras`
  (hermetic navigation proof), and missing extras render `RouteErrorScreen` — never crash.
- File now imports `route_extras.dart` + `route_error_screen.dart`.

### 4. `test/router/app_router_test.dart` — stale chat assertions (mid-campaign product change)

While verifying under `--concurrency=1`, the two `/chat/...` tests failed: **I-38/I-56's E2EE
chat landed in the shared tree mid-run** (`lib/features/chat/` untracked, `app_router.dart`
rewired `/chat/:chatId` → real `ChatScreen(chatId: chatId)` instead of `VComingSoonScreen`),
so the coming-soon assertions went stale. Updated to the current contract:
- removed `/chat/...` from the coming-soon loop;
- new test: `/chat/<id> renders ChatScreen` (and asserts NOT VComingSoonScreen);
- `RoutePaths coherence` list: `(chat, VComingSoonScreen)` → `(chat, ChatScreen)`.
62/62 green in the file.

### 5. Flake/slow audit results

- **2× consecutive full runs pre-change: 764/764, no flakes.** Per-directory timings all
  < 7 s; no test file approaches the 10 s bar (the only 20 s timeout is the deliberate
  EF-04 regression guard on the hive lost-key test, which completes in ~2 s).
- Remaining fixed `Future.delayed(300 ms)` in `v_network_image_test.dart` is load-safe by
  design (EF-04 split the decode path into its own poll-based file; the 11 tests here only
  exercise placeholder/error states against the deterministic test HttpClient).
- `--concurrency=1` initially exposed 2 app_router chat failures — root cause was F-1
  (stale assertions), not concurrency; fixed and re-proven green.
- I-44's in-flight files (config_provider/user_provider/realtime_service tests) failed during
  runs 3–4 (locks held, mid-edit); realtime tests passed 7/7 alone and I-44's later iteration
  fixed them — **NOT touched** (semaphore; other agents' work), consistent with the EF-04
  precedent. Full suite went green (951/951) once their edits settled.

## Files created / modified (lock evidence — all via `tools/agent_lock.sh`)

| File | Action | Lock |
|---|---|---|
| `test/router/app_router_test.dart` | port URL + chat-route assertions updated, ChatScreen test added | acquire 2026-08-09T21:31:18Z → held until release |
| `test/services/supabase_service_test.dart` | port URL | acquire 21:31:18Z → release |
| `test/features/profile_screens_test.dart` | port URL | acquire 21:31:19Z → release |
| `test/features/profile/avatar_flow_test.dart` | port URL | acquire 21:31:19Z → release |
| `test/providers/profile_providers_test.dart` | port URL | acquire 21:31:19Z → release |
| `test/features/auth_screens_test.dart` | RouteExtras-safe harness + 2 tests | acquire 21:31:19Z → release |
| `tools/check_ports.sh` | raw-string-literal allowance in awk scan | acquire → release |
| `docs/to-fix/TODO.md` | H-18 partial note (see below) | acquire (blocked by I-44; retried) → release |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I47-suite-health.md` | created (this log) | acquire → release |

`tools/agent_lock.sh list` post-release: no locks held by I-47-suite-health.

## Tests added + results

| Command | Result |
|---|---|
| `flutter test` (baseline, pre-edit) ×2 | **764/764 pass each** |
| `flutter test` × 2 (post-edit, final) | **951/951 pass each** (exit 0) |
| `flutter test --concurrency=1` | **951/951 pass** (exit 0) |
| `tools/check_ports.sh --strict` | **STRICT PASS** — 0 violations (exit 0) |
| `flutter test test/router/app_router_test.dart` | 62/62 |
| `flutter test` 6 edited files | 108/108 |
| `flutter analyze` on all touched files | No issues found |
| `rg "print\(" lib/` | **0 hits** (only `debugPrint` fallback inside `app_logger.dart`, by design) |
| `rg "localhost:54321" test/ integration_test/` | **0 hits** |

## MISTAKE / gotcha

- **MISTAKE (self):** my first `tools/check_ports.sh` awk comment contained apostrophes
  (`r'...'`) — inside the shell single-quoted awk program this terminated the string early and
  produced `awk: syntax error` with 0 references scanned. Caught by the summary counters
  (references dropped 146 → 0), fixed by rephrasing the comment with no quote chars. Lesson:
  `bash -n` does NOT validate the embedded awk program — always diff the summary counters.
- **MISTAKE (self):** the ChatScreen test insertion initially unbalanced the group braces
  (chat test landed outside `coming soon routes`, leaving an extra `});` at EOF) — analyzer
  flagged `expected_executable` at EOF; fixed by re-nesting.
- **Gotcha:** `flutter analyze` on a single file still prints the Swift Package Manager plugin
  notices (not errors).
- **Gotcha:** the shared tree is LIVE during the campaign — two consecutive green runs do not
  freeze the suite; other agents' locks (I-38 chat, I-44 mocktail tests, I-45/I-46) landed new
  files between my runs (764 → 951 tests). Every failure seen outside my files traced to
  mid-edit states of locked files.

## Issues found / reported (not fixed — out of scope or other agents')

- I-44's in-flight failures (config_provider/user_provider invalidation & stubbing, realtime
  channel tests) during runs 3–4 — resolved by I-44's own iteration; do not regress.
- I-48's `test/meta/conventions_test.dart` ships a Juega-port-banning regex literal that
  `check_ports.sh` now masks (this log) — no action needed on I-48's side.
- The E2EE chat router wiring (ChatScreen for `/chat/:chatId`) is uncommitted I-38/I-56 work;
  `test/router/app_router_test.dart` was updated to match. If I-38 changes `ChatScreen`'s
  constructor signature, re-verify the two chat router tests.
- `docs/to-fix/categories/04-TESTING.md` TST-09/TST-10 statuses still stale (D-03/V-02 owned) —
  flagged in EF-01 as well.

## TODO.md updates (applied on final lock pass)

- **H-18** (zero error-state tests) — ❌ → 🔄 partial: full suite green **951/951 ×2 + concurrency=1**
  (I-47, 2026-08-09; port hygiene + hermetic harness + stale-assertion sweep; error-state
  coverage continues with I-44/I-45).
- **L-13** (structure_test brittle) — already ✅ (EF-01); no change.

## Sources consulted

- supabase_flutter 2.12.4 source (`supabase.dart` — assert-guarded `instance` getter).
- Riverpod 2.6.1 source (invalidation semantics — for understanding I-44's failing test).
- Flutter `flutter test --concurrency` docs.
- I-01/I-03/I-09/EF-01/EF-04 daily logs (harness + RouteExtras + stability precedents).

---

## RESUME addendum (2026-08-09, run 2 — session cancelled mid-flight, work committed in `f4b221f`)

**Context:** my first session was cancelled while the checkpoint commit `f4b221f` was
being assembled; the orchestrator relaunched me (I-47, resume) to complete and verify
the remaining suite-health items. My committed partial work: `test/router/app_router_test.dart`
(port URL + chat-route assertions + ChatScreen test), `test/features/auth_screens_test.dart`
(RouteExtras-safe harness + 2 regression tests), `tools/check_ports.sh` (raw-string-literal
allowance), `docs/history/phase-02-flutter-foundation/2026-08-09_I47-suite-health.md`
(this log), and 4 sibling test files' port URLs (supabase_service/profile_screens/avatar_flow/
profile_providers tests).

### What I verified on resume (2026-08-09, all green)

| Item | Result |
|---|---|
| `test/router/app_router_test.dart` `setUpAll` URL | ✅ already `http://127.0.0.1:54386` (partial work landed) — no `localhost:54321` anywhere in `test/`/`integration_test/` |
| `tools/check_ports.sh --strict` | ✅ **STRICT PASS** — exit 0 · mappings 19 · references 142 · OK 58 · INFO 109 · **VIOLATIONS 0** (script classification already correct: test-only `127.0.0.1:54386` refs are OK; I-48's banned-port regex literal masked as raw-string; compose/config.toml remap verified landed — I-02's `54382:5432`/`54386:8000`/`54443:8443` mappings all report OK) |
| Full suite run 1 | ✅ **951/951** (00:22) — pre-I-46 tree state |
| Full suite run 2 | ✅ **951/951** (00:28) — pre-I-46 tree state |
| `flutter test --concurrency=1` | ✅ **951/951** (01:21) — pre-I-46 tree state |
| Full suite run 3 (I-46's 46 algorithm tests landed mid-session) | ✅ **997/997** (00:19) |
| Full suite run 4 | ✅ **997/997** (00:20) |
| `flutter test --concurrency=1` (final tree state) | ✅ **997/997** (01:24) |
| `flutter analyze` | ✅ No issues found |
| `rg "print\(" lib/` | ✅ 0 (word-bounded `\bprint\s*\(` = 0; only `computeFingerprint()` method name matched the loose literal — not a call) |
| `rg "debugPrint" lib/` | ✅ only `lib/core/logging/app_logger.dart` (by design) |
| `state.extra as Map<String,dynamic>` in test harnesses | ✅ 0 remaining — `test/features/auth_screens_test.dart` uses the typed `RouteExtra.fromState` factories; the only `as Map<String, dynamic>` hits in `test/crypto/*` are `jsonDecode` results (data, not router extras); the `auth_screens_test.dart` mention is a doc comment |
| Flake/slow audit | ✅ no fixed-sleep flakes found — the only real-time wait is the documented load-safe 300 ms in `v_network_image_test.dart` (EF-04 split the decode path into its own poll-based file); remaining `tester.pump(Duration(...))` calls are fake-clock advances (deterministic); the 20 s `Timeout` in `storage_service_test.dart` is the deliberate EF-04 hive lost-key guard (completes in ~2 s) |

### TODO.md H-18 (locked this session)

The H-18 row now carries the suite-health milestone: full suite **951/951 ×2 +
--concurrency=1**, `check_ports.sh --strict` exit 0, port hygiene, hermetic harness,
stale-assertion sweep (I-47, 2026-08-09) appended after I-44's error-state closure.

### MISTAKE / gotcha (resume run)

- **Gotcha:** `rg "print\(" lib/` matched `computeFingerprint()` (a method *name*) — the
  literal grep is not word-bounded. The authoritative guard is I-48's
  `test/meta/conventions_test.dart` (`\bprint\s*\(`), which passes 5/5; documented here so
  no future agent "fixes" a non-issue by renaming the crypto method.
- **Gotcha:** the checkpoint commit `f4b221f` had already flipped H-18 to ✅ (I-44) in
  TODO.md; my original H-18 edit was overwritten by the commit assembly. Re-applied the
  I-47 milestone as an additive suffix to I-44's row (not a status flip).

### Issues found / reported (not fixed — out of scope)

- I-46's algorithm suite (age_policy, password_policy, otp_format, shard_math, rank_bracket —
  46 tests) landed in the tree mid-resume (untracked, locks held by I-46 at 17:11–17:12).
  The suite re-verified green WITH them: 997/997 ×2 + concurrency=1. No interaction with
  my files; nothing to fix on my side.
- None new. The suite is stable 997/997 across consecutive runs (2× full + 1×
  concurrency=1 at the final tree state), 0 flakes observed. Prior issues (I-44 mid-edit
  transient failures, I-38 ChatScreen constructor coupling) remain as recorded above.
