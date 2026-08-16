# H1 — rekey-epoch fix: message #2 undeliverable in group E2EE chat (2026-08-17)

Agent: `H1-rekey-epoch` · Phase 07 (chat) · No commits (working tree only).

## What was built

Closed the two live-bug defects in group E2EE chat with a group **epoch** scheme
and a **resilient distribution** loop.

### A. Crypto — group epochs (`lib/crypto/group_cipher.dart`, `lib/crypto/constants.dart`)

- `GroupSenderKeyRecord` gains `epoch` (default 0, persisted as `epoch`,
  included in `copyWith`). Record JSON version `e2eeSenderKeyRecordVersion`
  2 → **3**; `fromJson` rejects v2 (treated as absent → one re-distribution,
  then stable — the documented on-device migration story).
- The registry `_GroupRegistry` (`group_sender_key_registry:<chatId>`) gains a
  group-level `epoch` counter (default 0). Registry version
  `e2eeSenderKeyRegistryVersion` 2 → **3**; `fromJson` rejects old versions.
- `wipeGroupKeys` NO LONGER DELETES the registry — it clears `senders` +
  `distributed_to` and bumps the persisted epoch (creating the registry at
  epoch 1 when absent).
- `_ensureOwnRecord` stamps the CURRENT registry epoch into a minted record
  (0 when no registry exists).
- `senderKeyBundleJson` adds `'epoch': record.epoch`; bundle version
  `e2eeSenderKeyBundleVersion` → **3** (the code had 1; the bump lands on 3
  like the other two — v1/v2 bundles are rejected by the version guard).
- `processSenderKeyBundle` epoch-aware no-regress guard:
  - parse + validate `epoch` (int >= 0) alongside the other fields;
  - no existing record → accept;
  - `bundle.epoch > record.epoch` → ACCEPT (genuine rekey — the fix; overrides
    the old `chain_index <= lastSeenN` guard);
  - `bundle.epoch < record.epoch` → ignore (stale old-epoch replay);
  - `epoch == record.epoch && chain_index <= lastSeenN` → ignore (F2c
    preserved);
  - `epoch == record.epoch && chain_index > lastSeenN` → accept (gap heal).
  - stored record `epoch` = bundle epoch; `lastSeenN = chain_index - 1`
    unchanged.
- `decrypt`: NO epoch check on messages — the record IS the epoch; a rekeyed
  record starts fresh (lastSeenN = -1) so index 0 is accepted.

### B. Service — resilient distribution (`lib/core/services/chat_service.dart`)

- `membersMissingSenderKey` is now a PURE candidate computation
  (activeMemberIds − sender − distributed_to); it no longer persists.
- New `markSenderKeyDistributed({groupChatId, senderUserId, memberIds})`
  persists targets; called by the service AFTER each successful distribution
  insert.
- `_sendGroupMessage`: per-member try/catch around (bundleJson → pairwise
  encrypt → INSERT): on failure log (member id only — never key material) and
  CONTINUE; on success `markSenderKeyDistributed([member])`. The message-row
  insert stays OUTSIDE the per-member loop. Roster-wipe logic, ordering,
  outbox and error logging unchanged.

### C. Test updates

- Pinned test (group_cipher_test.dart 'wipeGroupKeys…'): rewritten tail — the
  registry now SURVIVES the wipe (epoch 0→1 asserted via raw JSON), the
  pre-wipe round-2-empty pin moves to the explicit `markSenderKeyDistributed`
  call, and the tail asserts bob DECRYPTS 'fresh' after the fresh-epoch
  bundle is distributed (old tail asserted the broken `failed` behavior).
- Two persist-pin tests ('membersMissingSenderKey persists…', F2b) updated to
  the new contract (pure computation + explicit mark call).
- New 'rekey epochs' group (3 tests): fresh-epoch accept + rekeyed message
  decrypts; old-epoch bundle ignored; same-epoch stale ignored. The 3rd
  test's manual bundle now carries `'epoch': 0` (version via the bumped
  constant), and bob decrypts m0/m1 first so `chain_index 1 == lastSeenN` is
  real (see MISTAKE below).
- chat_service_test.dart: harness `_MockGroupCipher` stubs the new
  `markSenderKeyDistributed`; the skip test removes bob's published prekeys
  (undoing the setUp default) so the X3DH failure is real; it also verifies
  the mark is called for carol only, never bob.

## Decisions made and why

- **Epoch lives in the registry, not in each record** — the wipe path needs a
  counter that survives record deletion; the registry is the natural owner.
- **`decrypt` does not check epochs** — a message carries no epoch field; the
  record's epoch IS the epoch. A rekeyed record (epoch N+1, lastSeenN -1)
  accepts index 0 by the existing replay logic.
- **The version bump is the migration** — v2 state (record/registry/bundle)
  fails the guards and is treated as absent: one re-distribution round, then
  v3 everywhere. No manual migration code.
- **Distribution failures are per-member, message insert is outside the loop**
  — a member without a published bundle must never block the message; a
  failed member stays missing (not marked) so the next send retries.

## MISTAKE (pre-written RED test 3 was not self-consistent)

The pre-written 3rd rekey-epoch test ('same-epoch stale bundle…') built a
manual bundle with `chain_index: 1` and root = C_2, but bob never decrypted
m0/m1, so his `lastSeenN` was -1 — `chain_index 1` was NOT `<= lastSeenN`,
and the stale bundle would have been ACCEPTED as a gap-heal, corrupting the
record invariant (`root == C_{lastSeenN+1}`) and making the final m2 assertion
fail for the wrong reason. Fixed by making bob decrypt m0/m1 first (the
scenario the test name/comment describe). Per DEVELOPMENT-WORKFLOW §1.3: a red
test must be red for the right reason.

MISTAKE (service skip test): the harness `setUp` publishes bob's bundle, so
the pre-written 'member WITHOUT a published prekey bundle' test could never
fail the X3DH for bob — it failed expecting 2 inserts while the harness
produced 3. Fixed by removing bob's prekeys in the test body.

## Commands run

```bash
# RED proof
dart analyze lib/crypto lib/core/services test/crypto test/services
#   → 3 errors: epoch getter undefined (test/crypto/group_cipher_test.dart)
flutter test test/services/chat_service_test.dart
#   → 1 failure: skip test (3 inserts instead of 2)

# GREEN
dart analyze lib/crypto lib/core/services test/crypto test/services   # 0 issues
flutter test test/crypto/group_cipher_test.dart                        # 32/32
flutter test test/services/chat_service_test.dart                      # 32/32
flutter test test/crypto/group_cipher_test.dart test/services/chat_service_test.dart \
  test/core/repositories/chat_repository_test.dart \
  test/features/chat/chat_screen_test.dart                             # 100/100
```

Full suite deliberately NOT run (per assignment).

## Follow-up (J1 + K1 rounds, 2026-08-17)

The J1 round (reinstall heal + send mutex, 2026-08-17) added 3 more group_cipher tests —
reinstall-heal ×2, v2-record ×1. The K1 round added 4 more (bundle-identity binding:
mismatch-ignored / match-accepted / spoofed-ignored / malformed-expected). The
`test/crypto/` count now stands at **179** `test(` (group_cipher 39). Reconciliation done
by K2-docs4 + orchestrator (`docs/history/phase-07-chat/2026-08-17_K2-docs4.md`).
