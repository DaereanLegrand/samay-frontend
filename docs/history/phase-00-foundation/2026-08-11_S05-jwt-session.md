# 2026-08-11 — S-05: JWT / session security audit (report)

**Agent:** S-05 (Phase 4.5 — Security) · **Mode:** report-only
**Method:** client-wiring review (`lib/`) + live empirical probes against the
running self-hosted auth (GoTrue v2.189.0) + config.toml vs compose-env
drift analysis.

## Client side (Flutter) — all PASS

| Check | Evidence |
|---|---|
| PKCE pinned | `lib/main.dart:119` `authFlowType: AuthFlowType.pkce` (I-30) |
| Session + PKCE verifier in secure storage | `SecureSessionStorage` / `SecurePkceStorage` (main.dart:113-114, I-25) |
| Refresh path explicit + failure-safe | `AuthService.refreshSession` (auth_service.dart:71) → `AuthNotifier.refreshSession` (auth_provider.dart:84); null session → warn + unauthenticated (no stale-session keep, I-30) |
| JWT audience/roles | `GOTRUE_JWT_AUD=authenticated`, `GOTRUE_JWT_ADMIN_ROLES=service_role` (compose) — app never carries service_role |
| Token expiry | `GOTRUE_JWT_EXP=3600` (1 h access) |

## Server side (self-hosted GoTrue) — 2 CONFIRMED GAPS

### 1. Refresh-token rotation NOT effective in the compose stack (HIGH) — **FIXED**
`supabase/config.toml` declares `enable_refresh_token_rotation = true` +
`refresh_token_reuse_interval = 10`, but the **compose auth service did not
pass any of the `GOTRUE_SECURITY_*` vars** (verified: absent from the running
container env). Empirical probe: signed in, refreshed once, then replayed the
**already-used** refresh token → HTTP 200 (new session issued). A stolen
refresh token therefore stayed valid indefinitely.
**Fix (applied in this batch):** compose `auth` env now sets
`GOTRUE_SECURITY_REFRESH_TOKEN_ROTATION_ENABLED: true`,
`GOTRUE_SECURITY_REFRESH_TOKEN_REUSE_INTERVAL: 10`,
`GOTRUE_RATE_LIMIT_TOKEN_REFRESH: 150`,
`GOTRUE_RATE_LIMIT_TOKEN_VERIFICATIONS: 30`,
`GOTRUE_RATE_LIMIT_SIGN_IN_SIGN_UPS: 30` (both stacks).
**Verifier (post-fix, live):** login → refresh → refresh → replay of the
deeply-superseded first token after 11 s → **HTTP 400 REJECTED** — rotation
active; the bounded reuse window (10 s) matches the config.toml design.

### 2. Password minimum length = 6 in the RUNNING stack (MEDIUM) — **FIXED**
Empirically verified: signup with the 6-character password `sixsix` →
HTTP 200, account created. config.toml also set 6 (below NIST SP 800-63B
§5.1.1's ≥ 8) and the compose stack didn't pass `GOTRUE_PASSWORD_MIN_LENGTH`.
**Fix (applied in this batch):**
- `GOTRUE_PASSWORD_MIN_LENGTH: 8` in both compose stacks + 
  `minimum_password_length = 8` in both config.toml files.
- Client policy `lib/features/auth/logic/password_policy.dart` raised 6 → 8
  with the ARB strings (`authPasswordWithRequirements`,
  `authPasswordTooWeak`) regenerated and all referencing tests updated
  (password_policy_test, auth_interactions_test, restyle_test,
  l10n_extraction_test).
**Verifier (post-fix, live):** 6-char signup → **HTTP 422 REJECTED**;
8-char signup → HTTP 200 ACCEPTED.

## Other notes

- `GOTRUE_MAILER_AUTOCONFIRM: true` in compose — dev-only convenience;
  MUST be `false` with real SMTP before any external/staging use (already
  noted in the Makefile; re-flagged for the release checklist).
- `GOTRUE_JWT_SECRET` is the documented dev placeholder; prod rotation is in
  the SECURITY.md incident runbook.
- No session-revocation UI (all-sessions sign-out) — product decision
  (MASVS S3.6, S-01 finding).
- OTP: client-side 60 s cooldown + 5-attempt block (I-29); server-side OTP
  rate limits exist in config.toml but only `EMAIL_SENT` reaches the compose
  stack — cover with the same env-wiring fix as #1 (S-10 re-verifies).

## Verifier cross-check

Pre-fix probes: 6-char signup → 200 (gap #2); refresh reuse → 200 (gap #1).
Post-fix probes (deterministic, re-run): 6-char signup → 422; 8-char signup →
200; superseded-token replay → 400. Client wiring grep-verified. No
regressions: flutter 2032/2032, opt-tests 8/8, opt-007 static PASS, pgTAP
321/321, `dart analyze` 0 issues.

*Samay JWT/session audit — S-05 · 2026-08-11 · gaps FIXED in this batch*
