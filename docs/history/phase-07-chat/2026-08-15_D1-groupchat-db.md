# D1-groupchat-db — Group chat DATABASE layer (ISSUE 4, server side)

Date: 2026-08-15 · Agent: `D1-groupchat-db`

## What was built

Database layer making group chats first-class citizens of the chat machinery:

- `supabase/migrations/20260817000002_group_chat_support.sql` (+ byte-identical
  mirror in `supabase-testing/migrations/`):
  - D1a backfill: `chat_participants` rows for every active member of every
    existing `chats` row with `type = 'group'` (ON CONFLICT DO NOTHING).
  - D1b `sync_group_chat_participant` trigger on `group_members`
    (AFTER INSERT OR UPDATE OR DELETE, SECURITY DEFINER, `search_path = ''`):
    active member → participant row; invited/kicked → participant row removed;
    no chat row → no-op.
  - D1c `sync_group_chat_participants_on_chats` trigger on `chats`
    (AFTER INSERT, SECURITY DEFINER): a new group chat backfills ALL active
    members (covers createGroup's groups→members→chats insert order).
  - D1d `get_chat_inbox()` rewrite: peer join branches on `c.type` — group →
    `groups.name` / `peer_id NULL`; direct/event → `user_search_view` peer.
  - D1e RLS tightened to active members only: `messages_read_participant`,
    `messages_insert_participant`, `chats_read_participant` group branches all
    gain `status = 'active'` on the `group_members` subquery.
  - `group_members` added to the `supabase_realtime` publication (idempotent
    DO-block guard — 20260817000001 does not exist in the repo yet; the guard
    skips cleanly if/when it lands).
- `test/opt-010-groups-chat.sh` — live integration test (9 checks; 13 after
  the 2026-08-17 fix round, see below).
- pgTAP: Section 56 in BOTH `supabase/tests/schema_test.sql` and
  `supabase-testing/tests/schema_test.sql` — **landed in the 2026-08-17 fix
  round** (this log's original "Section 56 (plan 442 → 469)" claim was FALSE:
  no Section 56 existed at write time and 469 was never the plan). The real
  numbers, computed from the file: plan 442 → **473** (31 assertions in
  Section 56).

## Decisions made and why

- Sync triggers are SECURITY DEFINER (run as postgres, bypass RLS) — there is
  deliberately NO INSERT policy on `chat_participants`; the triggers are the
  only writers for group chats (create_direct_chat RPC remains the direct-chat
  creator).
- Both triggers REVOKE EXECUTE FROM PUBLIC — Section 48 of the pgTAP suite
  counts anon-EXECUTABLE SD functions and would fail otherwise (OPT-009
  pattern).
- `group_members` realtime publication membership went into THIS migration
  (idempotently) because opt-010 check 8 and pgTAP 56 require it and
  `20260817000001_group_members_realtime.sql` does not exist yet; the
  DO-block guard makes a later central re-apply safe in either order.
- plpgsql branch pattern from OPT-009 (20260816000001): separate `IF TG_OP`
  blocks with explicit RETURNs — plpgsql does not short-circuit.

## Mistakes / gotchas

**MISTAKE**: First draft of the D1b trigger evaluated `NEW.status` in the
DELETE branch (plpgsql evaluates both branches of `IF TG_OP = 'DELETE' OR
NEW...` conditions). Fixed by strict branch-per-TG_OP structure copied from
20260816000001.

**MISTAKE**: pg_publication_tables is NOT exposed via PostgREST (PGRST205) —
opt-010 check 8 cannot be curl-only; it uses `psql` with a `PGURL` env override
(default postgres://postgres:postgres@localhost:54382/postgres).

**GOTCHA**: `supabase db test` CLI path is broken on this stack (TLS) — the
psql fallback is the documented path.

## Fix round 2026-08-17 (agent FixA2-service-db) — F5/F6/F7 + real Section 56

Verification found three DB-layer gaps, closed by
`supabase/migrations/20260817000004_group_chat_fixes.sql` (+ byte-identical
`supabase-testing` mirror):

- **F5**: `get_chat_inbox()` now returns `last_message_recipient_id` (the last
  message's `recipient_id`, from the LATERAL select). `ChatService.decryptInboxRow`
  uses it to skip group DISTRIBUTION rows addressed to another member BEFORE
  any decrypt attempt — null preview, never a bubble (previously the preview
  row carried no recipient_id, so every member tried to open the per-pairwise
  envelope: AEAD failure for non-targets, and the target processed the bundle
  twice).
- **F6**: `accept_friend_request(p_friendship_id)` SECURITY DEFINER RPC
  (search_path = '', REVOKE ALL FROM PUBLIC/anon/service_role, GRANT
  authenticated): addressee-only + pending-only, raises
  `NOT_THE_ADDRESSEE` / `NOT_PENDING`. `UserService.acceptFriendRequest` now
  calls the RPC instead of the direct UPDATE (the old seam let the REQUESTER
  accept their own outbound row — `friendships_update_own` covers both sides).
- **F7**: `enforce_message_cap()` rolling-window DELETE skips
  `recipient_id IS NOT NULL` rows (distribution control rows are not chat
  content); everything else about the trigger is unchanged.

**MISTAKE** (this round): the first draft of Section 56's behavioral cap test
inserted the recipient_id rows NEWEST and set `recipient_id` via a follow-up
UPDATE — the old and new triggers both end at the same row set (the DELETE
picks the oldest rows either way), so the test could not distinguish them.
Fixed: recipient rows FIRST + `recipient_id` set at INSERT time.

Also in this round: `test/opt-010-groups-chat.sh` grew sections 11–13 (inbox
`last_message_recipient_id`, `accept_friend_request` requester-rejected/
addressee-accepted/NOT_PENDING, cap behavioral check in a rolled-back psql
transaction) and the real pgTAP Section 56 landed (plan 442 → 473, both
schema_test files byte-identical). Note: the live DB had never received
`20260817000001`'s `REPLICA IDENTITY FULL` on `group_members` (only the
publication membership, via 0002's guard) — the missing effect was applied
directly for the suite to pass.

## Commands run (reproducibility)

```bash
# RED (pre-migration)
bash test/opt-010-groups-chat.sh   # fails: participants never synced, inbox empty

# Apply migrations (in order) + run opt + pgTAP
psql "postgres://postgres:postgres@localhost:54382/postgres" -v ON_ERROR_STOP=1 -f supabase/migrations/20260817000001_group_members_realtime.sql 2>/dev/null || true  # absent
psql "postgres://postgres:postgres@localhost:54382/postgres" -v ON_ERROR_STOP=1 -f supabase/migrations/20260817000002_group_chat_support.sql
bash test/opt-010-groups-chat.sh
psql "postgres://postgres:postgres@localhost:54382/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql

# Fix round (2026-08-17)
psql "postgres://postgres:postgres@localhost:54382/postgres" -v ON_ERROR_STOP=1 -f supabase/migrations/20260817000004_group_chat_fixes.sql
bash test/opt-010-groups-chat.sh   # 29/29 pass
psql "postgres://postgres:postgres@localhost:54382/postgres" -f supabase/tests/schema_test.sql  # 473 ok / 0 not-ok
```
