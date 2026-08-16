# 2026-08-17 — FixA1b-crypto-audit: ISSUE 4 group sender-key hardening (F1/F2/F4)

**Agent:** FixA1b-crypto-audit · **Scope:** `lib/crypto/group_cipher.dart`,
`lib/crypto/constants.dart`, `test/crypto/group_cipher_test.dart`. Companion to
the docs-only FixA4-docs round (E2EE-ARCHITECTURE.md §0.3/§9.6) and the FixB3
re-audit (test-count reconciliation).

## What was built

Second audit pass over the ISSUE 4 group sender-key code (first pass was the
D2 build itself, 2026-08-15). Three hardening fixes, all test-first:

- **F1 — chain-gap DoS cap.** `e2eeSenderKeyMaxSkip = 2000` (constants.dart).
  The envelope `chain_index` is attacker-controlled; an unbounded derivation
  walk is a remote CPU DoS (u32-max index ≈ 4.29e9 HKDF steps, re-run on every
  reload/redelivery). A gap `chainIndex - lastSeenN > e2eeSenderKeyMaxSkip` is
  now DROPPED **without deriving and without advancing the record** (mirrors
  `double_ratchet` `MAX_SKIP` semantics). u32-safe: Dart ints are 64-bit so the
  subtraction cannot overflow — a huge `chainIndex` simply yields a huge gap
  that trips the cap.
- **F2 — bundle `chain_index` = `lastSentN`.** D2 shipped bundles with a
  hardcoded `chain_index: 0`, which reset receivers to `lastSeenN = -1` on
  re-distribution and caused replay drops of the sender's live chain. The
  bundle now carries the record's `lastSentN` (the last message receivers have
  seen); the chain root is ready for message `lastSentN + 1`.
- **F2b — registry `distributed_to` target sets.** The registry
  (`group_sender_key_registry:<groupChatId>`) now persists per-sender
  `distributed_to` target sets so `membersMissingSenderKey` re-queries only
  the members who have NOT yet received the bundle (persisted in the
  `toJson`/`fromJson` v2 schema).
- **F2c — no-regress guard.** A stale/duplicate bundle never overwrites a
  live record (`chain_index <= existing.lastSeenN` → ignored; chain-index
  validation tightened on ingest).
- **F4 — chatId binding.** `GroupSenderKeyRecord` carries `chatId` (the chat
  the chain was distributed in). `decrypt` rejects an envelope whose
  record is bound to a different chat — a G2-chain envelope posted into a
  different chat is dropped, closing a cross-chat namespace leak. v1 records
  (no `chat_id`) are rejected by `fromJson`.
- **JSON v2 migration for on-device state.** Record schema `v2`
  (`e2eeSenderKeyRecordVersion = 2`, adds `chat_id`); registry schema `v2`
  (`e2eeSenderKeyRegistryVersion = 2`, adds `distributed_to`). v1 records and
  registries are rejected by `fromJson` — this is on-device secure-storage
  state (per-device), so a version bump is a clean one-way migration with no
  server contract change.

## Tests (RED → GREEN)

- New `group('audit fixes (F1 bounded gap / F2 re-distribution + no-regress /
  F4 chat binding)')` in `test/crypto/group_cipher_test.dart` — 6 tests:
  - `F1: chainIndex = 0xFFFFFFFF → dropped, record untouched` (record
    advances/derives nothing, replay still dropped on re-delivery);
  - `F1: gap just over the cap dropped without derivation` (no HKDF steps on
    the dropped path);
  - `F2a: same-epoch re-distribution does NOT desync receivers` (bundle
    carries `lastSentN`, receivers keep deriving);
  - `F2b: after a distribution round the target set is persisted` — the next
    `membersMissingSenderKey` excludes already-received members;
  - `F2c: stale/duplicate bundle never overwrites a live record`;
  - `F4: record bound to its chat — G2-chain envelope posted into a foreign
    chat is dropped`.
- RED proven before implementation: tests failed on the un-fixed code
  (unbounded walk / chain_index-0 reset / missing `chat_id`).

## Results

- `test/crypto/` totals **169 `test(`** (group_cipher 29, session 30,
  primitives 25, key_store 21, envelope 18, ratchet 23, x3dh 10, prekey 13) —
  previously 162 (group_cipher 22); 169 after FixB2's v1-record migration test (group_cipher 29).
- `flutter test test/crypto` → all pass; `dart analyze lib/crypto` → 0 issues.
- No changes to `session.dart`, `x3dh.dart`, `double_ratchet.dart`,
  `envelope.dart` wire format, or `chat_service.dart`.

## Decisions

- **Drop-without-derive** (F1): deriving only up to the cap would still burn
  up to 2000 HKDF steps per hostile envelope; dropping before walking keeps
  the hostile path at O(1). Legit large gaps (>2000) are treated as
  unrecoverable desync — the member re-requests the bundle (distribution
  round) instead of blocking the decrypt path.
- **Bundle carries `lastSentN`, not 0** (F2): distribution must be
  idempotent; re-sending a chain root at index 0 would replay-drop every
  message after the receiver's current position.
- **`chat_id` in the record, not just the AAD** (F4): the AEAD AAD already
  binds the chat namespace at the crypto level, but a record that was
  distributed in chat A could be used to *ingest* a bundle crafted for chat B
  before any decryption attempt. Binding the record at ingest closes the
  leak one layer earlier.

## MISTAKE-1

The first F2 attempt (D2 build) shipped bundles with `chain_index: 0` — the
intent was "a fresh chain starts at 0", but bundles are *re-sent* across
distribution rounds, so the fixed 0 rewound receivers to `lastSeenN = -1`
every re-distribution. Diagnosed as "replay drop after re-distribution" in
the F1/F2 audit. Watch for this when any future code re-serializes a chain
root: always persist and re-send the *live* position.

## Commands run (reproducibility)

```bash
tools/agent_lock.sh acquire lib/crypto/group_cipher.dart --owner FixA1b-crypto-audit
tools/agent_lock.sh acquire lib/crypto/constants.dart --owner FixA1b-crypto-audit
tools/agent_lock.sh acquire test/crypto/group_cipher_test.dart --owner FixA1b-crypto-audit
flutter test test/crypto/group_cipher_test.dart          # RED: audit-fix tests fail on D2 code
flutter test test/crypto                                # 169 tests, all pass
dart analyze lib/crypto test/crypto                     # 0 issues
rg -o "test\(" test/crypto/*.dart | sort | uniq -c      # count reconciliation → 169 (incl. FixB2's v1-record test, group_cipher 29)
tools/agent_lock.sh release ... --owner FixA1b-crypto-audit   # per file
```

## Not verified

- Full Flutter suite not run (per brief — another agent may hold the flutter
  startup lock); verification limited to `test/crypto/` + `dart analyze`.
