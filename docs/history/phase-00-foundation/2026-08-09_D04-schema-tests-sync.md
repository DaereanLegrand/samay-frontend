# D-04 — pgTAP Schema Tests Sync (signup_tracker RLS + check_signup_email + donate_shards hardening)

## Date: 2026-08-09

## Role
Documentation agent D-04 — sync `supabase/tests/schema_test.sql` and `supabase-testing/tests/schema_test.sql` with the current migration reality (post `20260724000001` / `20260724000002`).

## What was built

Both pgTAP files (`supabase/tests/schema_test.sql` and `supabase-testing/tests/schema_test.sql`) updated to match migrations `20260724000001_fix_signup_tracker_rls.sql` and `20260724000002_fix_donate_shards_rpc.sql`:

1. **Section 6 (signup_tracker)** — added a `FORCE ROW LEVEL SECURITY` assertion (`relforcerowsecurity` from `pg_class`), matching `ALTER TABLE public.signup_tracker FORCE ROW LEVEL SECURITY` in `20260724000001`. The old "wide-open, accepted for MVP" comment is gone. (+1 test)
2. **Section 10 (donate_shards_to_group)** — updated header/comment to document the `20260724000002` hardening (auth.uid() guard, `REVOKE EXECUTE FROM PUBLIC`, `GRANT EXECUTE TO authenticated`). Kept the structural `has_function(..., ARRAY['uuid','uuid','integer','timestamptz'])` assertion and added a pointer to the behavioral curl test `test/opt-001-rls-security.sh` (TEST H1–H3: anon denied, auth works, cross-user blocked). (0 tests — reference only, per mission)
3. **Section 15 (signup_tracker policies)** — `policies_are` now asserts the 4 email-scoped policies `signup_tracker_select_own` / `insert_own` / `update_own` / `delete_own` (was the 4 "Anyone can ..." wide-open policies). (1 test, replaced)
4. **New Section 37 (check_signup_email)** — `has_function('check_signup_email', ARRAY['text'])` + `has_function_priv` EXECUTE assertions for both `anon` and `authenticated`, matching the `REVOKE ALL ... FROM PUBLIC; GRANT EXECUTE ... TO anon, authenticated` in `20260724000001`. (+3 tests)
5. **Plan count** — `plan(125)` → `plan(129)` (125 + 1 FORCE + 3 check_signup_email), verified by a bash SELECT-line recount (see Verification).
6. **Header comment** — "Covers all 16 migrations" → 18 for `supabase/` (through `20260724000002`); 17 for `supabase-testing/` (through `20260724000001`, with a NOTE documenting the parity gap).
7. **Seed counts** — unchanged and re-verified: `app_config` = 37 keys, `admin_users` = 1 row (37 keys confirmed in all three of `20260510000001_full_schema.sql`, `supabase/seed.sql`, `supabase-testing/seed.sql`).
8. **handle_signup absence** — Sections 13 & 36 already asserted it; kept as-is (mission: "already there").

## Decisions made and why

- **`has_function_priv` over `function_privs_are`** for the EXECUTE grants: `has_function_priv(schema, function, args, role, privilege, description)` is the longest-available pgTAP signature with a description argument; `function_privs_are` (exact acl-set comparison) was avoided to keep the file robust across pgTAP versions.
- **No grant assertion on `donate_shards_to_group`** in the pgTAP file: `supabase-testing/migrations/` does not contain `20260724000002`, so an "anon has no EXECUTE" assertion would pass on the main stack but fail on the testing stack. The behavioral coverage belongs to `test/opt-001-rls-security.sh` (TEST H1–H3), which the file now references. The two test files stay structurally identical.
- **FORCE RLS asserted via `pg_class.relforcerowsecurity`** (same pattern as the pre-existing `relrowsecurity` check) rather than a new helper.
- **No stack was started** (mission constraint: Juega's stack runs; Samay compose files still map 5432/54321 — I-02 owns the remap). Verification is 100% static: grep against migrations + SELECT recount.

## MISTAKE / gotcha

- **MISTAKE (count, caught during verification):** a naive `rg -c '^\s*SELECT '` returns 132, not 129. Line 404 (`SELECT 1 FROM pg_proc WHERE proname = 'handle_signup'`) is a *nested* SELECT inside the `ok(NOT EXISTS (...))` test (Section 36) and is NOT a test. Test count = total − plan − finish − nested = 129. This file already carried this nested SELECT before my change; the original plan(125) was correct under the same counting rule.

## Commands run (verification, all static)

```bash
diff supabase/tests/schema_test.sql supabase-testing/tests/schema_test.sql   # only header note differs
rg -c '^\s*SELECT ' supabase/tests/schema_test.sql                           # 132 → 129 tests (see MISTAKE)
rg -n 'signup_tracker_(select|insert|update|delete)_own' supabase/migrations/20260724000001_fix_signup_tracker_rls.sql   # matches lines 57-68
rg -n 'check_signup_email|GRANT EXECUTE|REVOKE ALL' supabase/migrations/20260724000001_fix_signup_tracker_rls.sql        # fn line 15, grants 43-44
rg -n 'FORCE ROW LEVEL SECURITY' supabase/migrations/20260724000001_fix_signup_tracker_rls.sql                            # line 73
rg -n 'auth\.uid|REVOKE EXECUTE|GRANT EXECUTE|CREATE OR REPLACE FUNCTION donate_shards_to_group' supabase/migrations/20260724000002_fix_donate_shards_rpc.sql
rg -c "^    \('" supabase/migrations/20260510000001_full_schema.sql supabase/seed.sql supabase-testing/seed.sql       # 37 keys each
rg -n 'DROP FUNCTION IF EXISTS public.handle_signup' supabase/migrations/20260513000002_fix_signup_tracker.sql          # line 4
tools/agent_lock.sh acquire/release supabase/tests/schema_test.sql supabase-testing/tests/schema_test.sql docs/history/phase-00-foundation/2026-08-09_D04-schema-tests-sync.md --owner D-04
```

## Verification results

- [x] `plan(129)` == 129 test SELECTs in BOTH files (132 total − plan − finish − nested pg_proc SELECT)
- [x] Every policy name asserted greps to the migration SQL verbatim (4 signup_tracker policies)
- [x] `check_signup_email(text)` + anon/authenticated EXECUTE grants match `20260724000001` lines 15/43-44
- [x] `relforcerowsecurity` assertion matches `FORCE ROW LEVEL SECURITY` line 73
- [x] donate_shards_to_group signature matches both `20260512000001` and `20260724000002`; opt-test reference exists (`test/opt-001-rls-security.sh` TEST H)
- [x] seed counts unchanged: app_config 37 (all 3 sources), admin_users 1
- [x] `handle_signup` drop verified (`20260513000002` line 4)
- [x] No stale "Anyone can" assertions remain (only explanatory comments)
- [x] Files mirrored: only the header migration-count note differs (env-accurate)

## Deferred / notes

- **LIVE `supabase db test` run is pending**: must be executed after I-02 (compose/config port remap to 54382/54386/54381/54384/54388/54443) and I-77 (pgTAP expansion) land, when the remapped stack is up. Not run now by design (mission constraint).
- **Parity gap found (report to I-02/M-10/D-08):** `supabase-testing/migrations/` is missing `20260724000002_fix_donate_shards_rpc.sql` (17 vs 18 migrations). Until it is copied over, the testing stack keeps PUBLIC EXECUTE on `donate_shards_to_group`.
- **Stale docs found (report to D-02):** `docs/specs/steps/phase-00-foundation/SECU-rls-policies.md` (line 38: signup_tracker "wide-open"), `docs/specs/steps/cross-references.md` (SECU row + Known Issues: "signup_tracker wide-open RLS") and `docs/specs/product/samay_mvp_spec.md` §5 note still describe the pre-`20260724000001` state.
- **No commits made** (orchestrator checkpoints commit).
