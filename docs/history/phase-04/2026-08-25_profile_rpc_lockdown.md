# 2026-08-25 — Profile-RPC lockdown (users table)

## Directive

"API IS EXPOSED AND ANY USER WITH THE ANON TOKEN CAN ABUSE THE PLATFORM.
I WANT A RPC FOR BASIC STUFF username, bio, date_of_birth, FORBID CLIENTS TO
MODIFY ANY OTHER FIELD UNDER NO CIRCUMSTANCE." — plus: the RPCs must
DB-sanitize and validate server-side, mirroring client validation.

## What was built

**SQL (baseline edit `020_core/02_users.sql`, byte-identical mirror in
`supabase-testing/migrations/`):**
- Helpers (IMMUTABLE, `search_path=''`): `sanitize_username` (NFKC → strip
  Unicode Cc/Cf ranges → trim → drop whitespace/`@`), `sanitize_free_text`
  (strip Cc/Cf + trim + code-point cap), `assert_username_shape`
  (required / ≥5 / ≤64 cp / charset / NFKC-stable), `assert_date_of_birth`
  (required / ≥18 y / ≥1900).
- SECURITY DEFINER RPCs scoped to `auth.uid()`, PUBLIC-revoked,
  authenticated-granted: `create_my_profile` (validate + insert row with
  economy defaults + atomic signup `shard_ledger` grant),
  `update_my_profile(p_bio, p_date_of_birth)` (username immutable by design —
  no parameter; bio `''`=clear, ≤160 cp; DOB **set-once**), 
  `delete_my_account()` (tombstone rename), and setters `set_avatar_url`
  (https-only), `set_discovery_opt_in`, `set_read_receipts_enabled`,
  `set_profile_public`.
- Lockdown DCL: `REVOKE ALL ON users FROM anon`; authenticated keeps SELECT
  only; `service_role` untouched (Go CLI/cron/seeds keep working). Clients
  now have NO write path to the table at all.
- Defense-in-depth CHECK `users_username_shape` (tombstone-exempt) — fires
  even for privileged raw writers.

**Client:** all six former direct-table writers rewired to RPCs
(`AuthService.createUserProfile/softDeleteUser`,
`UserService.updateAvatarUrl/updateBio/setDiscoveryOptIn`,
`ChatService.setReadReceiptsEnabled`, `SocialService.setProfilePublic`);
client-side username sanitize kept as defense-in-depth before the call.

**Tests (RED→GREEN):** pgTAP Section 60 (+82 assertions, plan 504→586, both
mirrors); new curl suite `test/opt-014-profile-rpc.sh` (24 checks incl. THE
pin: user/anon direct PATCH/POST → permission denied); opt-001 TEST I pins
flipped to the new contract; Dart service/provider fakes updated.

## Decisions

- Set-once DOB: opening DOB to clients would unfarm… farm the age gate;
  heal path only when NULL.
- Username immutable after creation (matches the product caption).
- Code-point caps (64/160) instead of grapheme parity — PG has no grapheme
  count; 64 never false-rejects the client's 20-grapheme emoji handles.
- Server RAISES with client-parity Spanish messages (`P0001`) so the existing
  `error_mapper` surfaces them verbatim.

## MISTAKE blocks

- MISTAKE: `RAISE EXCEPTION '... % ...' USING ERRCODE=...` without the
  parameter arg → "too few parameters specified for RAISE". Pass the value
  after the format string.
- MISTAKE: pgTAP `throws_ok` message arg is EXACT-match, not substring.
- MISTAKE: inside `$$dollar quotes$$`, `E'\\u200B'` stays a literal
  backslash sequence — single backslash decodes; and stripping ZWSP between
  spaces leaves a DOUBLE space (no whitespace collapse — that IS client
  parity).
- MISTAKE: GoTrue admin-create assigns its OWN uuid — never assert row state
  against a client-chosen constant id; read the returned id.
- MISTAKE: bare `psql` lacks pgTAP functions on this image until
  `CREATE EXTENSION pgtap` (the Makefile's CLI route hung on TLS);
  extension install + psql fallback worked. Also `ARRAY[]` needs `::name[]`.

## Pre-existing issues found (NOT fixed, out of scope)

- `opt-007-compose-static.sh` fails at HEAD for reasons unrelated to this
  work: (a) its key-alignment grep expects an obsolete inline
  `SERVICE_KEY="${SERVICE_KEY:-…}"` pattern that the current opt-tests
  (dev_env.sh sourcing) don't contain; (b) tracked tool artifact
  `supabase/.temp/cli-latest` drifted (CLI upgraded 2.100.1 → 2.115.0 during
  pgTAP runs).

## Commands

```
cd supabase-testing && echo reset | bash reset.sh     # applies edited baseline
make supabase-db-test (or psql fallback)              # 586/586 assertions
bash test/opt-014-profile-rpc.sh                      # 24/24
bash test/run_all_backend.sh                          # 14/15 (only pre-existing opt-007)
make check && make test                               # gates green, 2454/2454
```

Baselines moved: Flutter 2449→2454; pgTAP plan 504→586; opt-tests 13→15.
