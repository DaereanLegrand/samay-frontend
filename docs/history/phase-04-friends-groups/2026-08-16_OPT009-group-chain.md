# 2026-08-16 — OPT-009: Group "Error del servidor" root cause + chain of command

**Scope:** groups (GROU/GLIM), RLS, client services, tests.

---

## What was built

### The bug the user hit
Opening a newly created group showed **"Error del servidor. Intenta de nuevo."**
on every group, even though creation succeeded. Reproduced end-to-end by
running the REAL app (`SamayApp` + real router + real stack) as the group
creator and walking to the detail screen.

**Root cause:** `GroupService.getGroupMembers` selected
`id, user_id, role, joined_at, status, users!inner(username)` — **`group_id`
was missing from the select**, but the freezed `GroupMember.fromJson`
(generated `group_member.g.dart:11`) requires `groupId`:
`json['group_id'] as String` → `null as String` → **TypeError** → the
`groupMembersProvider` went `AsyncError` → the generic `ServerError` message
(`app_error.dart:38`). The raw REST layer was fine — the crash lived in the
model boundary.

**Second bug found while reproducing (same screen):** the `users!inner(username)`
join is own-row-only under `users` RLS (`users_read_own`), so PostgREST dropped
every co-member's row — the member list showed **only the current user**
(verified live: creator saw 1 of 2 rows).

### Fixes (client — `lib/`)
- `group_service.dart getGroupMembers`: select now includes `group_id` and
  joins the security-barrier view aliased as `users`:
  `users:user_search_view!inner(username)` (PostgREST relationship alias —
  response key stays `users`, so the model + screens are untouched). The view
  join returns **all** members' usernames (verified: 2/2 rows for both members).
- `shards_service.dart getGroupContributions` + `event_service.dart
  getEventPromotores`: same `users` → `users:user_search_view` alias swap
  (contributors/promotores lists had the same visibility bug).
- `group_service.dart transferPromotor`: now calls the new `transfer_promotor`
  SECURITY DEFINER RPC (single transaction) instead of the old two-PATCH
  dance (non-atomic, and impossible under the tightened RLS).

### Fixes (server — migration `20260816000001_group_chain_of_command.sql`)
1. **Role-hierarchy RLS** on `group_members` update/delete: only a promotor
   manages promotors; co_promotors manage members/co_promotors; members
   manage nothing. **Before this, a co_promotor could demote AND kick the
   promotor** (reproduced live — the group was left leaderless).
2. **`transfer_promotor(p_group_id, p_new_promotor_id)`** RPC — promotor-only,
   atomic (demote self → promote successor), authenticated-only.
3. **`reassign_group_promotor`** triggers (group_members DELETE of a promotor
   row; users UPDATE on banned_at/deleted_at transitions): leadership
   auto-passes to a random **co_promotor**, else a random **active** member.
   Banned/soft-deleted promotors are demoted to `member` (unban restores a
   member, not leadership). Invited members are never promoted. Verified:
   promotor leaves → successor promoted, group survives; promotor banned →
   co_promotor promoted; promotor account deleted → active member promoted.

### Platform (macOS test harness)
`macos/Runner/DebugProfile.entitlements` gained
`com.apple.security.network.client` — the sandbox blocked ALL outbound
network, so live-stack integration tests could never run on macOS (the
repo's own integration device). Hermetic flows unaffected.

### Tests
- **`test/opt-009-groups-chain.sh`** (live, auto-registered by
  `run_all_backend.sh` — 15 checks): member-list visibility via
  user_search_view, chain-of-command matrix, transfer RPC, ban + delete
  leadership handover. **RED-proven before the fixes** (co_promotor demoted/
  kicked the promotor; RPC missing), now 15/15, idempotent across runs.
- **`test/services/group_service_test.dart`**: select-string pin (`group_id` +
  `users:user_search_view!inner`) and `transfer_promotor` RPC contract.
- **`test/core/repositories/groups_repository_test.dart`**: co-member
  usernames resolve through the view shape; a row WITHOUT `group_id` fails
  loudly (pins the root-cause requirement).
- **pgTAP**: new Section 55 (14 assertions, plan 428 → **442**), both stacks;
  header updated through 20260816000001.

## Validation (all green)
- `flutter test` **2315/2315** · `dart analyze` **0 issues**
- `go test ./...` green (5 packages)
- pgTAP **442/442** (psql fallback; the `supabase db test --db-url` CLI path
  fails on TLS with this stack — pre-existing, SELFHOSTING §3.2 documents the
  psql fallback)
- `bash test/run_all_backend.sh` **9/9** (opt-001..009)
- opt-005/007/008 static gates, `tools/check_ports.sh --strict`,
  `make secrets-check` — all PASS
- Live app end-to-end: real app now renders the group (error gone, all three
  detail providers AsyncData)

## Decisions
- Chain of command: co_promotor may promote/demote/kick members **and**
  co_promotors (the existing R17 sheet surface), but never the promotor;
  only a promotor creates promotors.
- Successor pick is **random** (per user request "alguien random o
  co-admin"), co_promotor preferred over plain members; invited members
  never receive leadership.
- Join alias `users:user_search_view` keeps every existing consumer (model
  getter, screens' raw-map reads) working — no model/screen churn.

## MISTAKE blocks
- **MISTAKE (opt-test leftovers):** the opt-test's fixed UUIDs + cleanup that
  only removed auth users left `public.users` rows behind (auth deletion does
  NOT cascade to `public.users`; the users DELETE is FK-blocked while the
  test's member rows exist). First rerun failed with `23505 username` then
  cascading FKs. Fixed: per-run random UUIDs + dependency-ordered cleanup
  (members → chats → groups → users → auth users). Re-verified 3/3 runs.
- **MISTAKE (trigger portability):** the first `reassign_group_promotor`
  draft used `IF TG_OP = 'DELETE' AND OLD.role = 'promotor'` — plpgsql does
  NOT short-circuit AND/OR, so firing on a `users` row evaluated
  `OLD.role` → "record old has no field role". Fixed with a DELETE-only
  branch (nested IF).
- **MISTAKE (plpgsql FOR loop):** `FOR gid IN SELECT ...` needs the loop
  variable declared (`DECLARE gid uuid;`) or the function fails to compile.

## Commands run (reproducibility)
```bash
# reproduce (root cause + fix proof): live app against the local stack
ANON_KEY=… SERVICE_KEY=… flutter test integration_test/scratch_live_app_repro_test.dart -d macos --dart-define=…

# chain-of-command RED before fix: 5/15 → after fix 15/15 (×3 idempotent)
bash test/opt-009-groups-chain.sh

# apply migration (both stacks mirrored; testing stack is the running one)
psql "postgres://postgres:postgres@localhost:54382/postgres" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20260816000001_group_chain_of_command.sql

# validation
flutter test            # 2315/2315
dart analyze            # 0
go test ./...           # green
psql "postgres://postgres:postgres@localhost:54382/postgres" -v ON_ERROR_STOP=1 \
  -f supabase/tests/schema_test.sql    # 442/442
bash test/run_all_backend.sh           # 9/9
tools/check_ports.sh --strict && make secrets-check
```

## Files
- `supabase/migrations/20260816000001_group_chain_of_command.sql` (new) +
  byte-identical `supabase-testing/` mirror
- `test/opt-009-groups-chain.sh` (new)
- `lib/core/services/group_service.dart`, `shards_service.dart`,
  `event_service.dart`
- `test/services/group_service_test.dart`,
  `test/core/repositories/groups_repository_test.dart`
- `supabase/tests/schema_test.sql` + `supabase-testing/tests/schema_test.sql`
  (Section 55, plan 442, header)
- `macos/Runner/DebugProfile.entitlements` (network.client — live-stack tests
  on macOS)
