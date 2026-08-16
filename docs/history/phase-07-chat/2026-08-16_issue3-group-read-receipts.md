# 2026-08-16 — group read receipts: per-member message_reads + UI status/info (ISSUE: blue checks + long-press status)

Agent: `orchestrator-issue3` · Phase 07 (chat) + Phase 00 (DB) · Working tree only.

## Symptoms (user report)

1. In a GROUP chat the sender sees BLUE double checks although not all members
   have read the message.
2. Long-press must expose a message-status action (sent / arrived / read) for
   OWN messages (information only available for own messages).

## Root cause (diagnosed)

The 1:1 read-receipt model (`messages.read_at` + `mark_messages_read`,
20260815000005) cannot express per-member reads: ANY member reading the chat
stamps `read_at` on every message from every other sender, so the FIRST reader
made every sender's message look read-by-everyone. There was no per-member read
tracking and no message-status UI.

## Fix (RED → GREEN)

### DB (migration `20260817000006_group_read_receipts.sql`, mirrored 1:1)

- **`message_reads(message_id, user_id, read_at)`** — PK(message_id, user_id),
  FK ON DELETE CASCADE (delete-for-everyone / cap-prune stay consistent),
  RLS ENABLE + FORCE (I-31 posture), policies:
  `message_reads_insert_own` (own-row INSERT gated on the message's chat
  participation — the RPC is the primary write path) +
  `message_reads_select_participant` (every participant sees who read what;
  also gates realtime delivery of INSERT events).
- **`mark_group_messages_read(p_chat_id)`** — SECURITY DEFINER,
  `search_path=''`, active-member-gated; inserts the caller's receipt on every
  message that is NOT theirs and NOT a distribution row (`recipient_id IS
  NULL`); `ON CONFLICT DO NOTHING` idempotent. The 1:1 `mark_messages_read`/
  `read_at` path is untouched (client routes by chat type).

### Client

- `ChatService.markMessagesRead` routes by chat type (group →
  `mark_group_messages_read`; direct → `mark_messages_read`).
- `loadMessages` selects `message_reads(user_id, read_at)` (embedded) — the
  thread renders "read by N of M" from it.
- `ChatService.subscribeToGroupMessageReads` + `ChatRepository` passthrough —
  realtime `message-reads:<chatId>` INSERT channel; the thread merges each
  (message_id, user_id, read_at) receipt live.
- `ChatMessagesState`: `readersOf`, `isReadByAll(row, otherMembers)` (blue ONLY
  when every other active member read; unknown/empty roster is conservative —
  never blue), `markMessageRead` merge (dedupe).
- `ChatThreadView`: group mode subscribes the reads channel; the own-bubble
  ticks flip blue only when all other members read; long-press on OWN committed
  messages gains "Información del mensaje" → sheet: Enviado HH:mm + (group)
  "Leído por N de M" with reader names / (1:1) "Leído HH:mm" / "No leído".
  Peer messages: no info action (own-only by design).
- ARB: 5 new keys (es + en, placeholders declared).

## Tests (RED → GREEN)

- pgTAP Section 57 (18 assertions; plan 476 → **494**, both stacks, byte-
  identical): table/columns/PK/FK/RLS/FORCE/policies + publication membership +
  RPC hygiene (definer, search_path, grants). RED proven before the migration
  (7 failures, table missing).
- `test/opt-011-groups-reads.sh` (new, 15 checks): mark → exactly one receipt,
  idempotent, self-stamp denied, sender+member see reads, non-member denied
  (RPC + RLS), group RPC never touches read_at, 1:1 read_at path unchanged,
  distribution rows never marked, anon denied. RED proven (10/14 fail with the
  contract dropped), GREEN 15/15; `run_all_backend.sh` 11/11.
- Dart: 5 state tests (readersOf/isReadByAll roster-set semantics/dedupe/
  leaver edge/markMessageRead), 3 service tests (type routing, embedded reads
  pass-through, channel), 4 widget tests (group blue-only-when-all,
  conservative empty roster, info sheet with names, peer has no info action).
  Full suite **2435/2435** (2414 + 7 I1 + 2 I2 + 12 I3), analyze 0, `make
  check` PASS, `go test` green.

## Verifier fix round (2026-08-17 — independent review findings, all closed)

| Finding | Fix |
|---|---|
| pgTAP plan off-by-one (Section 57 = 18 assertions, incl. `fk_ok`; the meta-guard regex undercounted it) | plan **494** in both stacks; the guard regexes (`qr_rpc_migration_test.dart`, `minigame_rpc_migration_test.dart`) extended with the `fk_ok\|pk_ok` suffix family |
| `message_reads` NOT in the `supabase_realtime` publication — the live blue-flip channel never fired (ticks only updated on reload) | idempotent `ALTER PUBLICATION ... ADD TABLE public.message_reads` (DO-block guard, 20260817000001 pattern) + pgTAP publication assertion + live verification (`pg_publication_tables` shows the row) |
| `message_reads_insert_own` allowed a member to SELF-STAMP a receipt on their own message (inflated "read by N of M") | policy gains `m.sender_id <> auth.uid()`; opt-011 check 1b pins the denial |
| `isReadByAll` counted readers instead of requiring the CURRENT roster ids — a departed member's stale receipt could false-blue | `isReadByAll(row, Set<String> otherMemberIds)` — readers must be a SUPERSET of the current other members; leaver-edge regression test added |

## Decisions made and why

- **Per-member rows over a readers array column** — a joinable, RLS-able,
  realtime-able table; arrays would break RLS granularity and FK cascade.
- **Blue ticks = ALL current other members** (WhatsApp semantics) — verified as
  a roster-id SET, so a leaver's stale receipt can never fake read-by-everyone;
  unknown roster → grey (conservative).
- **Info sheet own-only** — the user's explicit requirement; peer read-state is
  not this device's information.
- **Distribution rows never marked** — control rows are not chat content.

## MISTAKE (meta guards)

The pgTAP plan-consistency guards (`qr_rpc_migration_test.dart`) caught a plan
off-by-one (493 vs actual 492 — the section has 16 assertions, not 17) and the
l10n parity test caught missing `placeholders:` metadata for the
`chatMessageInfoReadBy` template. Both fixed before the full suite went green —
the guards did their job.

## Commands run

```bash
# RED (DB): Section 57 + opt-011 written first, migration NOT applied
PGPASSWORD=postgres psql ... -f supabase/tests/schema_test.sql   # 7 not ok
bash test/opt-011-groups-reads.sh                                # 10 FAIL

# GREEN (DB)
PGPASSWORD=postgres psql ... -f supabase/migrations/20260817000006_group_read_receipts.sql
PGPASSWORD=postgres psql ... -f supabase/tests/schema_test.sql   # 494/494 ok, 0 fail
bash test/opt-011-groups-reads.sh                                # 15/15
bash test/run_all_backend.sh                                     # 11/11

# GREEN (client)
dart analyze                                                     # 0 issues
flutter test                                                     # 2435/2435
make check                                                       # PASS (exit 0)
go test ./...                                                    # green

# Verifier fix round
PGPASSWORD=postgres psql ... -c "DROP POLICY ...; DROP TABLE ... CASCADE; DROP FUNCTION ...;"
PGPASSWORD=postgres psql ... -f supabase/migrations/20260817000006_group_read_receipts.sql   # re-applied (policy fix + publication)
bash test/opt-011-groups-reads.sh                                # 15/15 (incl. self-stamp denial)
flutter test                                                     # 2435/2435
```

Locks: migration x2, schema_test x2, opt-011, chat_service.dart, chat_providers.dart,
chat_thread_view.dart, chat_repository.dart, ARB x2, chat_state_test.dart,
chat_screen_test.dart, flow_test.dart (owner `orchestrator-issue3`) — held for
the verifier pass.

Follow-up: independent verifier + security review in progress.
