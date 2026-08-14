# 2026-08-09 — EF-05: Docs & migration parity sweep (consistency gaps)

**Agent:** EF-05-parity-docs · **Role:** consistency/parity fixer across `supabase/`,
`supabase-testing/`, and `docs/` — closes gaps flagged by I-33, I-35, I-37, I-31, D-03,
D-04, D-07, D-08, and M-10 track.
**Status:** DONE · **Mode:** static-only (no docker, no DB, no stack, no commits, Juega untouched).

## What was fixed

### 1. supabase-testing migration parity (I-33 gap — pre-existing, reported by I-32/D-04/D-08)
- `supabase-testing/migrations/20260510000001_full_schema.sql` still carried the §7
  seed INSERTs (7.1 admin_users + 7.2 app_config 37-key block) that I-33 had removed
  from `supabase/migrations/20260510000001_full_schema.sql` (SUP-04: seed data lives
  only in `seed.sql`). The only other diff in the file was that section.
- **Fixed:** replaced the supabase-testing seed section with the identical pointer
  comment block. Verified byte-identical afterwards:
  `cmp supabase/migrations/20260510000001_full_schema.sql supabase-testing/migrations/20260510000001_full_schema.sql`
  → clean. All 19 other migrations were already byte-identical (scripted `cmp` loop).
- `rg -c 'INSERT INTO (app_config|admin_users)'` on both files → 0 hits.

### 2. I-33 seed-key parity
- `app.search_debounce_ms` verified present in BOTH `supabase/seed.sql` and
  `supabase-testing/seed.sql` (line 51, value '300', PERF-05/L-24 comment). Both files
  identical, 38 keys each (`rg "^    \('" | wc -l` → 38/38). No edit required.

### 3. E2EE doc "112 bytes" errata (I-37 flagged, V-06 relevant)
- `docs/security/E2EE-ARCHITECTURE.md` §6.4 printed `4+1+1+32+32+32+4+4+4 = **112 bytes**`
  while the field table sums to 114. The implemented codec
  (`lib/crypto/envelope.dart` `ratchetHeaderSize = 114`, with the empirical I-37
  comment that 112 misaligns `ct_len` by 2 bytes and breaks AEAD) is authoritative.
- **Fixed:** spec now reads `= **114 bytes**` + an ERRATA note that the implementation
  is authoritative (I-37 verified; MISTAKE-1 ref in `2026-08-09_I37-e2ee-core.md`).
- Second occurrence fixed in the D-07 daily log (`2026-08-09_D07-e2ee-architecture.md`,
  "112-byte header" → "114-byte header" + errata pointer).

### 4. FILE-OWNERSHIP.md stale paths
- `lib/core/utils/retry.dart` → `lib/core/utils/async_ops.dart` (verified: `retry.dart`
  does not exist; `async_ops.dart` exists with withRetry/withTimeout/backoff/resilient).
- `tools/check_ports.sh` → `tools/check_ports.sh` (verified: `tools/` has it, `tools/`
  does not exist).

### 5. TODO.md H-32 (I-35's flip never landed — blocked by I-37's lock)
- H-32 row did not exist anywhere in `docs/to-fix/` (I-35's log documented the block).
- **Fixed:** added H-32 to the HIGH table (ban enforcement: Go CLI writes
  `users.banned_at` but banned users kept working JWTs). Marked ✅ (I-35, 2026-08-09 —
  BanService + auth gate + `/banned` screen, 11 tests green; flip landed by EF-05)
  with the note that **server-side `custom_access_token_hook` enforcement remains
  OPEN (S-03/EEDG)** — the authoritative boundary.
- Counts updated: HIGH 31 → 32, TOTAL 112 → 113.

### 6. test/README.md stale "planned (I-01)" integration note
- The integration-suite row, the "Running Tests" snippet, and the naming-convention
  entry still said "Being created by I-01 (planned) / run_all.sh".
- **Fixed:** now describes the landed layout — `integration_test/` with
  `auth_flow_test.dart`, `error_flow_test.dart`, `profile_flow_test.dart`,
  `integration_test/README.md`, `runner.sh` (dependency-safe order), hermetic-by-default
  in-memory harness (`support/fake_supabase.dart`), opt-in live flows
  (`support/test_users.dart`).

### 7. SECU-rls-policies.md:38 stale signup_tracker note
- Line 38 + the "Known RLS Issue" section still described the pre-`20260724000001`
  wide-open `USING (true)` state.
- **Fixed:** policy-design row now reflects the email-scoped `signup_tracker_*_own`
  policies + `FORCE ROW LEVEL SECURITY` (migration `20260724000001`) and the hardened
  `check_signup_email` RPC; the Known RLS Issue section is marked RESOLVED with
  references (C-01/SUP-01, pgTAP Sections 6/15/37).

### 8. SECURITY.md gap table — 5 rows with evidence
- **G-03** → ✅ (I-32, 2026-08-09 — migration `20260809000002`: column REVOKE on the
  7 protected users columns + `assert_safe_user_update()` trigger; pgTAP §39a/39b).
- **G-04** → ✅ (I-30 + I-25, 2026-08-09 — PKCE pinned, `tokenRefreshed` handling +
  `refreshSession()`, SecureStorage session/PKCE persistence; SEC-04/SEC-11, H-22).
- **G-05** → ✅ (I-29, 2026-08-09 — client OTP cooldown + attempt caps; server-side
  `rate_limits` remains S-10/I-31).
- **G-10** → ✅ (I-26, 2026-08-09 — Hive AES-256 at rest, key in flutter_secure_storage;
  SEC-10/M-32).
- **G-17** → ✅ (D-04, 2026-08-09 — pgTAP now asserts email-scoped policies + FORCE
  RLS + check_signup_email grants; no "Anyone can" assertions left; both files
  byte-identical).
- Only these 5 rows touched (evidence in the I-32/I-30/I-29/I-26/D-04 logs). G-01/G-02
  flips deliberately left to V-02 per I-31's deferred notes.

## Lock evidence (tools/agent_lock.sh)

All acquired + released by EF-05-parity-docs:

| File | Acquire | Release |
|------|---------|---------|
| `supabase/migrations/20260510000001_full_schema.sql` (reference, no edit) | ✅ | ✅ |
| `supabase-testing/migrations/20260510000001_full_schema.sql` | ✅ | ✅ |
| `supabase/seed.sql` (verify only) | ✅ | ✅ |
| `supabase-testing/seed.sql` (verify only) | ✅ | ✅ |
| `docs/security/E2EE-ARCHITECTURE.md` | ✅ | ✅ |
| `docs/history/phase-00-foundation/2026-08-09_D07-e2ee-architecture.md` | ✅ | ✅ |
| `docs/process/FILE-OWNERSHIP.md` | ✅ | ✅ |
| `docs/to-fix/TODO.md` | ✅ (waited for EF-01's lock; acquired after release) | ✅ |
| `test/README.md` | ✅ | ✅ |
| `docs/specs/steps/phase-00-foundation/SECU-rls-policies.md` | ✅ | ✅ |
| `docs/security/SECURITY.md` | ✅ | ✅ |
| `docs/history/phase-00-foundation/2026-08-09_EF05-parity-docs.md` (this log) | ✅ | ✅ |

## Verification (commands + results)

```bash
cmp supabase/migrations/20260510000001_full_schema.sql \
    supabase-testing/migrations/20260510000001_full_schema.sql   # ✓ identical
rg -c 'INSERT INTO (app_config|admin_users)' supabase*/migrations/*.sql  # 0 hits
rg -n 'app.search_debounce_ms' supabase/seed.sql supabase-testing/seed.sql  # line 51 both
rg -c "^    \('" supabase/seed.sql supabase-testing/seed.sql     # 38 / 38
rg -n '114' lib/crypto/envelope.dart                              # ratchetHeaderSize = 114
rg -n '112|114' docs/security/E2EE-ARCHITECTURE.md                # 114 only (ERRATA note)
rg -n 'retry\.dart|async_ops\.dart|tools/check_ports|tools/check_ports' docs/process/FILE-OWNERSHIP.md
rg -n 'H-32' docs/to-fix/TODO.md                                  # row + counts
rg -n 'planned|I-01' test/README.md                               # no stale planned refs
rg -n 'wide-open' docs/specs/steps/phase-00-foundation/SECU-rls-policies.md  # only RESOLVED context
rg -n 'G-03|G-04|G-05|G-10|G-17' docs/security/SECURITY.md        # ✅ rows
```

## Deferred / notes

- **Root README.md** still says `integration_test/ — PLANNED (I-01)` (lines 147, 216)
  — D-05-owned, not in my lock list; flagged for D-05/V-09.
- **H-32 has no category-file entry** (`docs/to-fix/categories/08-SECURITY.md` is
  D-03-owned); a SEC-16-style entry could be added by D-03/V-02 for cross-reference
  consistency (the S-03/EEDG hook handoff is already noted in SEC-04's "Remaining").
- **TODO.md header** "173 total findings" is the category-wide total (D-03 convention);
  the table total is now 113. Left untouched (D-03 owns the header semantics).
- No tests run: docs/parity-only agent (no code changed). No docker, no commits,
  Juega untouched.
