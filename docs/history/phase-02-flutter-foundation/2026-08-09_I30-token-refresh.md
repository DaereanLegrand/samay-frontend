# 2026-08-09 — I-30: Token refresh + explicit PKCE (SEC-04 / H-22)

**Agent:** I-30 (token refresh + PKCE — provider, client init, tests)
**Status:** DONE
**Scope:** `lib/main.dart` (explicit `authFlowType: AuthFlowType.pkce`),
`lib/core/providers/auth_provider.dart` (`tokenRefreshed` null-session handling +
`refreshSession()` on the notifier), `test/providers/auth_provider_test.dart` (4 new
tests), `docs/to-fix/TODO.md` (H-22 flip), `docs/to-fix/categories/08-SECURITY.md`
(SEC-04 flip), this log.
**Note:** third attempt of this agent; prior sessions stalled without producing work.
This session completed the full RED → GREEN → REFACTOR → VALIDATE → DOCUMENT cycle.

## Context

SEC-04 / H-22 (`docs/to-fix/categories/08-SECURITY.md`): `AuthService.refreshSession()`
existed but was never called by any caller; PKCE was never explicitly configured on
`Supabase.initialize`; the `tokenRefreshed` auth event silently fell through to the
shared `initialSession/signedIn/tokenRefreshed` branch where a null/expired session
was silently treated as unauthenticated (no log, and — because the branch also covers
`initialSession` — no distinction between "never had a session" and "refresh died").

## What was built

1. **Explicit PKCE** (`lib/main.dart`) — `FlutterAuthClientOptions` now pins
   `authFlowType: AuthFlowType.pkce`. Verified against the installed SDK first:
   `supabase_flutter 2.12.4` (`flutter_go_true_client_options.dart:11` —
   `super.authFlowType`) and `supabase 2.10.6` (`supabase_client_options.dart:17` —
   `AuthClientOptions.authFlowType` defaults to `AuthFlowType.pkce`). The field exists,
   so per assignment the explicit pin was added (guards against default drift and makes
   the flow visible; the code verifier is persisted by I-25's `SecurePkceStorage`).
2. **`tokenRefreshed` null-session handling** (`lib/core/providers/auth_provider.dart`)
   — the event now has its own case: a session-bearing `tokenRefreshed` rebuilds state
   via I-35's `_authStateForUser` with the **cache-aware** ban check
   (`forceBanCheck: false`, matching I-35's design: a ban lands at worst within the 30 s
   cache window on a long-lived session); a null-session `tokenRefreshed` logs
   `AppLogger.warn` and transitions to unauthenticated instead of silently keeping a
   stale session. `initialSession`/`signedIn` keep the existing shared branch
   (`forceBanCheck: true`).
3. **`AuthNotifier.refreshSession()`** — explicit token renewal for callers that need a
   fresh session now: calls `AuthService.refreshSession()` (which swallows transport
   errors and returns `Map<String, dynamic>?`); null → warn + unauthenticated; success →
   `_authStateForUser(user)` (ban gate + profile probe reused from I-35).

## Tests (RED → GREEN)

`test/providers/auth_provider_test.dart` — 4 new tests (12 total in the file), mocktail
seam over `AuthService` + `BanService` with a controllable
`StreamController<supabase.AuthState>`:

- TOKEN_REFRESHED with a valid session keeps the user authenticated.
- TOKEN_REFRESHED without a session transitions to unauthenticated (starts authenticated).
- `refreshSession()` success updates the state with the new user (+ `verify` the call).
- `refreshSession()` failure (returns null) transitions to unauthenticated.

RED: the two `refreshSession()` tests failed to compile (`AuthNotifier.refreshSession`
undefined). GREEN after the provider change: all 4 pass.

## Validation

```bash
dart analyze lib/main.dart lib/core/providers/auth_provider.dart test/providers/auth_provider_test.dart
# No issues found!
dart analyze lib/                                # 0 errors, 14 info (all pre-existing —
                                                 #   I-36 in-flight public_profile_screen.dart)
flutter test test/providers/auth_provider_test.dart test/router/app_router_test.dart
# 73/73 pass (12 provider + 61 router)
flutter test test/features/auth/ test/providers/ test/services/
# 98/98 pass
```

## Commands run

```bash
export AGENT_NAME="I-30-token-refresh"
tools/agent_lock.sh acquire lib/main.dart --owner "$AGENT_NAME"   # + auth_provider.dart,
#   test/providers/auth_provider_test.dart, docs/to-fix/TODO.md, 08-SECURITY.md (all instant —
#   no locks were held at session start)
# RED → GREEN → analyze → tests → docs
tools/agent_lock.sh release <all 5 files> --owner "$AGENT_NAME"
```

## MISTAKE blocks

- **MISTAKE (my RED phase):** I initially considered testing the stream path with a
  `StreamController<dynamic>` — wrong: gotrue 2.20.0's `AuthState` is a *class*
  (`AuthState(event, session, {fromBroadcast})`), not a record, so the events must be
  built as `supabase.AuthState(...)`. Resolved with a second, prefixed import of
  `package:supabase_flutter` (the unprefixed one keeps `hide AuthState` for Samay's
  `AuthState`). The prefixed import also avoids adding a direct `gotrue` dependency
  (would trip `depend_on_referenced_packages`).
- **MISTAKE (prior sessions, reported by orchestrator):** the two previous I-30 attempts
  stalled without producing work — likely from over-scoping. This session stuck to the
  assignment's numbered steps and ran analyze/tests after every change.

## Issues found / reported (not fixed — out of scope)

- **Refresh failure does NOT emit `tokenRefreshed` in the installed gotrue:** in
  `gotrue 2.20.0`, a failed auto-refresh either emits `signedOut` (invalid refresh
  token) or logs/rethrows on retryable network errors — a null-session `tokenRefreshed`
  is therefore rare. The defensive handling is still correct (SEC-04 fix guidance item 2
  asks for exactly this), and `AuthNotifier.refreshSession()` gives the app an explicit
  path to attempt renewal. The authoritative failure surface remains the SDK.
- **`AuthService.refreshSession()` swallows the error** (`auth_service.dart:64-72`,
  logs + returns null): the notifier therefore cannot distinguish "network down" from
  "refresh token revoked". Both map to unauthenticated — acceptable per SEC-04 (the
  router redirects to login; the user re-authenticates). A future refinement could
  surface a network error state instead of signing out; left for the I-44/I-47 test
  pass if desired.
- **`authFlowType` is `AuthFlowType.pkce` by default in supabase 2.10.6** — the explicit
  pin is documentation + drift protection, not a behavior change on this SDK version.
- **`docs/security/SECURITY.md` G-04 / §2.3** still describes the pre-fix state
  (`refreshSession()` never called, no PKCE on init). D-06 owns that doc; the status
  flip there is out of scope for this agent (noted for the orchestrator).
- **Server-side ban hook handoff** (from I-35's log) remains open: a
  `custom_access_token_hook` rejecting token issuance for banned users is the
  authoritative enforcement — still S-03/EEDG scope.
