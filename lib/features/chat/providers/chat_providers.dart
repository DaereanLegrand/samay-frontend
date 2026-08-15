import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/chat_repository.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/core/utils/pagination.dart';
import 'package:samay/crypto/e2ee_key_store.dart';
import 'package:samay/crypto/e2ee_prekey_service.dart';
import 'package:samay/crypto/interfaces.dart';

/// Compile-time switch for E2EE key/session storage:
/// `true` → flutter_secure_storage ([SecureE2eeKeyStore]/[SecureE2eeSessionStore],
/// iOS Keychain / Android Keystore, §8.2 namespaces, allowBackup=false
/// Android rule M-27 + iOS keychain entitlements M-28).
/// `false` → in-memory stores (tests / the two-party harness only).
///
/// Production wiring landed 2026-08-13: the secure stores were already
/// implemented, tested (test/crypto/e2ee_key_store_test.dart) and used by
/// nothing except the flag; identity/prekey/ratchet material now survives
/// app restarts at rest, protected by the platform keystore (E2EE §8).
const bool useSecureE2eeKeyStore = true;

/// Device-local E2EE key material (identity, SPKs, OPKs).
final e2eeKeyStoreProvider = Provider<E2eeKeyStore>((ref) {
  if (useSecureE2eeKeyStore) return SecureE2eeKeyStore();
  return MemoryE2eeKeyStore();
});

/// Per-chat session JSON persistence (§8.2/§8.3).
final e2eeSessionStoreProvider = Provider<E2eeSessionStore>((ref) {
  if (useSecureE2eeKeyStore) return SecureE2eeSessionStore();
  return MemoryE2eeSessionStore();
});

/// Prekey publishing + bundle fetch against Supabase (migration
/// 20260809000003 `e2ee_identity_keys` + `fetch_prekey_bundle` RPC).
final e2eePrekeyServiceProvider = Provider<E2eePrekeyService>((ref) {
  return SupabaseE2eePrekeyService(
    client: ref.watch(supabaseClientProvider),
    keyStore: ref.watch(e2eeKeyStoreProvider),
  );
});

/// The E2EE-wired [ChatService] used by the chat screen: encrypts on send,
/// decrypts on load and on realtime delivery (E2EE §12.2 step 3).
final chatE2eeServiceProvider = Provider<ChatService>((ref) {
  return ChatService(
    client: ref.watch(supabaseClientProvider),
    realtime: ref.watch(realtimeServiceProvider),
    e2eeKeyStore: ref.watch(e2eeKeyStoreProvider),
    e2eeSessionStore: ref.watch(e2eeSessionStoreProvider),
    e2eePrekeyService: ref.watch(e2eePrekeyServiceProvider),
  );
});

/// The chat feature's [ChatRepository], built on the E2EE-wired
/// [ChatService] so every message path (load/send/subscribe) stays encrypted
/// at the service layer (E2EE §12.2 step 3 — the repository must never
/// bypass it; see `ChatRepository` docs).
///
/// Feature-scoped by design: `repository_providers.dart` deliberately has no
/// chat repository — the chat feature is the only message consumer and
/// always goes E2EE, so the E2EE wiring lives here.
final chatE2eeRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    chat: ref.watch(chatE2eeServiceProvider),
    realtime: ref.watch(realtimeServiceProvider),
  );
});

/// History page size (CHAT spec: "load last 50 messages on open, scroll up →
/// paginate older messages").
const int chatPageSize = 50;

/// Mirror of the `chat.message_cap` app_config key (default 1000) enforced
/// server-side by the `enforce_message_cap` trigger (TRIG spec / migration
/// 20260809000001). The DB rolling window never stores more than this many
/// messages per chat, so the client must not paginate past it — [PageLoader]
/// flips `hasMore` false at the cap (see [ChatMessagesNotifier]).
const int chatMessageCap = 1000;

/// The chat thread state (I-56 public API preserved): decrypted messages
/// (oldest first) plus the pagination flags the screen renders.
///
/// Driven by (and a thin view over) the generic [PagedState] — the offset/
/// hasMore/cap/dedupe machinery lives in `lib/core/utils/pagination.dart`
/// (I-72), so every other paginated feature gets the same engine. Rows keep
/// `Map<String, dynamic>` shape: the E2EE service does not select `chat_id`
/// and adds the `decryptFailed` flag (see [ChatRepository]).
class ChatMessagesState {
  ChatMessagesState({
    required List<Map<String, dynamic>> messages,
    required bool hasMore,
    bool loadingOlder = false,
    int pageSize = chatPageSize,
    int nextOffset = 0,
  }) : _paged = PagedState<Map<String, dynamic>>(
          items: messages,
          hasMore: hasMore,
          loadingMore: loadingOlder,
          pageSize: pageSize,
          nextOffset: nextOffset,
          idOf: _messageIdOf,
        );

  /// The paged core this state is a view over (I-72): all paging flags and
  /// the dedupe-by-id transformations live there.
  final PagedState<Map<String, dynamic>> _paged;

  /// Decrypted rows, oldest first.
  List<Map<String, dynamic>> get messages => _paged.items;

  /// Whether an older page is still available (server returned a full page
  /// on the last fetch and the message cap has not been reached).
  bool get hasMore => _paged.hasMore;

  /// True while an older page is being fetched (loader row in the UI).
  bool get loadingOlder => _paged.loadingMore;

  /// Rows requested per fetch.
  int get pageSize => _paged.pageSize;

  /// Next server offset for the next older page.
  int get nextOffset => _paged.nextOffset;

  /// Dedupe key: the message `id` (realtime rows can overlap page
  /// boundaries). Rows without a string id are never deduped.
  static String? _messageIdOf(Map<String, dynamic> message) =>
      message['id'] is String ? message['id'] as String : null;

  /// Wraps a [PageLoader]-produced [PagedState] back into the chat state
  /// shape ([ChatMessagesNotifier] never does paging arithmetic itself).
  factory ChatMessagesState.fromPaged(
    PagedState<Map<String, dynamic>> paged,
  ) {
    return ChatMessagesState(
      messages: paged.items,
      hasMore: paged.hasMore,
      loadingOlder: paged.loadingMore,
      pageSize: paged.pageSize,
      nextOffset: paged.nextOffset,
    );
  }

  ChatMessagesState copyWith({
    List<Map<String, dynamic>>? messages,
    bool? hasMore,
    bool? loadingOlder,
    int? pageSize,
    int? nextOffset,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      pageSize: pageSize ?? this.pageSize,
      nextOffset: nextOffset ?? this.nextOffset,
    );
  }
}

class ChatMessagesNotifier
    extends FamilyAsyncNotifier<ChatMessagesState, String> {
  /// The paging engine for this chat (I-72): fetch seam, dedupe key, page
  /// size and cap. Created fresh in every [build] so a (re)load always
  /// restarts from the first page.
  late PageLoader<Map<String, dynamic>> _loader;

  /// The E2EE seam (I-50): every message path goes through the injected
  /// [ChatService] — encrypt-on-send, decrypt-on-load. The provider must
  /// never touch the raw Supabase client (pinned by a `verifyNever` test in
  /// `test/features/chat/chat_pagination_test.dart`).
  ChatRepository get _repo => ref.read(chatE2eeRepositoryProvider);

  @override
  Future<ChatMessagesState> build(String chatId) async {
    // Family instances are long-lived (keep-alive provider); a fresh loader
    // resets the paging state on every (re)load so refresh() re-reads the
    // first page.
    _loader = PageLoader<Map<String, dynamic>>(
      fetch: (offset, limit) =>
          _repo.loadMessages(chatId, limit: limit, offset: offset),
      idOf: ChatMessagesState._messageIdOf,
      pageSize: chatPageSize,
      maxItems: chatMessageCap,
    );
    return ChatMessagesState.fromPaged(await _loader.loadFirst());
  }

  /// Re-runs [build] (after sending, pull-to-refresh).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Sends a message and reloads the thread. [chatE2eeRepositoryProvider]
  /// encrypts via [ChatService] before insert; the reload path decrypts.
  Future<void> send(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    final stopwatch = Stopwatch()..start();
    try {
      await _repo.sendMessage(chatId, text, null);
      await refresh();
      AppLogger.instance.debug(
        'chat provider send ok chat=$chatId ms=${stopwatch.elapsedMilliseconds}',
      );
    } catch (e, st) {
      AppLogger.instance.error(
        'chat provider send failed chat=$chatId '
        'type=${e.runtimeType} ms=${stopwatch.elapsedMilliseconds}',
        '$st',
      );
      rethrow;
    }
  }

  /// Appends a realtime-delivered row, deduplicated by `id` (dispose-safe
  /// subscription wiring lives in the chat screen).
  void addMessage(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String) return;
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncData(ChatMessagesState(messages: [row], hasMore: true));
      return;
    }
    if (current.messages.any((m) => m['id'] == id)) return;
    state = AsyncData(current.copyWith(messages: [...current.messages, row]));
  }

  /// Fetches the next older page ([chatPageSize] rows before the current
  /// window) via [PageLoader.loadMore] — it prepends the page (deduplicated
  /// by id — realtime rows may overlap page boundaries) and recomputes
  /// [ChatMessagesState.hasMore].
  ///
  /// ## Message cap (CHMC/TRIG)
  ///
  /// The DB trigger caps the rolling window at `chat.message_cap` (1000):
  /// pagination must never exceed it, so `hasMore` flips false once the
  /// accumulated thread reaches [chatMessageCap] or the next page comes back
  /// short. Failures leave the previous state intact and are rethrown (the
  /// screen surfaces them via a snackbar).
  Future<void> loadOlder() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingOlder || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingOlder: true));
    try {
      state = AsyncData(
        ChatMessagesState.fromPaged(await _loader.loadMore(current._paged)),
      );
    } catch (e, st) {
      state = AsyncData(current.copyWith(loadingOlder: false));
      AppLogger.instance.error(
        'chat provider loadOlder failed chat=$arg type=${e.runtimeType}',
        '$st',
      );
      rethrow;
    }
  }
}

/// Messages of a chat (oldest first), decrypted; pagination (last 50 on
/// open, older pages via [ChatMessagesNotifier.loadOlder]) + send + refresh.
final chatMessagesProvider = AsyncNotifierProvider.family<ChatMessagesNotifier,
    ChatMessagesState, String>(ChatMessagesNotifier.new);

/// A chat in the caller's inbox (RPC `get_chat_inbox`, migration
/// 20260815000004): peer identity, last message (E2EE envelope — the
/// preview is decrypted client-side via [ChatRepository.decryptInboxRow])
/// and the unread count (messages from the peer newer than the caller's
/// read watermark).
class ChatInboxItem {
  const ChatInboxItem({
    required this.chatId,
    required this.type,
    this.peerId,
    this.peerUsername,
    this.peerAvatarUrl,
    this.lastMessageId,
    this.lastMessageSenderId,
    this.lastMessageContent,
    this.lastMessageAt,
    required this.unreadCount,
    this.decryptFailed = false,
  });

  final String chatId;
  final String type;
  final String? peerId;
  final String? peerUsername;
  final String? peerAvatarUrl;
  final String? lastMessageId;
  final String? lastMessageSenderId;
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final int unreadCount;

  /// Whether the last-message envelope could not be decrypted (the UI
  /// renders [ChatService.chatUndecryptablePlaceholder] / "Tú: …").
  final bool decryptFailed;

  factory ChatInboxItem.fromRow(Map<String, dynamic> row) {
    final lastAt = row['last_message_created_at'];
    return ChatInboxItem(
      chatId: row['chat_id'] as String? ?? '',
      type: row['type'] as String? ?? 'direct',
      peerId: row['peer_id'] as String?,
      peerUsername: row['peer_username'] as String?,
      peerAvatarUrl: row['peer_avatar_url'] as String?,
      lastMessageId: row['last_message_id'] as String?,
      lastMessageSenderId: row['last_message_sender_id'] as String?,
      lastMessageContent: row['last_message_content'] as String?,
      lastMessageAt: lastAt is String ? DateTime.tryParse(lastAt) : null,
      unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
      decryptFailed: row['last_message_decrypt_failed'] == true,
    );
  }

  ChatInboxItem copyWith({int? unreadCount, bool? decryptFailed}) {
    return ChatInboxItem(
      chatId: chatId,
      type: type,
      peerId: peerId,
      peerUsername: peerUsername,
      peerAvatarUrl: peerAvatarUrl,
      lastMessageId: lastMessageId,
      lastMessageSenderId: lastMessageSenderId,
      lastMessageContent: lastMessageContent,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      decryptFailed: decryptFailed ?? this.decryptFailed,
    );
  }
}

/// The caller's inbox: every chat they participate in, most-recent-first.
/// Rows carry the E2EE last-message preview decrypted best-effort
/// ([ChatRepository.decryptInboxRow] — own messages via the outbox, peer
/// envelopes via the session, undecryptable → placeholder flag).
class ChatInboxNotifier extends AsyncNotifier<List<ChatInboxItem>> {
  ChatRepository get _repo => ref.read(chatE2eeRepositoryProvider);

  @override
  Future<List<ChatInboxItem>> build() async {
    final rows = await _repo.fetchInbox();
    final items = <ChatInboxItem>[];
    for (final row in rows) {
      final decrypted = await _repo.decryptInboxRow(row);
      items.add(ChatInboxItem.fromRow(decrypted));
    }
    return items;
  }

  /// Re-reads the inbox (pull-to-refresh, after realtime events, after a
  /// chat visit).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Marks [chatId] read server-side and refreshes the badge.
  Future<void> markRead(String chatId) async {
    try {
      await _repo.markChatRead(chatId);
    } catch (e, st) {
      AppLogger.instance.error('chat inbox markRead failed chat=$chatId: $e', '$st');
    }
    await refresh();
  }
}

/// The caller's inbox (autoDispose — a fresh read whenever the list screen
/// or the feed badge mounts).
final chatInboxProvider = AsyncNotifierProvider<ChatInboxNotifier,
    List<ChatInboxItem>>(ChatInboxNotifier.new);

/// Total unread messages across all chats — the feed button's badge number.
final chatUnreadCountProvider = Provider<int>((ref) {
  final inbox = ref.watch(chatInboxProvider);
  final items = inbox.valueOrNull;
  if (items == null) return 0;
  return items.fold(0, (sum, item) => sum + item.unreadCount);
});
