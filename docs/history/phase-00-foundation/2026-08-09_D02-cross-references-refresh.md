# 2026-08-09 — D-02: Refresh `docs/specs/steps/cross-references.md`

## What was built

Refreshed the step dependency graph doc (`docs/specs/steps/cross-references.md`) so it reflects
the working tree on 2026-08-09 (branch `fixes`, H-02 uncommitted). No code changed.

### Status corrections (verified against code, not guessed)

| Row | Old claim | New claim (verified) |
|-----|-----------|----------------------|
| `SECU` | "`signup_tracker` has wide-open RLS — known issue" | ✅ RLS locked down — migration `20260724000001` (email-scoped policies, FORCE RLS, SECURITY DEFINER `check_signup_email`); donate RPC auth check in `20260724000002` |
| `TRIG` | ✅ (bare) | ✅ + note: all 6 triggers exist incl. `message_cap_trigger` and `shard_distribution_dispatch_trigger` (placeholder, `RAISE LOG` only) |
| `CRON` | ✅ (bare) | ✅ + note: status-poll + account-hard-delete scheduled; `ranks.update_cron`/`override-reconciler` pending GRCK/MPGR |
| `AUTH` | "Signup uses OTP-only (no password)" | Signup flow is email + password + OTP verification + age gate + terms + username |
| `CHAT` | "18 methods in `supabase_service.dart` throw `UnimplementedError`" | ❌ screens still, but C-02 replaced all stubs — service layer complete; E2EE planned I-37/I-38 |
| `APIS` | "`cmd/samay-api-server/` directory is empty" | Directory does not exist (removed in Vive→Samay rename); no `build-api` Makefile target |
| Known issues: `signup_tracker` wide-open, `cmd/samay-admin` (C-07), raw path strings (H-02), 14/15 `Scaffold()` stubs (H-01), `realtime_provider.dart` stub (L-01) | stale rows | ✅/updated; added rows: donate RPC auth (C-06), port convention change (partial), `schema_test.sql` stale (D-04), `supabase-testing` one migration behind, 23 pre-existing Flutter failures (I-47) |

### New sections (same table format, no restructuring)

- **Planned Workstreams (180-Agent Orchestration)** table between Phase 15 and the Dependency Graph:
  `I-01` (integration_test suite), `I-02`+`M-01..M-10` (self-hosted Docker, ⚠️ partial port remap),
  `I-37`+`I-38` (E2EE double-ratchet chat), `D-11`+`U-01..U-30` (disco design system),
  `I-49..I-78` (phase 05+ foundations).
- **Dependency graph**: appended "Orchestration workstreams" block (docs/process, I-01, I-02/M-01..M-10,
  D-11/U-01..U-30, I-37/I-38, I-49..I-78) and fixed the stale `SECU ⚠️ (signup_tracker wide-open)` line.
- **Critical path**: added "Campaign chains" block (self-hosting, E2EE, disco UI, tests).

## Decisions

- **Verified every changed row with a grep before editing** (see Verification below). Anything I could
  not verify was left untouched or marked with its source (e.g., 176/23 test baseline comes from
  `AGENT-RULES.md` §2 and the H-02 daily log, not re-run).
- **Port convention row is ⚠️ Partial, not ✅**: `supabase/config.toml` api/studio/inbucket/analytics
  are remapped (54386/54381/54384/54388) but `[db] port = 5432` and both `docker-compose*.yml` sets
  still map 5432/54321/54443 — a live conflict with Juega's stack. The stack must NOT be started
  until I-02/M-01..M-10 land (AGENT-RULES §0.3).
- **`schema_test.sql` and `supabase-testing/` gaps recorded as known issues owned by others**
  (D-04, M-10/I-02) — out of scope for D-02; reported, not fixed.
- **Did NOT touch `docs/to-fix/TODO.md`** — owned by D-03 (already modified in the working tree).

## MISTAKE

- **MISTAKE (caught before edit)**: first draft of the "Known Issues" signup_tracker row kept the old
  severity ⚠️ with only a "fixed" note; rewrote as ✅ with the migration evidence. Severity must reflect
  current reality, not history.
- **MISTAKE (caught on review pass)**: the visual graph's `SECU ⚠️ (signup_tracker wide-open)` line
  contradicted the updated table row — fixed after the first full-file read.
- **MISTAKE (avoided)**: nearly copied the old APIS row ("empty directory") verbatim — verified
  `ls cmd/samay-api-server` first: the directory no longer exists at all.

## Verification (greps run after editing)

```bash
# signup_tracker RLS fix — policies + FORCE RLS + check_signup_email RPC exist
rg -n "check_signup_email|signup_tracker_select_own|FORCE ROW LEVEL SECURITY" supabase/migrations/20260724000001_fix_signup_tracker_rls.sql
# donate RPC auth check — auth.uid() guard + REVOKE/GRANT
rg -n "auth.uid\(\) != p_user_id|REVOKE|GRANT EXECUTE" supabase/migrations/20260724000002_fix_donate_shards_rpc.sql
# no UnimplementedError left in lib/ (C-02 claim)
rg -c "UnimplementedError" lib/            # (no matches → exit 1)
# H-02 RoutePaths exists + tested
ls lib/core/router/route_paths.dart test/router/route_paths_test.dart
# C-07 CLI entry point exists
ls cmd/samay-admin/main.go cmd/samay-admin/root.go
# TRIG claim: message_cap + shard_distribution_dispatch in schema
rg -n "message_cap_trigger|shard_distribution_dispatch_trigger" supabase/migrations/20260510000001_full_schema.sql   # lines 515, 569
# CRON claim: 3 jobs scheduled
rg -n "events-status-poll|events-end-events|account-hard-delete|hard_delete_expired_users" supabase/migrations/20260510000002_cron.sql
# Port claim: config.toml remapped, db still 5432
rg -n "^port" supabase/config.toml          # 54386 / 5432 / 54381 / 54384 / 54388
rg -n '5432|54321|54443' supabase/docker-compose.yml
# schema_test stale (D-04): wide-open policy asserts + "16 migrations"
rg -n "Anyone can (select|insert|update|delete) signup_tracker|wide-open|16 migrations" supabase/tests/schema_test.sql
# supabase-testing one migration behind
diff -rq supabase/migrations supabase-testing/migrations  # Only in supabase: 20260724000002
# APIS dir absent
ls cmd/samay-api-server                     # No such file or directory
# integration_test/ absent (I-01 claim)
ls integration_test                         # No such file or directory
# chat service methods implemented (C-02 claim)
rg -c "Future<void> sendMessage|Future<void> uploadPhoto|Future<void> likePhoto|Future<List<Map<String, dynamic>>> getNotifications|Future<void> markNotificationRead|Future<void> subscribeToMessages" lib/core/services/supabase_service.dart   # 6
```

## Commands run

```bash
git branch --show-current                   # fixes
git log --oneline -12                       # checkpoint history (ffbc8ae = H-01)
git status --short                          # confirmed H-02 uncommitted; docs/to-fix owned by D-03
tools/agent_lock.sh acquire docs/specs/steps/cross-references.md --owner D-02
tools/agent_lock.sh acquire docs/history/phase-00-foundation/2026-08-09_D02-cross-references-refresh.md --owner D-02
# (edits via edit tool — 9 edit operations)
tools/agent_lock.sh release docs/specs/steps/cross-references.md --owner D-02
tools/agent_lock.sh release docs/history/phase-00-foundation/2026-08-09_D02-cross-references-refresh.md --owner D-02
tools/agent_lock.sh list                    # (no locks held)
```

## Issues found (reported, not fixed — out of scope)

- `supabase/config.toml` `[db] port = 5432` + `docker-compose*.yml` 5432/54321/54443 mappings still
  conflict with Juega — I-02/M-01..M-10 scope.
- `supabase-testing/migrations/` missing `20260724000002` (donate fix) — M-10/I-02 parity.
- `supabase/tests/schema_test.sql` asserts pre-fix wide-open signup_tracker policies and covers only
  migrations 01–16 — D-04.
- `test_runner.sh` hardcodes `127.0.0.1:5432` — D-05 scope.
- 23 pre-existing Flutter test failures unchanged (176/23 baseline) — I-47 scope.
