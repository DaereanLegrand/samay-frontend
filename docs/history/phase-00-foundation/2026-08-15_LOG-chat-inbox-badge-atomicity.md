# Chat A→B == B→A (session/insert atomicity) + inbox with unread badge (2026-08-15)

**Branch:** `fixes` · **Worktree:** post-`af52ebf` (uncommitted by user directive)

## Part 1 — "Message sent on A, not visible on B" (session/insert atomicity)

### Symptom (user report)

A message sent from tester2 to tester3 produces NO error, but tester3's chat
with tester2 shows nothing.

### Root cause (verified live)

The DB row existed (sender tester2), but its envelope was **type 0x02
(ratchet)** — decoded `SME2\x01\x02` from the stored row. tester3's device
never received the **init envelope (0x01)** for that session, so it cannot
decrypt the ratchet message and drops it.

Why: before the RLS fix (20260815000003), tester2's device ran the full E2EE
send path — X3DH init → **persist the initiator session with
`has_sent_init=true`** → INSERT (which FAILED with 42501). The persisted
session survived; the post-fix retry restored it and sent a RATCHET message
into a session the peer never saw. `encryptText` persisted the init state
BEFORE the message insert was confirmed — a **session/insert atomicity bug**.

### Fix (A→B identical to B→A)

- `E2eeMessageCipher` gained `envelopeIsInit(envelope)` + `Future<void> wipe()`
  (the concrete `E2eeSession.wipe` became async, awaiting the store delete).
- `ChatService.sendMessage`: when the INSERT fails and the envelope was the
  session's **init**, the session is rolled back (`wipe()` + dropped from the
  `_sessions` cache) — the next send **re-initiates fresh X3DH** with a new
  type-0x01 init the peer CAN decrypt. Symmetric by construction.
- Logs (user directive "ADD LOGS"): `encryptText` logs envelope type +
  `hasSentInit`; `_handleRatchetEnvelope` logs the drop reason
  (no-session / identity-mismatch) — the silent-failure path is now visible;
  `sendMessage` logs the envelope type + the rollback event.

### Regression test

`chat_e2ee_test` "failed INIT insert rolls the session back": server rejects
the first insert (42501) → retry MUST produce a type-0x01 init envelope and
the peer decrypts it. (The orphaned live ratchet row was deleted.)

## Part 2 — Chat button on the feed with unread badge + inbox

### Server (migration `20260815000004_get_chat_inbox.sql`, both stacks)

- `chat_participants.last_read_at timestamptz NOT NULL DEFAULT now()` — the
  per-user read watermark (existing rows start "read").
- `get_chat_inbox()` — SECURITY DEFINER, `search_path=''`,
  authenticated-only: every chat the caller participates in, most-recent-
  first, with peer identity via `user_search_view` (block-exclusion intact),
  the last message (E2EE envelope — server never sees plaintext; the client
  decrypts the preview) and `unread_count` (messages from others newer than
  the watermark). Caller-scoped by construction.
- `mark_chat_read(p_chat_id)` — SECURITY DEFINER, self-only watermark bump.
- **MISTAKE:** the first draft had an unqualified `chat_id` inside the
  LATERAL subquery — it collided with the OUT parameter `chat_id` (42702).
  Qualified as `messages.chat_id`; opt-003 TEST G caught it live.

### Client

- `ChatService.fetchInbox()/markChatRead()/decryptInboxRow()` (decrypt is
  best-effort: outbox for own, session for peer, placeholder otherwise).
- `ChatInboxNotifier` + `chatInboxProvider` (autoDispose) +
  `chatUnreadCountProvider` (badge total).
- `InboxRealtimeListener` (shell-mounted, friendships pattern): subscribes to
  `messages:inbox:<uid>` with `sender_id=neq.<me>` (realtime v2.102.3 +
  realtime_client 2.7.3 support `neq`; RLS gates delivery to the caller's
  chats) → invalidates the inbox → live badge.
- `ChatListScreen` (new route `RoutePaths.chatList`, chat flag-gated): peer
  name/avatar initial, best-effort preview ("Tú: …" for own), relative time,
  unread `VCountBadge`, pull-to-refresh, empty/error states.
- **Feed button (user request)**: `_ChatInboxButton` — chat bubble at the
  top-right of the brand hero (same placement voice as the profile's settings
  gear) with the total-unread badge (hidden at 0).
- `ChatScreen` marks read on first successful load + on live inserts.
- `chatInboxProvider` added to the auth-scope reset flush list.

### Tests

- pgTAP +13 (plan **401**): `last_read_at` column + both RPCs (existence,
  definer, `search_path=''`, grants).
- opt-003 TEST G (5 checks): inbox visible to both participants; **symmetric
  unread** (sender 0 / receiver 1); `mark_chat_read` clears it; reverse
  direction (B→A == A→B); outsider's inbox excludes the chat.
- Flutter +21: chat_service inbox RPCs + E2EE-safe decrypt; chat_inbox
  provider (mapping, badge sum, markRead re-read); ChatListScreen widgets;
  feed chat-button badge; realtime `subscribeToInbox` (channel + filter).

## Validation

- `dart analyze` 0 · `flutter test` **2259/2259** · `go test ./...` green.
- pgTAP **401/401** live (psql fallback) · `bash test/run_all_backend.sh`
  **8/8**.
- Live `get_chat_inbox` verified against the deployed backend.
- Migration 20260815000004 applied live (remote shares the local stack's DB).

## Follow-ups

- Media attachments, group/event chat UI, typing indicators, read receipts —
  unchanged (CHAT spec gaps).
- The inbox realtime channel is best-effort (the badge falls back to the
  next provider read) — consistent with the friendships listener contract.
