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

  /// Best-effort decryption of an inbox row's last message (E2EE path — the
  /// server only ever sees envelopes). Own messages render from the outbox;
  /// undecryptable ones become [ChatService.chatUndecryptablePlaceholder]
  /// with `decryptFailed` on the returned row.
  Future<Map<String, dynamic>> decryptInboxRow(Map<String, dynamic> row) =>
      _chat.decryptInboxRow(row);
}
