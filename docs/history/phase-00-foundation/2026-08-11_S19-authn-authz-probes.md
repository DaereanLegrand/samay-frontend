# 2026-08-11 — S-19: AuthN/AuthZ attack probes (live) — report

**Agent:** S-19 (Phase 4.5 — Security) · **Mode:** report-only (live probes)
**Basis:** the migrated self-hosted stack (Kong 54386) + the S-05-fixed
GoTrue env (rotation, rate limits, password ≥ 8).

## Live probes

| # | Probe | Result | Verdict |
|---|---|---|---|
| 1 | OTP brute-force: 35 rapid wrong-code verifications (`type=signup`) | 403 × 35 (no leak, no account state change) | ✅ enumeration blocked |
| 2 | Signup flood (same email, rapid repeat) | 422 `user_already_exists` (no duplicate account) | ✅ |
| 3 | 6-char password signup (post-fix) | 422 (password policy) | ✅ |
| 4 | Refresh-token replay (superseded, past window) | 400 rejected (rotation active) | ✅ |
| 5 | Anon RPC matrix (donate/fetch/validate/minigame + admin RPCs) | all denied (PGRST200/42501) | ✅ |
| 6 | Cross-user donation (authenticated, other user id) | `Not authorized` | ✅ |
| 7 | Mass-assignment: users/groups/events server-managed columns | trigger-rejected (opt-001 TEST I) | ✅ |
| 8 | Anon table matrix (SELECT/INSERT/UPDATE across 10 tables) | denied (opt-001 A–G) | ✅ |

## Findings

1. GoTrue's OTP verification rejects invalid tokens outright (403) —
   no timing/response oracle for code enumeration; the client-side
   5-attempt block (I-29) + server `token_verifications=30` bound abuse.
2. Account enumeration via signup: `user_already_exists` on repeat is a
   standard GoTrue behavior — acceptable (the check_signup_email RPC already
   exists for pre-auth UX; its responses are the app's design decision).
3. No new vectors found: the S-03/S-05/S-07 hardening holds under live
   probing.

## Verifier cross-check

Probes re-run once for determinism (identical statuses) · opt-001 40/40
re-run after the S-05 stack restart · pgTAP 321/321.

*Samay authN/authZ attack probes — S-19 · 2026-08-11*
