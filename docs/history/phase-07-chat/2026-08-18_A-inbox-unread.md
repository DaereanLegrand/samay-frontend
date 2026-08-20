# A-inbox-unread — fix inbox unread_count for E2EE control rows (2026-08-18)

Agent: `A-inbox-unread` · Phase 07 (chat) · No commits (working tree only).

## What was built

Fixed the home-screen chat-button badge inflation: `public.get_chat_inbox()`
counted EVERY row from others newer than the read watermark toward
`unread_count` — including group-chat sender-key DISTRIBUTION rows and
KEY-REQUEST rows (`recipient_id IS NOT NULL`). The E2EE client inserts these
control rows with NO user-visible message (key distribution, roster-change
rekey, key-request retries), so group chats showed a phantom unread badge.
Same class F7 already exempts from the message-cap rolling window
(`enforce_message_cap` skips `recipient_id IS NOT NULL`); the inbox count was
never given that exemption.

### Migration `supabase/migrations/20260818000001_fix_inbox_unread.sql` (+ byte-identical `supabase-testing/` mirror)

- `CREATE OR REPLACE FUNCTION public.get_chat_inbox()` — signature /
  `RETURNS TABLE` UNCHANGED (no `DROP FUNCTION`; OUT params identical to
  `20260817000004`'s). Only the body changed:
  - **unread_count subquery**: added `AND m.recipient_id IS NULL` — only real
    content rows from others newer than the watermark count toward the badge.
  - **last-message `LEFT JOIN LATERAL`**: added
    `AND messages.recipient_id IS NULL` — the inbox preview is now the last
    REAL content message, not a distribution envelope (a control envelope as
    preview was meaningless/undecryptable for non-targets).
- Re-issued the same `REVOKE`/`GRANT EXECUTE ... TO authenticated` lines as in
  `20260817000004_group_chat_fixes.sql`.
- Header comment explains the fix, mirroring the 0004 style.

### Opt-test `test/opt-010-groups-chat.sh`

- New **TEST 14 "Inbox unread_count ignores sender-key distribution rows"**:
  A + B reset watermarks via `mark_chat_read` → A inserts ONE content row
  (`recipient_id` NULL) + ONE distribution row (`recipient_id` = B), both
  after the watermark → asserts B's `unread_count` == 1 (content ONLY, not 2),
  A's own == 0 (sender-excluded), B's preview is the last content message,
  and B `mark_chat_read` → 0.
- **TEST 11 updated** (pre-existing case): since the preview now skips
  distribution rows, the inbox preview is the last real content message
  (`MSG_A`, `last_message_recipient_id` NULL) instead of the distribution row
  (`DIST_MSG`, `recipient_id` = B). The `last_message_recipient_id` column
  remains in the RETURNS TABLE for API compatibility but is now always NULL
  (content rows carry no recipient). Updated the section header + assertion
  to the new contract.

## RED → GREEN

1. **RED**: added TEST 14 only, ran `bash test/opt-010-groups-chat.sh` →
   **2 new failures for the right reason**: `B's unread_count is 2 (expected
   1)` and `Inbox preview is not the last content message` (preview was the
   distribution row). All pre-existing cases passed (33 pass / 2 fail).
2. **GREEN**: wrote + applied `20260818000001` to the running stack, updated
   TEST 11 to the new preview contract, re-ran → **35 pass / 0 fail, exit 0**.

## Decisions

- **`recipient_id IS NULL` is the control-row discriminator**, exactly like
  F7's cap exemption — one consistent rule for "what is a user-visible
  message" (control rows = bundles/requests, invisible to the badge).
- **No `DROP FUNCTION`**: the signature didn't change, so `CREATE OR REPLACE`
  suffices (Postgres forbids changing OUT params via OR REPLACE — that was
  0004/F5's reason for dropping; not needed here).
- **Single-file psql apply instead of `supabase/migrate.sh`**: migrate.sh
  re-runs ALL migrations, and the base `20260510000001_full_schema.sql` is
  NOT idempotent (plain `CREATE TABLE`, no `IF NOT EXISTS`) → it would abort
  under `ON_ERROR_STOP=1` against an already-migrated DB. Applied only the
  new file with the same psql invocation the Makefile reset loop uses
  (`PGPASSWORD=postgres psql -h localhost -p 54382 ... -f <file>`). No ports,
  config.toml, or compose files touched; no full reset (another agent may be
  running against the live stack).
- **TEST 11 behavioral change is deliberate**: F5's preview-targeting column
  is now vestigial (always NULL) — the client preview is always a real
  content envelope, so decryption is always attempted on a real message.
  Kept the column for API compatibility (RETURNS TABLE untouched).

## Commands run

```bash
tools/agent_lock.sh acquire test/opt-010-groups-chat.sh --owner A-inbox-unread
tools/agent_lock.sh acquire supabase/migrations/20260818000001_fix_inbox_unread.sql --owner A-inbox-unread
tools/agent_lock.sh acquire supabase-testing/migrations/20260818000001_fix_inbox_unread.sql --owner A-inbox-unread
tools/agent_lock.sh acquire docs/history/phase-07-chat/2026-08-18_A-inbox-unread.md --owner A-inbox-unread
bash test/opt-010-groups-chat.sh                      # RED: 33 pass / 2 fail (new case, right reason)
cp supabase/migrations/20260818000001_fix_inbox_unread.sql supabase-testing/migrations/
cmp supabase/migrations/20260818000001_fix_inbox_unread.sql supabase-testing/migrations/20260818000001_fix_inbox_unread.sql  # BYTE-IDENTICAL
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/migrations/20260818000001_fix_inbox_unread.sql
bash test/opt-010-groups-chat.sh                      # GREEN: 35 pass / 0 fail, exit 0
tools/agent_lock.sh release test/opt-010-groups-chat.sh --owner A-inbox-unread
tools/agent_lock.sh release supabase/migrations/20260818000001_fix_inbox_unread.sql --owner A-inbox-unread
tools/agent_lock.sh release supabase-testing/migrations/20260818000001_fix_inbox_unread.sql --owner A-inbox-unread
tools/agent_lock.sh release docs/history/phase-07-chat/2026-08-18_A-inbox-unread.md --owner A-inbox-unread
```

## Pre-existing issues found (NOT fixed — out of scope)

- `supabase/migrate.sh` cannot be re-run against an already-migrated stack:
  the base `20260510000001_full_schema.sql` is non-idempotent (plain
  `CREATE TABLE` without `IF NOT EXISTS`) and aborts under `ON_ERROR_STOP=1`.
  The Makefile `supabase-docker-reset` works because it drops the volume
  first; migrate.sh does not.
- Several unrelated uncommitted working-tree changes exist in the repo
  (Dart lib/test/theme files from other agents) — untouched.