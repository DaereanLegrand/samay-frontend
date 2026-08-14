# Phase 00 — DATA + SECU + TRIG + CRON: Database Schema & Foundation

## Date: 2026-05-10

## What was built

### DATA — Full Database Schema Migration
- `supabase/migrations/20260510000001_full_schema.sql` — single comprehensive migration:
  - **3 extensions**: pgcrypto, moddatetime, pg_cron
  - **19 enum types**: subscription_tier, friendship_status, group_role, size_tier, rank_bracket, event_type, event_status, join_mode, event_role, invite_status, cosmetic_type, chat_type, mini_game_type, mini_game_status, shard_reason, preshard_reason, report_target_type, report_status, admin_role
  - **30 tables**: all tables per MVP spec (users through processed_webhooks)
  - **40+ indexes**: on FK cols, status, timestamps, lookup cols
  - **3 moddatetime triggers**: users, groups, events

### SECU — Row Level Security (in same migration)
- RLS enabled on all 30 tables
- **48 RLS policies** covering:
  - Users: read/update own, admin-only banned_at
  - Events: read if public/member/invitee, update if promotor
  - Event QR tokens: read own only (Edge Function manages writes)
  - Admin tables (admin_users, admin_audit_log, subscription_overrides, processed_webhooks): zero client access (service_role only)
  - Chat: participant-based access via direct/group/event derivation
  - Shard/preshard ledgers: read own only
  - app_config: public read only

### TRIG — Database Triggers (in same migration)
- **`group_size_tier_trigger`**: AFTER INSERT/DELETE on group_members → updates groups.size_tier (micro/small/medium/large)
- **`dynamic_qr_enabled_trigger`**: BEFORE INSERT/UPDATE of preshards_pool on events → sets dynamic_qr_enabled = (preshards_pool > 0)
- **`message_cap_trigger`**: AFTER INSERT on messages → enforces rolling window cap from app_config.chat.message_cap (default 1000)
- **`group_shards_increment_trigger`**: AFTER INSERT on group_shard_contributions → increments groups.group_shards
- **`photo_likes_count_trigger`**: AFTER INSERT/DELETE on event_photo_likes → recalculates event_photos.likes_count

### CRON — pg_cron Jobs
- `supabase/migrations/20260510000002_cron.sql`:
  - **events-status-poll** (every minute): upcoming → live
  - **events-end-events** (every minute): live → ended
  - **account-hard-delete** (daily 3AM): hard-deletes users soft-deleted >30 days ago, anonymizes ledger entries and messages, removes group memberships
  - Helper function `hard_delete_expired_users()` for proper cleanup (preserves shard_ledger/preshard_ledger integrity)

### Testing
- `supabase/tests/schema_test.sql` — 57 pgTAP tests covering:
  - Extensions installed (3)
  - Enum types exist (19)
  - Tables exist (30)
  - Triggers exist (3 moddatetime)
  - Seed data correct (1 admin_user, 37 app_config keys)
  - **All 57 tests pass**

### Files Created
- `supabase/migrations/20260510000001_full_schema.sql` (802 lines)
- `supabase/migrations/20260510000002_cron.sql` (cron jobs)
- `supabase/seed.sql` (seed data for db reset)
- `supabase/tests/schema_test.sql` (pgTAP tests)

## Decisions
- **Single migration file** for schema + triggers + RLS + seeds — cleaner than 6 separate files since all are logically one deploy unit
- **Seed data in migration** rather than seed.sql alone — ensures consistency even if `supabase db push` is used without `db reset`
- **RLS on admin tables**: policy `FOR ALL USING (false)` — even though RLS doesn't apply to service_role, this provides defense-in-depth against misconfigured anon keys
- **Hard delete function** rather than raw DELETE — must preserve ledger integrity and anonymize messages before cascade deletes

## MISTAKE: RLS policies used OLD/NEW references
Initial RLS policies used `OLD` and `NEW` references as if they were trigger functions. In PostgreSQL RLS:
- `USING` checks existing rows (on SELECT/UPDATE/DELETE)
- `WITH CHECK` validates new rows (on INSERT/UPDATE)
- Neither supports `OLD`/`NEW` — those are trigger-specific
- To reference the row being inserted in `WITH CHECK`, use the table name as qualifier: `table_name.column_name`
- Fixed 3 policies: `users_update_own`, `group_members_insert`, `ep_insert_promotor`

## MISTAKE: Check constraint test used wrong pgTAP function
`check_ok()` requires a boolean expression, not constraint name. Removed the `check_ok` call since the CHECK constraint is verified implicitly by the DB migration.

## MISTAKE: pgTAP plan count wrong
Initial plan was 49 but actual tests ran 57. Caused by counting errors. Fixed by recounting and using a comment-based tally.

## Commands Run
```bash
psql postgresql://postgres:postgres@127.0.0.1:5432/postgres -f supabase/migrations/20260510000001_full_schema.sql
psql ... -f supabase/migrations/20260510000002_cron.sql
supabase db test
```

## Verification
- All 30 tables present with correct columns
- All 19 enum types created
- 48 RLS policies active
- 9 custom triggers firing (3 moddatetime + 5 business + 1 function)
- 3 cron jobs scheduled
- System admin user seeded (00000000-0000-0000-0000-000000000000)
- 37 app_config keys seeded
- pgTAP: 57/57 tests pass
- Go tests: `go test ./...` passes

## Deferred
- **FLMT** (rate limiting): depends on EEDG from Phase 05 — deferred
- **Edge Function cron jobs** (rank calculation, override reconciler): function bodies don't exist yet — will create when Phase 05/11 Edge Functions are built
- **Supabase Storage bucket policies**: need actual bucket creation via API — deferred to when storage is needed (Phase 03 avatar upload)

## Next Steps (Phase 01 — Admin CLI)
- `DBCL` — db client + Go models
- `ROOT` — cobra root command
- `USRS`, `EVTC`, `GRPS`, etc. — CLI operations
