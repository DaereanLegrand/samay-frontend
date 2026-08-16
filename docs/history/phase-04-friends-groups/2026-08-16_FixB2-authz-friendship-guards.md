# FixB2-authz — friendship guard re-audit fixes (2026-08-16)

## What was built

Re-audit fix (LOW, pre-existing) in `lib/core/services/user_service.dart`:

1. **`sendFriendRequest` mutual-accept shortcut** — the `UPDATE status='accepted'`
   was guarded only by the row `id`; because `friendships_update_own` covers
   requester OR addressee, the addressee of a BLOCKED row could flip the block
   into an accepted friendship. Fix:
   - The reverse probe now selects `id, status`.
   - A reverse `blocked` row throws `Exception('No puedes enviar una
     solicitud: estás bloqueado')` (mirrors the forward-direction guard's
     message shape; a block is only lifted by the blocker via `unblockUser`).
   - The mutual-accept UPDATE gained `.eq('status', 'pending')` — a blocked
     row can never be flipped through the filter, even if the throw were ever
     bypassed (defense in depth; the UPDATE no-ops on non-pending rows).

2. **`declineFriendRequest`** — the DELETE had no status guard, so the
   addressee of a blocked row could delete the block. Fix: added
   `.eq('status', 'pending')`; a blocked row is not deletable through this
   path.

3. **Test coverage gap** — added `test/crypto/group_cipher_test.dart`
   "on-device migration" group: a persisted v1 record (version 1, no
   `chat_id`) is rejected by `GroupSenderKeyRecord.fromJson` (treated as
   absent), decrypt drops (NoSession semantics), and re-distribution heals
   the device to a v2 record with the chain resuming.

## Decisions

- **Blocked-row mutual-accept behavior:** THROW a blocked error (not insert a
  fresh pending request, not silent no-op 'accepted'). Honest outcome: a
  block exists; only the blocker may lift it.
- Both sendFriendRequest probes select `id, status` (status only needed on the
  reverse probe, kept symmetric so the mocktail stub stays single).

## Tests / commands

```bash
flutter test test/services/user_service_test.dart test/crypto/group_cipher_test.dart  # 77/77 green
dart analyze lib/core/services/user_service.dart test/services/user_service_test.dart test/crypto/group_cipher_test.dart  # 0 issues
```

RED proof: the 3 updated/new tests failed against the pre-fix service
(decline filter index error, missing `pending` filter, blocked row accepted).

## MISTAKE

- First `edit` on `group_cipher_test.dart` replaced the F4 test's opening
  lines with the new group, orphaning the F4 body after `main()`'s closing
  brace — repaired with a second full-tail edit. Always re-read the target
  region after a large edit.
