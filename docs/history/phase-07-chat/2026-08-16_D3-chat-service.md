# 2026-08-16 — D3-chat-service: Group chat E2EE service layer (ISSUE 4)

**Agent:** D3-chat-service · **Scope:** service/repository/provider layer + one
additive migration. UI screens are the NEXT round (UI agent owns
`lib/features/chat/screens/*`, `group_detail_screen.dart`,
`lib/features/groups/screens/*`).

## What was built

- `supabase/migrations/20260817000003_group_chat_distribution.sql` (+
  byte-identical `supabase-testing/` mirror): `messages.recipient_id uuid NULL`
  — the sender-key DISTRIBUTION addressing column (per-pairwise-session bundle
  rows carry the target member). No RLS change (the envelope + client-side skip
  provide the privacy). Applied to the live 54382 stack.
- `ChatService` group routing (ISSUE 4 / D3b), gated on the new optional
  `GroupE2eeCipher? groupCipher` constructor param / `groupE2eeEnabled` getter:
  - `_chatInfoCache` (type + reference_id per chat, `SELECT type, reference_id
    FROM chats WHERE id = …`), `getChatReferenceId(String chatId)` accessor.
  - `_rosterCache` + rekey-on-change: `_sendGroupMessage` fetches the ACTIVE
    roster from `chat_participants` (documented source: D1's triggers keep it
    equal to active `group_members`; RLS `cp_read_participant`), compares to
    the cached roster; any diff → `wipeGroupKeys` + re-distribute to every
    other member; no diff → lazy heal via `membersMissingSenderKey`.
  - Distribution: rows with `recipient_id` = target, content = REAL pairwise
    X3DH init envelope (`E2eeSession(chatId: 'g:<chatId>:<peer>')` namespace)
    of the bundle JSON, inserted BEFORE the single 0x03 message row.
  - `_decryptGroupRow`: recipient_id != me → silent skip; 0x03 → groupCipher
    (plaintext → bubble + `_cachePlaintext`, dropped → hidden, failed →
    bubble); 0x01/0x02 → pairwise decrypt → `processSenderKeyBundle` → hidden.
  - `peerNeedsRekey` returns false for groups; `_deleteUndecryptable` skips
    group chats (undecryptable group rows STAY — the rekey heals).
  - `loadMessages` select gained `recipient_id`.
- `chat_providers.dart` (D3c): `chatE2eeServiceProvider` wires
  `GroupE2eeCipher(keyStore:…, sessionStore:…)`. No other provider changes.
- `GroupService.getGroupChatId(String groupId)` (D3d) + `GroupsRepository`
  passthrough: `chats.id` of the type='group'/reference_id row — the UI agent
  opens the group's E2EE chat with it.
- Tests: 8 group tests in `test/services/chat_service_test.dart` (mock client +
  FAKE `GroupE2eeCipher` via mocktail, real pairwise crypto), 3
  `getGroupChatId` tests in `group_service_test.dart`, 2 passthrough tests in
  `groups_repository_test.dart`, opt-010 section 10 (4 new assertions), and
  `integration_test/group_chat_flow_test.dart` (live-stack, skip-if-down).

## Decisions

- **Roster source: `chat_participants`** (one query, same seam
  `_resolvePeerUserId` uses; the D1 sync triggers guarantee it mirrors ACTIVE
  `group_members`; readable via `cp_read_participant`). Documented in code.
- **Roster-change semantics:** ANY roster diff → `wipeGroupKeys` (new epoch;
  a removed member's chain copies are dead) → `membersMissingSenderKey`
  reports everyone again (registry cleared) → the OWN chain is minted fresh
  (via `senderKeyBundleJson`) and re-distributed to every other active member.
- **Group routing gates on `groupCipher != null`** — without the dependency
  the service is byte-identical to before (all pre-existing 1:1 tests pass
  unchanged; the chats query is never issued).
- **Pairwise distribution namespace:** synthetic store key
  `g:<chatId>:<peerUserId>` inside the existing E2eeSessionStore (key-agnostic
  store; `sessionIndex` has no consumers). The recipient resolves the session
  by the row's sender_id. The real chatId namespace is 1:1-only — pinned by a
  test asserting no session under the real chatId after a group send.
- **Own-echo:** own group rows serve from the outbox; after a restart they are
  un-decryptable by construction (one-way sender-key chain) and drop silently.
- **Inbox preview:** `get_chat_inbox` does not select `recipient_id` — a
  distribution row as last message yields a null preview (silent either way);
  not changing the RPC keeps the migration minimal (the task allows the column
  only).

## MISTAKE-1

Dart field promotion on `_groupCipher!`: the analyzer flagged the 2nd+ `!` per
method as unnecessary (promotion after the first demotion) while the 1st was
required — sed-removing ALL `!` produced 8 errors. Fixed by hoisting
`final cipher = _groupCipher!;` at the top of the two methods (explicit
non-null local, self-documenting). Lesson: hoist non-null locals instead of
scattering `!`.

## MISTAKE-2

Test-harness compile errors (RED iteration): `FutureOr` needed `dart:async`;
`_MockRealtimeChannel` is `MockRealtimeChannel` in resolving_builder.dart;
`decryptResults` lives on the party, not the mock; `_makeSenderKeyEnvelope` is
async so `late final String messageEnvelope = await…` is illegal — the
envelope is now computed once in `setUp` and passed to the party constructors.

## Commands

```
# RED proof (all three fail to compile — behavior missing)
flutter test test/services/chat_service_test.dart test/services/group_service_test.dart test/core/repositories/groups_repository_test.dart

# GREEN: targeted suites
flutter test test/services/chat_service_test.dart test/services/group_service_test.dart test/core/repositories/groups_repository_test.dart          # 74 pass
flutter test test/services test/core/repositories test/features/chat                                 # 459 pass

# analyze
dart analyze lib/core/services/chat_service.dart lib/core/services/group_service.dart lib/core/repositories/groups_repository.dart lib/features/chat/providers/chat_providers.dart test/services/chat_service_test.dart test/services/group_service_test.dart test/core/repositories/groups_repository_test.dart   # 0 issues
dart analyze lib test integration_test        # 0 issues

# DB layer
psql "postgres://postgres:postgres@localhost:54382/postgres" -v ON_ERROR_STOP=1 -f supabase/migrations/20260817000003_group_chat_distribution.sql
bash test/opt-010-groups-chat.sh              # 24/24 (20 pre-existing + 4 new)

# integration flow (compile-only — device run is the verifier's)
dart analyze integration_test/group_chat_flow_test.dart   # 0 issues
```

## Validation

- 1:1 behavior untouched: `test/features/chat/chat_e2ee_test.dart` (the two-
  party 1:1 harness) and every pre-existing test in the touched files pass
  unchanged (459 in the three dirs).
- opt-010: 24/24. Analyze: 0 issues. Group tests cover send ordering, roster
  shrink rekey, load/subscribe/inbox routing, namespace pinning, single-member
  groups.
- BLOCKED (reported, not fatal): `supabase/tests/schema_test.sql` +
  `supabase-testing/tests/schema_test.sql` are held by D1-groupchat-db (locks
  from 04:12:53Z, still held at completion). The additive recipient_id pgTAP
  checks are OPTIONAL per the assignment; opt-010 section 10 covers the DB
  contract instead. The migration is applied to the live stack; the
  supabase-testing mirror ships but its stack was not migrated.
