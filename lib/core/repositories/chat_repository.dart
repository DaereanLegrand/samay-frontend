import 'package:samay/core/services/chat_service.dart';
import 'package:samay/core/services/realtime_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Chat domain repository (I-50): thin facade over [ChatService].
///
/// Dependency direction doctrine (DEVELOPMENT-WORKFLOW §5): providers depend
/// on repositories, repositories on services, services on the Supabase client.
///
/// ## E2EE invariant (E2EE-ARCHITECTURE.md §12.2 — DO NOT bypass)
///
/// End-to-end encryption lives inside [ChatService]: `sendMessage` encrypts
/// the payload into an opaque envelope before insert and
/// `loadMessages`/`subscribeToMessages` decrypt on the way out. The
/// repository MUST NOT bypass it — every message path below delegates to the
/// injected [ChatService]:
///
/// - [loadMessages] → `ChatService.loadMessages` (decrypts history)
/// - [sendMessage] → `ChatService.sendMessage` (encrypts before insert)
/// - [subscribe] → `ChatService.subscribeToMessages` (decrypts live rows —
///   **never** a raw `RealtimeService.subscribeToMessages`, which would leak
///   ciphertext envelopes to the UI)
///
/// [realtime] is exposed for future non-message subscriptions only; the
/// message path never touches it (pinned by a `verifyNever` test in
/// `test/core/repositories/chat_repository_test.dart`).
///
/// The repository is intentionally **not** wired in
/// `lib/core/repositories/repository_providers.dart`: the chat feature is the
/// only message consumer and always goes E2EE, so its repository provider
/// lives feature-scoped in `lib/features/chat/chat_providers.dart`
/// (`chatE2eeRepositoryProvider`, built on the E2EE-wired [ChatService]).
/// Message rows keep `Map<String, dynamic>` shape: the service does not
/// select `chat_id` and adds the `decryptFailed` flag for the UI.
class ChatRepository {
  ChatRepository({required ChatService chat, required this.realtime})
      : _chat = chat;

  final ChatService _chat;

  /// Raw realtime access for future non-message subscriptions (notifications,
  /// presence). The message path must never use this — see the E2EE invariant
  /// above and the `verifyNever` guard in
  /// `test/core/repositories/chat_repository_test.dart`.
  final RealtimeService realtime;

  /// Whether the underlying [ChatService] has the E2EE stack wired.
  bool get e2eeEnabled => _chat.e2eeEnabled;

  /// Message history for [chatId] (oldest first), decrypted by the service.
  /// [limit]/[offset] paginate the newest-first server query.
  Future<List<Map<String, dynamic>>> loadMessages(
    String chatId, {
    int limit = 50,
    int offset = 0,
  }) =>
      _chat.loadMessages(chatId, limit: limit, offset: offset);

  /// Sends [content] (+ optional [mediaUrl]) to [chatId]. The service
  /// sanitizes the input and — when E2EE is wired — encrypts it into an
  /// envelope before insert.
  Future<void> sendMessage(String chatId, String content, String? mediaUrl) =>
      _chat.sendMessage(chatId, content, mediaUrl);

  /// Subscribes to live inserts for [chatId]; rows are decrypted by the
  /// service before [onInsert] sees them. Returns the [RealtimeChannel] so
  /// the caller can unsubscribe on dispose. Never call
  /// `realtime.subscribeToMessages` for chat rows — that bypasses E2EE
  /// decryption.
  RealtimeChannel subscribe(
    String chatId,
    void Function(Map<String, dynamic>) onInsert,
  ) =>
      _chat.subscribeToMessages(chatId, onInsert);

  /// The caller's chat inbox (RPC `get_chat_inbox`, migration
  /// 20260815000004): chats they participate in with peer identity, last
  /// message (E2EE envelope) and unread count, most-recent-first.
  Future<List<Map<String, dynamic>>> fetchInbox() => _chat.fetchInbox();

  /// Bumps the caller's read watermark for [chatId] (RPC `mark_chat_read`).
  Future<void> markChatRead(String chatId) => _chat.markChatRead(chatId);

  /// Stamps `read_at` on the caller's peer's unread messages (RPC
  /// `mark_messages_read`, migration 20260815000005) — only call when the
  /// caller's `read_receipts_enabled` is on. E2EE-inert: only `read_at`
  /// is ever written, never the envelope.
  Future<void> markMessagesRead(String chatId) => _chat.markMessagesRead(chatId);

  /// The caller's read-receipts privacy switch (`users.read_receipts_enabled`).
  Future<bool> getReadReceiptsEnabled() => _chat.getReadReceiptsEnabled();

  /// Persists the caller's read-receipts switch (own-row RLS).
  Future<void> setReadReceiptsEnabled(bool value) =>
      _chat.setReadReceiptsEnabled(value);

  /// Live `read_at` flips for [chatId] (raw rows — consume only `read_at`).
  /// Like [subscribe], this must never leak raw envelopes to the UI: the
  /// channel delivers full rows but the caller only merges the status field.
  RealtimeChannel subscribeToMessageReads(
    String chatId,
    void Function(Map<String, dynamic>) onUpdate,
  ) =>
      _chat.subscribeToMessageReads(chatId, onUpdate);

  /// Live per-member read flips in a GROUP chat (20260817000006): each
  /// `message_reads` INSERT carries exactly one (message_id, user_id,
  /// read_at) receipt — the thread merges it into the row's read set (the
  /// sender's ticks flip blue only when EVERY other member read). E2EE-
  /// inert: metadata only, never envelope bytes.
  RealtimeChannel subscribeToGroupMessageReads(
    String chatId,
    void Function(Map<String, dynamic>) onInsert,
  ) =>
      _chat.subscribeToGroupMessageReads(chatId, onInsert);

  /// Live hard-delete events for [chatId] (delete-for-everyone from the
  /// sender, or the undecryptable cleanup) — the open thread removes the row
  /// live. The row is the pre-delete record (REPLICA IDENTITY FULL).
  RealtimeChannel subscribeToMessageDeletes(
    String chatId,
    void Function(Map<String, dynamic>) onDelete,
  ) =>
      _chat.subscribeToMessageDeletes(chatId, onDelete);

  /// Delete-for-everyone: sender-only + a 5-minute window verified with the
  /// SERVER's clock (`messages.sent_at`, migration 20260815000006). The
  /// [MessageDeleteOutcome] drives the UI copy (too-old snackbar etc.).
  Future<MessageDeleteOutcome> deleteMessageForEveryone(String messageId) =>
      _chat.deleteMessageForEveryone(messageId);

  /// Delete-for-me: hides the message on this device only (in-memory
  /// tombstone) — the server rows stay for the peer.
  Future<void> deleteMessageForMe(String chatId, String messageId) =>
      _chat.deleteMessageForMe(chatId, messageId);

  /// Whether [messageId] was locally deleted for this chat (the provider
  /// drops it from the thread).
  bool isLocallyDeleted(String chatId, String messageId) =>
      _chat.isLocallyDeleted(chatId, messageId);

  /// Whether the peer's published identity differs from the session's bound
  /// identity (reinstall detection, E2EE §7.5). False without a session.
  Future<bool> peerNeedsRekey(String chatId) =>
      _chat.peerNeedsRekey(chatId);

  /// Best-effort decryption of an inbox row's last message (E2EE path — the
  /// server only ever sees envelopes). Own messages render from the outbox;
  /// undecryptable ones become [ChatService.chatUndecryptablePlaceholder]
  /// with `decryptFailed` on the returned row.
  Future<Map<String, dynamic>> decryptInboxRow(Map<String, dynamic> row) =>
      _chat.decryptInboxRow(row);
}
