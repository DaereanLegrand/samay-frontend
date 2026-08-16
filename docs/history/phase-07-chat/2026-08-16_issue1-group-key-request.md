# 2026-08-16 — group key-request retry protocol: missing-chain deadlock heal (ISSUE: messages not arriving to all members)

Agent: `orchestrator-issue1` · Phase 07 (chat) · Working tree only (no commits).

## Symptom (user report)

Group "Grupito" (4 users, 4 devices): when tester3 sends a message it arrives to
everyone EXCEPT tester. It "resolved after some time" — consistent with a
synchronization/key-exchange failure that heals only when a later roster change
triggers a rekey.

## Root cause (diagnosed in code, reproduced in tests)

The sender's distribution registry marks a member as **distributed** as soon as
the bundle-row INSERT succeeds. If the receiver's device never actually processed
that bundle — stale pairwise identity after a reinstall/identity change (the
init-drop class fixed 2026-08-15), an RLS-timing miss at invite-accept (D1e:
invited users cannot read the chat, so the bundle row was invisible until the
membership flipped), or a dropped init envelope — the receiver has NO sender-key
record for that sender. Every type-0x03 message from that sender then drops
(NoSession, `E2eeDecryptResult.dropped`). The sender never re-distributes
(the member is not "missing" in its registry) → deadlock. The heal only happens
when a roster change (`wipeGroupKeys` + fresh epoch) forces a full
re-distribution — "resolved after some time".

## Fix (RED → GREEN)

The Signal retry-request analogue, 2026-08-17 protocol:

- `lib/crypto/constants.dart` — `e2eeGroupKeyRequestVersion` (1) +
  `e2eeGroupKeyRequestKind` (`samay.group_key_request`).
- `lib/crypto/interfaces.dart` — `E2eeDecryptResult.dropped({missingChain})`:
  the drop class that IS requestable (no sender-key record / stale-identity
  record). Replays, out-of-order and gap-beyond-cap drops stay unrequestable.
- `lib/crypto/group_cipher.dart`:
  - `isSenderKeyRequest(String)` — kind-marker check.
  - `senderKeyRequestJson({groupChatId, groupId, missingSenderUserId})` — the
    request payload (the requester's identity is the row's RLS-bound
    `sender_id`, never a self-attested field — the K1 lesson).
  - `senderKeyRequestTarget({json, groupChatId, groupId})` — validates the
    request against the chat/group and returns the missing sender id.
  - `unmarkSenderKeyDistributed({groupChatId, senderUserId, memberIds})` —
    removes members from the sender's `distributed_to` set so
    `membersMissingSenderKey` reports them again.
  - `decrypt` marks `missingChain: true` on the no-record and identity-mismatch
    drops.
- `lib/core/services/chat_service.dart`:
  - `_requestGroupSenderKey(chatId, missingSenderId, groupId)` — throttled per
    (chat, sender) (`groupKeyRequestCooldown` = 1 min); the request JSON rides
    the plaintext of the pairwise session and lands as a `recipient_id`-
    addressed `messages` row (never a bubble on any device; server sees
    ciphertext only). Fires from `_decryptGroupRow` when a 0x03 drop carries
    `missingChain`.
  - `_handleSenderKeyRequest(...)` — the chain owner un-marks the requester and
    re-distributes its bundle IMMEDIATELY (no waiting for the next message or a
    roster change). Requests for another member's chain are ignored
    (cross-chain guard).
  - `_distributeBundleToMissing(...)` — the per-member distribution loop
    extracted from `_sendGroupMessage` (H1 distribution contract preserved:
    per-member try/catch, mark-after-successful-insert) and reused by the
    request handler.

## Tests (RED → GREEN)

- `test/crypto/group_cipher_test.dart` — new "key-request retry protocol" group
  (3 tests): marker routing (request vs bundle vs junk), round-trip + foreign
  group/chat rejection, `unmarkSenderKeyDistributed` registry semantics.
- `test/services/chat_service_test.dart` — 4 tests:
  1. a missingChain 0x03 drop fires EXACTLY ONE request row addressed to the
     sender (throttled; rows hidden);
  2. a pairwise row whose plaintext is a request for MY chain un-marks the
     requester + re-distributes immediately;
  3. a request for ANOTHER member's chain is ignored (no unmark, no
     re-distribution);
  4. **end-to-end deadlock heal with REAL ciphers on both sides**: healthy
     round 1 → bob's device loses the chain (wipe) → alice's next send produces
     NO distribution (deadlock pinned) → bob's load drops the message and
     requests → alice's load re-distributes → bob heals → the NEXT message
     decrypts.

Validation: `flutter test` **2421/2421** (baseline 2414 + 7), `dart analyze`
0 issues (touched dirs + full repo).

## Decisions made and why

- **Retry request over "re-distribute on every send"** — the sender cannot know
  a member failed to process a bundle; only the receiver knows it is missing the
  chain. Request rows are E2EE (pairwise envelope), RLS-gated (active members
  only), throttled, and capped by the existing message-cap trigger exemption for
  `recipient_id` rows (20260817000004 F7).
- **missingChain only for no-record + stale-identity drops** — replays/gaps heal
  by themselves; requesting on them would spam.
- **Immediate re-distribution on request** — the user-visible symptom
  ("arrives to all except tester, resolved later") must resolve promptly, not on
  the sender's next message.

## MISTAKE (test-harness, fixed)

The request tests initially (a) verified `markSenderKeyDistributed` exactly once
— but round-1's send already marks the member, so the request-heal mark is the
second call (fixed to `called(2)`); (b) used `thenReturn(Future.value(...))`,
which mocktail rejects for futures — `thenAnswer` required. Both are harness
errors, not implementation errors.

## Commands run

```bash
# RED proof
dart analyze test/crypto/group_cipher_test.dart test/services/chat_service_test.dart
#   → 30 errors: undefined senderKeyRequestJson/Target/unmark/isSenderKeyRequest,
#     undefined e2eeGroupKeyRequest* constants, missingChain named param

# GREEN
dart analyze lib/crypto lib/core/services test/crypto test/services   # 0 issues
flutter test test/crypto/group_cipher_test.dart test/services/chat_service_test.dart   # 82/82
flutter test test/crypto test/services test/features/chat test/core/repositories       # 659/659
dart analyze                                                          # 0 issues
flutter test                                                          # 2421/2421
```

Locks: acquired + held for `lib/crypto/constants.dart`, `lib/crypto/interfaces.dart`,
`lib/crypto/group_cipher.dart`, `lib/core/services/chat_service.dart`,
`test/crypto/group_cipher_test.dart`, `test/services/chat_service_test.dart`
(owner `orchestrator-issue1`) — released after the verifier sign-off.

Follow-up: E2EE-ARCHITECTURE.md §9.6 errata row for the retry protocol;
independent verifier review in progress.
