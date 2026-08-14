# 2026-08-13 — Fix: "Error Unauthorized" on login/signup + stack boot + no-fallback policy

## Context

On a new install, logging in with `tester@tester.com` / `tester123` bounced the
user from "Iniciar Sesión" to "Crear cuenta", and entering the credentials there
popped an "Error Unauthorized" dialog. Reproduced on simulator AND physical
device.

## Root cause (verified empirically with curl against both stacks)

1. **Stale anon key in the app build.** Every Flutter build baked
   `SUPABASE_ANON_KEY=sb_publishable_ACJ…` from the repo-root `.env` (an opaque
   publishable key, historical leftover). PostgREST **only validates legacy
   HS256 JWTs signed with the stack's `JWT_SECRET`** — the publishable key is
   not a JWT, so every `/rest/v1/` call (RPC + table queries) returned
   **401 Unauthorized** on BOTH the local testing stack and remote prod.
   GoTrue + Kong accepted the key, which is exactly why the failure was
   confusing:
   - `signIn` succeeded (GoTrue) → `AuthService.userHasProfile()` swallowed the
     PostgREST 401 and returned `false` → `AuthGuard` redirected the
     authenticated user to `/auth/signup` ("Crear cuenta").
   - On signup, `checkEmail` swallowed the 401 (→ `'signup'`), `sendOtp`
     (GoTrue) succeeded, then `upsert_signup_tracker` RPC 401'd → thrown →
     popup "Error" + "Sesión expirada. Inicia sesión de nuevo." (Unauthorized).
   - The working key (used by `supabase/.env`, feeds Kong `$ANON_KEY`) is the
     legacy JWT `eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJyb2xlIjogImFub24i…`.
   This limitation was already documented in the 2026-08-11 clean-boot log §9.

2. **Local prod stack would not boot.** `samay-db` and `samay-functions` came
   up with NO network endpoint attached (`NetworkMode=samay_default` but zero
   live endpoints) — the db healthcheck is localhost-only, so it passed anyway.
   Every dependent service crash-looped with `lookup samay-db: no such host`.

3. **Local prod DB missing 3 migrations** (`20260809000005` qr_validate_rpc,
   `20260809000006` minigame_rpc, `20260812000001` upsert_signup_tracker) —
   the volume predates them; `make supabase-start` does not run `migrate.sh`.

## What was done

### Infra / keys
- Root `.env`, `supabase/.env.local`, `supabase-testing/.env.local`,
  `test/run_all_backend.sh`: `SUPABASE_ANON_KEY` → the legacy JWT (same value
  the stacks' Kong already uses). Verified: login (GoTrue 200), `users` query
  with the session (200, RLS row visible), `check_signup_email` → `"exists"`,
  `upsert_signup_tracker` (204), all against Kong with the legacy key.
- Local prod stack: `docker network connect samay_default samay-db
  samay-functions` + `docker compose up -d --force-recreate db kong`
  (compose service aliases like `db` are only registered by compose, not by a
  manual connect) → all 10 containers healthy.
- Applied the 3 missing migrations to the local prod DB (all idempotent
  `CREATE OR REPLACE`).
- Backend opt-suite: **8/8 passed** (was 7/8 — opt-001 failed on the missing
  `upsert_signup_tracker`).

### App (no-fallback policy — user directive)
> "By no circumstance must clicking in one thing take you to another that was
> not explicitly stated… such fallbacks must never exist."

- `AuthGuard`: deleted the `!hasProfile → /auth/signup` redirect. Guard now
  only: banned → ban screen, unauthenticated → login, authenticated on
  login/welcome → feed.
- `AuthService.userHasProfile`: no longer swallows errors → propagates (absent
  row still returns false).
- `AuthNotifier.checkEmail`: no longer swallows errors → propagates.
- `AuthNotifier`: listener/initial-restore paths use `_authStateForUserSafe`
  (log + stay put; never navigate, never sign out). Explicit paths
  (`signIn`/`verifyOtp`) surface the error via `AsyncError` → the screen popup.
- Signup "already registered" dialog: added an explicitly labeled
  "Iniciar sesión" action → `/login` (the only navigation off the dialog).
- Error popups now carry a code: every `AppError` subtype has a stable `code`
  (`NETWORK_ERROR`, `AUTH_UNAUTHORIZED`, `SERVER_ERROR`, `VALIDATION_ERROR`,
  `PERMISSION_DENIED`, `RATE_LIMITED`, `NOT_FOUND`, `NOT_CONFIGURED`);
  `showAppError` renders "message + Código de error: <code>" in the dialog and
  snackbar (new l10n key `errorCodeLabel`).
- Logging: `AppLogger` is a complete no-op in release builds (`enabled`
  constructor opt-out, `enabled ?? !kReleaseMode`; `log()` + `markCrash()`
  early-return when disabled) — logs are testing/debug-only.

### Environment note (testing vs prod)
- The tester account lives on the **testing stack** and **remote prod**.
  On the **local prod stack** the account does NOT exist (fresh DB volume).
- Remote prod: password no longer matches `tester123` (a recovery email was
  sent 2026-08-13T14:30Z and the password was changed afterwards — login now
  returns `invalid_credentials`, a CORRECT and clear response).
- Verified end-to-end on the testing stack: login → 200, `users` row via the
  session → 200 (so the app goes straight to the feed — no bounce).

## Verification

- `flutter analyze` — 0 issues.
- `flutter test` — **2161 passed, 0 failed**.
- `bash test/run_all_backend.sh` — **8/8 passed**.
- New IPA `build/ios/ipa/samay_app-adhoc.ipa`: legacy JWT key baked in,
  zero `sb_publishable` strings, URL `https://samay-api.qallariy.lat`.

## MISTAKE blocks (for future devs)

> **MISTAKE (session chaos):** during the multi-agent session an agent ran a
> `git stash`/`git reset` sequence that reverted ~150 tracked files (the LUXE
> WIP) and clobbered two agents' in-flight work. The full WIP was recovered
> from the dangling stash commit `9ac0bc9` (`git checkout 9ac0bc9 -- .`) and
> the lost fixes were re-applied. Lesson: NEVER run `git stash`/`git reset`/
> `git checkout` on a shared working tree with in-flight uncommitted work.
> Agents must use `tools/agent_lock.sh` for files, never git.

> **MISTAKE (keys):** the repo root `.env` carried a stale opaque publishable
> anon key while the stacks' Kong/PostgREST ran a legacy HS256 JWT. PostgREST
> silently 401s opaque keys, and the app's error mapping + fail-closed helpers
> turned that into a wrong-screen bounce + cryptic popup instead of a clear
> error. Keep ONE anon key source of truth; if a key stops working, probe both
> `auth/v1` and `rest/v1` before touching code.

> **MISTAKE (stack boot):** `docker network connect` re-attaches a container
> but does NOT restore compose service-name aliases (`db`). Use
> `docker compose up -d --force-recreate <svc>` instead of manual connects.

## Commands run (reproducibility)

```bash
# stack fix
docker network connect samay_default samay-db samay-functions
cd supabase && docker compose up -d --force-recreate db kong
# migrations (local prod DB)
for f in 20260809000005_qr_validate_rpc 20260809000006_minigame_rpc 20260812000001_upsert_signup_tracker_rpc; do
  docker cp supabase/migrations/$f.sql samay-db:/tmp/m.sql && docker exec samay-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/m.sql
done
# WIP recovery
git checkout 9ac0bc9 -- .
# verify
flutter analyze && flutter test
bash test/run_all_backend.sh
make build TARGET=ios-adhoc
```

## Follow-up (same day)

- `tester@tester.com` password set to `tester123` on BOTH the local testing
  stack and remote prod via GoTrue admin API
  (`PUT /auth/v1/admin/users/<id>` with the service_role JWT). Verified:
  `grant_type=password` login returns 200 on both.
- Added `TARGET=simulator` support to `make build` and `make install`
  (`flutter build ios --simulator` + `xcrun simctl install booted`), matching
  the existing `make dev TARGET=simulator` branch — the bare `TARGET=simulator`
  previously fell through to the Android branch (`adb` / release-keystore
  errors). opt-008 makefile-static gate still passes.
- Built + installed the fixed app on the physical device (adhoc) and the iOS
  simulator (iPhone 17 Pro); verified the baked config: remote prod URL +
  legacy anon JWT, zero `sb_publishable` strings. App launches on the
  simulator (pid confirmed).

## Repair wave (same day, post-commit): "Próximamente" elimination + audit closure

Two audit agents cataloged every unimplemented/placeholder item in code and
docs; four repair agents + orchestrator integration closed them:

- **R1 (events + router):** new `MyEventsScreen` (real events tab, listEvents
  backed), new `EventCollageScreen` (photo wall), invite route now renders the
  real `EventInviteRoute`; ZERO `VComingSoonScreen` usages remain in lib/ (the
  widget itself was deleted). Flags flipped ON: events, qr, minigames,
  partyFinder, cosmeticsSection, photoUpload. subscriptions stays OFF (awaits
  RevenueCat key). FlagGate neutral fallback (no "Próximamente" copy).
  16 orphaned coming-soon l10n keys removed.
- **R2 (profile/groups/banner):** public-profile Report wired to
  ModerationService.reportContent (reason dialog + confirmation); Settings
  Notificaciones/Privacidad rows enabled → new NotificationSettingsScreen
  (persisted prefs via config cache) + PrivacyInfoScreen; group Events tab
  lists real events, Chat tab honest 1:1-only state (E2EE §9.6); crash-recovery
  banner (LOG-03 TODO closed). 19 l10n keys added, 3 placeholder keys removed.
- **R4 (server + services):** uploadEventCover fixed → public `groups` bucket
  (was private `events` + getPublicUrl → served nothing); new migration
  20260813000001 with SECURITY DEFINER join_minigame_session +
  finish_minigame_session (escrow, refund, win, FOR UPDATE serialization);
  minigame_service wired to the RPCs; pgTAP 344/344, opt-006 E2E (escrow,
  idempotency, invalid_winner) 42/42, opt-001 43/43.
- **R3 (docs):** to-fix ledger reconciled (16 rows closed with repo evidence,
  4 flipped back to genuinely-open, 4 aligned; category vs summary
  contradictions removed), PHASE-INVENTORY refreshed (14 steps ⚠️ foundation
  landed, I-02 ✅), README stale claims fixed, changelog entry added.
- **Orchestrator integration:** fixed l10n-extraction gate hit
  (`collage-photo-` → `photo-tile-`), justified two new fixed-content
  ListViews, deleted the now-unused VComingSoonScreen widget + its test,
  replaced the responsive coming-soon case with SettingsScreen, cleaned
  qr_flow_test imports.

Final state: flutter analyze 0 issues, flutter test 2189/2189, backend opt
suite 8/8, check_secrets PASS. Committed as fix/feat — see git log.

## Follow-up: funnel-completion gate (age gate + username skipped on Waydroid)

**Bug:** registering on Waydroid (tester3@tester.com, slow x86_64 device) skipped
BOTH the age verification and the username selection; the same flow on the
emulator (tester2@tester.com) completed fully.

**Diagnosis (DB-verified):** tester3 has NO `users` row and
`signup_tracker.profile_created = f` — the account was left incomplete. After
OTP verification the session exists but no profile row yet; a mid-funnel
interruption (app restart / flutter hot-restart) relaunched the app →
`_resolveInitialState` → authenticated + hasProfile=false → the guard's
no-redirect policy dropped the user straight onto the feed, permanently
bypassing age gate, privacy/terms and username selection.

**Fix:** `AuthGuard` now has an explicit funnel-completion gate: an
authenticated user without a `users` row (and not already inside the auth
funnel) is sent to `/auth/age-gate` — the age gate resolves the email from the
session and re-establishes the explicit chain age gate → privacy/terms →
profile setup. This is not a hidden navigation: the age gate is the only
legitimate next step for an incomplete account, and every funnel screen lives
under `authPrefix`, so the redirect only fires OUTSIDE the funnel. It also
covers CLI-created users and any account whose profile row is missing.

**Tests:** router tests updated — profile-less user on /main/feed or /login →
AgeGateScreen (not feed); explicit /auth/signup still reachable. Full suite
2190/2190, analyze clean.
