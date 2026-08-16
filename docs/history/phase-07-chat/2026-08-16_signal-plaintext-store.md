# 2026-08-16 — Signal plaintext store + prekey re-wrap (the permanent "Mensaje no descifrable" fix)

**Step:** `signal-plaintext-store` — root-caused + fixed the persistent
"más mensaje no descifrable" across every device/platform (waydroid, android
emulator, iOS simulator).

## Root cause (confirmed against libsignal-protocol-java source)

Samay re-decrypts server-side history from a STATEFUL Double Ratchet after
every app restart/update, keeping plaintext only in an in-memory map. Signal
never re-decrypts: apps persist decrypted plaintext locally (SQLCipher) and
unacknowledged prekey messages RE-WRAP the same base key. Three divergences
compounded:

1. **No persistent plaintext** — `_decryptedByMessage` (memory) only. After
   any restart, `loadMessages` re-processes already-consumed messages: the
   ratchet chain has advanced → AEAD fails → every message bubbles. Own sent
   messages additionally lose the in-memory outbox (DEBUG-REPORT item C).
2. **Fresh X3DH per unacknowledged send** (`wipe()` + re-init) instead of
   Signal's `getPreKeyMessage` re-wrap — burns an OPK server-side per send,
   and each new init REPLACES the peer's session (Sesame), so re-processed
   older inits fail on the consumed OPK.
3. **Drop/failure conflation** — replays, stale identities and missing
   prekey material returned `null`, which the caller classified as
   `decryptFailed` → the bubble (Signal drops these silently as
   `DuplicateMessageException`).

Signal source: `SessionCipher.encrypt` (re-wrap with same baseKey),
`SessionBuilder.processV3` (`hasSessionState(version, baseKey)` — reuse the
existing session, never re-run X3DH or re-consume an OPK),
`clearUnacknowledgedPreKeyMessage` on ANY successful decrypt.

## What was built

1. **`MessagePlaintextStore`** (`lib/core/services/message_plaintext_store.dart`):
   abstract store + `HiveMessagePlaintextStore` (the already-open, already
   AES-256 `message_cache` box — key in Keystore/Keychain, the SQLCipher
   equivalent) + `MemoryMessagePlaintextStore` (tests). Keys
   `chatId::messageId`, values `{"t": iso8601, "p": plaintext}`; pruned to
   `chat.message_cap` (1000) per chat; wiped with the key material (§7.6).
2. **`ChatService`** (`chat_service.dart`): cache-first in
   `_decryptMessageNow` (memory → persisted store → crypto); write-through on
   every successful decrypt AND on own-send outbox hits; `deleteMessageForMe`
   clears the entry; prune after each load. Restart-reload now serves stored
   plaintext — ZERO re-decryption.
3. **`E2eeDecryptResult` tri-state** (`interfaces.dart`): plaintext /
   SILENT drop (replay, stale identity, missing prekey, no-session ratchet) /
   genuine failure (tampering — the only bubble). `_decryptMessageNow`
   converts no-session drops to the existing `needsSession` class (reinstall
   hide + server offload unchanged); session-present drops are
   `decryptDropped` (hidden, rows stay server-side). Inbox + realtime paths
   drop silently.
4. **`E2eeSession`** (`session.dart`):
   - Unacknowledged sends RE-WRAP the current ratchet message with the
     persisted `ek_a`/`spk_id`/`opk_id` (Signal getPreKeyMessage) — one
     `fetchBundle` per session, no OPK burn. Legacy JSON (no persisted
     fields) or idle-past-90-day sessions heal with ONE fresh X3DH.
   - `_handleInitEnvelope` FIRST looks up a session bound to
     `(senderIkDh, ekA)` across active + retired (`_decryptWithBaseKeySession`)
     and decrypts via its ratchet — never loading/deleting an OPK
     (Signal `hasSessionState(version, baseKey)`). Replays AEAD-fail against
     the reused session → silent drop.
   - `init_acknowledged` is set on ANY successful decrypt (init path too) —
     simultaneous initiation converges (Signal `clearUnacknowledgedPreKeyMessage`).
   - Session JSON persists `ek_a`, `spk_id`, `opk_id` (+ `ek_a` on retired
     entries); old JSON restores gracefully.
5. **Provider wiring** (`chat_providers.dart`): `chatE2eeServiceProvider`
   passes `HiveMessagePlaintextStore`; `ChatMessagesState.messages` filters
   `decryptDropped` rows.

## Tests (RED → GREEN)

- NEW `test/services/message_plaintext_store_test.dart` (7): roundtrip,
  scoping, delete, prune-by-time, restart survival, no-plaintext-on-disk.
- `test/services/storage_service_test.dart`: +3 HiveService cache methods.
- `test/crypto/session_test.dart`: +5 — re-wrap same baseKey (no re-fetch),
  OPK not re-consumed, replay = silent drop (not failed), responder persists
  `init_acknowledged`, legacy JSON heals once then re-wraps.
- `test/features/chat/chat_e2ee_test.dart`: the pre-fix unacknowledged test
  (asserted fresh ekA per send) was rewritten to assert the SAME baseKey +
  1 bundle fetch + OPK conservation; NEW "THE LIVE BUG" test — live
  conversation, restart both sides, reload → ALL history plaintext, zero
  bubbles, conversation continues.
- Full suite: 2313/2313 (was 2266), `dart analyze` 0 issues, go test ok,
  ports strict, secrets pass.

## Decisions made and why

- **Persist decrypted plaintext** (reverses the §8.4 "memory-only" rule):
  impossible to re-render server history otherwise — the ratchet is
  irreversible. Storage is the SQLCipher-equivalent: AES-256 at rest, key in
  Keystore/Keychain, device-local, bounded, wiped on account deletion/switch.
- **Re-wrap, not re-init**: Signal-faithful; stops OPK burn and session
  churn; the peer can always decrypt re-sent inits via the baseKey-reused
  session.
- **Silent drops**: Signal's `DuplicateMessageException` model — the bubble
  is reserved for genuine tampering/skip-gap against an existing session.
- **Legacy heal**: old session JSON (pre-persist) or idle sessions past
  90 days get ONE fresh X3DH — the peer's session is gone in both cases, so
  a re-wrap could never decrypt there.

## Mistakes / gotchas

> **GOTCHA — prune RangeError:** `MemoryMessagePlaintextStore.prune` missed
> the `excess <= 0` guard (entries.length − maxPerChat went negative and
> `List.take` threw). Caught by the e2ee harness (every load prunes).

> **GOTCHA — harness != provider:** `ChatService.sendMessage` alone never
> refreshes (the provider's `send` does). The restart-reload test initially
> failed because the sender's own messages were never cached — the test now
> mirrors the provider's refresh-after-send.

> **GOTCHA — dropped ≠ needsSession:** the tri-state initially classified
> ALL init drops (incl. stale-identity on a fresh reinstall) as silent
> drops, breaking the REINSTALL test (rows must be `needsSession` → hidden +
> server-deleted). Fixed: the caller probes `sessionExists` for drops — no
> session → needsSession (unchanged reinstall semantics); session present →
> silent drop.

## Commands run (reproducibility)

```bash
flutter test test/crypto/session_test.dart test/services/message_plaintext_store_test.dart \
  test/services/storage_service_test.dart test/features/chat/chat_e2ee_test.dart   # RED → GREEN
dart analyze            # 0 issues
flutter test            # 2313/2313
go test ./...           # ok
tools/check_ports.sh --strict   # PASS
tools/check_secrets.sh          # PASS
```

## On-device validation (user)

`make build-install TARGET=android|waydroid` on both devices → FRESH sends
between the two accounts must survive an app restart / update on BOTH
devices (no bubbles). Note: already-bubbled history is unrecoverable (the
ratchet keys are consumed) — validate with fresh messages.
