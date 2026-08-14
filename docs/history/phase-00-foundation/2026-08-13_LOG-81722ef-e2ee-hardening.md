# E2EE Hardening: Replay Protection, Session Convergence, SPK Expiry (2026-08-13, `81722ef`)

**Agent:** R2-log-backfill (docs-remediation sweep) · **Branch:** `fixes` · **HEAD:** `81722ef`

## What was built

Security-hardening pass over the E2EE stack after the SECURITY.md §5.2 / MASVS
audit follow-ups. 13 files, +683/−62:

1. **X3DH init-envelope replay protection (§4.2 blacklist):** persisted
   `sha256(sender_ik_dh|ekA|spk_id|opk_id)` marker drops replayed init
   envelopes without re-delivering plaintext or touching the session; survives
   restarts.
2. **Inactive-session convergence (Sesame §3.2/§3.4):** displaced sessions kept
   up to 30 days, **bounded at 2**; tried on active-session decrypt failure and
   activated on success — simultaneous-init sessions now converge.
3. **Failed-init abort path (Sesame §3.4):** a failed init attempt restores the
   previous session.
4. **Signed prekey expiry (§5.2):** retired SPK privates deleted 7 days after
   rotation in both stores; orphan key files purged; `spk.meta` gains
   `retired_at`.
5. **`computeFingerprint()` is now read-only** — no X3DH initiation, no OPK
   consumption (was a side-effecting call).
6. **Secure key store:** `useSecureE2eeKeyStore` flipped to `true` — identity/
   prekey/ratchet material lives in `flutter_secure_storage` (Keychain/
   Keystore) instead of being regenerated every launch.
7. **`E2eeSessionStore.wipeAll()`** + wipe on `signOut`/`deleteAccount` (§7.6),
   best-effort so a storage failure never blocks sign-out (auth wiring in
   `auth_provider.dart` +16, `chat_providers.dart` +18).

Core changes in `lib/crypto/session.dart` (+286), `e2ee_key_store.dart` (+82),
`e2ee_primitives.dart` (+8), `constants.dart` (+18), `interfaces.dart` (+5).

## Tests / validation

- +9 crypto (`session_test.dart` +168, `e2ee_key_store_test.dart` +41) and +2
  auth (`auth_provider_test.dart` +59) — suite **2209/2209**, `dart analyze`
  clean.
- `test/meta/conventions_test.dart` updated: commit/push allowed since
  2026-08-14 (product decision), destructive git ops stay denied.
- `test/opt-008-makefile-static.sh` (+24): scratch-repo git calls no longer
  inherit `GIT_INDEX_FILE` (the pre-commit hook's temp index was clobbering the
  macos tracked-file checks under `git commit`).

## Decisions

- Replay blacklist persisted in the session store (not memory) so it survives
  restarts; convergence bounded at 2 inactive sessions to cap storage growth.
- Wipe is best-effort by design: sign-out/delete-account must never block on
  Keychain errors.

## Commands run

```bash
git show 81722ef --stat            # 13 files, +683/−62
dart analyze                       # 0 issues
flutter test                       # 2209/2209
```

## Follow-ups

- Group fan-out (§9.6) still pending.
- SPK rotation cadence / OPK replenishment monitoring on a live stack.
