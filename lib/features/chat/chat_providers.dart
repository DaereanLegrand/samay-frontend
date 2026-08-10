import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/chat_repository.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/crypto/e2ee_key_store.dart';
import 'package:samay/crypto/e2ee_prekey_service.dart';
import 'package:samay/crypto/interfaces.dart';

/// Compile-time flag: when `true`, E2EE key/session material lives in
/// flutter_secure_storage ([SecureE2eeKeyStore]/[SecureE2eeSessionStore]).
/// Defaults to the in-memory stores until the secure-storage production
/// wiring lands (Android backup rules `allowBackup=false` + iOS keychain
/// entitlements — M-27/M-28 scope, E2EE-ARCHITECTURE.md §8.4); the memory
/// fallback is what tests and the current dev build use (documented).
const bool useSecureE2eeKeyStore = false;

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
/// messages per chat, so the client must not paginate past it — [loadOlder]
/// flips `hasMore` false at the cap (see [ChatMessagesNotifier]).
const int chatMessageCap = 1000;

/// The chat thread state: decrypted messages (oldest first) plus the
/// pagination flags the screen renders (I-56, CHAT spec).
class ChatMessagesState {
  const ChatMessagesState({
    required this.messages,
    required this.hasMore,
    this.loadingOlder = false,
  });

  /// Decrypted rows, oldest first.
  final List<Map<String, dynamic>> messages;

  /// Whether an older page is still available (server returned a full page
  /// on the last fetch and the message cap has not been reached).
  final bool hasMore;

  /// True while an older page is being fetched (loader row in the UI).
  final bool loadingOlder;

  ChatMessagesState copyWith({
    List<Map<String, dynamic>>? messages,
    bool? hasMore,
    bool? loadingOlder,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      loadingOlder: loadingOlder ?? this.loadingOlder,
    );
  }
}

class ChatMessagesNotifier
    extends FamilyAsyncNotifier<ChatMessagesState, String> {
  /// Next server offset for [loadOlder] (rows already consumed).
  int _offset = 0;

  /// Whether the server may hold an older page (recomputed per fetch).
  bool _hasMore = true;

  /// In-flight guard for [loadOlder] (L-07 concurrency guard — a second tap
  /// while fetching must not double-fetch).
  bool _loadingOlder = false;

  /// The E2EE seam (I-50): every message path goes through the injected
  /// [ChatService] — encrypt-on-send, decrypt-on-load. The provider must
  /// never touch the raw Supabase client (pinned by a `verifyNever` test in
  /// `test/features/chat/chat_pagination_test.dart`).
  ChatRepository get _repo => ref.read(chatE2eeRepositoryProvider);

  @override
  Future<ChatMessagesState> build(String chatId) async {
    // Family instances are long-lived (keep-alive provider); reset the
    // paging state on every (re)load so refresh() re-reads the first page.
    _offset = 0;
    _hasMore = true;
    _loadingOlder = false;
    final first = await _loadPage(chatId, 0);
    _offset = first.length;
    _hasMore = _fullPage(first.length) && _offset < chatMessageCap;
    return ChatMessagesState(messages: first, hasMore: _hasMore);
  }

  /// Re-runs [build] (after sending, pull-to-refresh).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Sends a message and reloads the thread. [chatE2eeRepositoryProvider]
  /// encrypts via [ChatService] before insert; the reload path decrypts.
  Future<void> send(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    await _repo.sendMessage(chatId, text, null);
    await refresh();
  }

  /// Appends a realtime-delivered row, deduplicated by `id` (dispose-safe
  /// subscription wiring lives in the chat screen).
  void addMessage(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String) return;
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncData(ChatMessagesState(messages: [row], hasMore: _hasMore));
      return;
    }
    if (current.messages.any((m) => m['id'] == id)) return;
    state = AsyncData(current.copyWith(messages: [...current.messages, row]));
  }

  /// Fetches the next older page ([chatPageSize] rows before the current
  /// window), prepends it (deduplicated by id — realtime rows may overlap
  /// page boundaries) and recomputes [ChatMessagesState.hasMore].
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
    if (current == null || _loadingOlder) return;
    if (!_hasMore || _offset >= chatMessageCap) {
      if (_hasMore) {
        _hasMore = false;
        state = AsyncData(current.copyWith(hasMore: false));
      }
      return;
    }
    _loadingOlder = true;
    state = AsyncData(current.copyWith(loadingOlder: true));
    try {
      final older = await _loadPage(arg, _offset);
      final existing = {
        for (final m in current.messages)
          if (m['id'] is String) m['id'] as String,
      };
      final deduped = [
        for (final m in older)
          if (m['id'] is String && !existing.contains(m['id'])) m,
      ];
      final merged = [...deduped, ...current.messages];
      _offset += older.length;
      _hasMore = _fullPage(older.length) && _offset < chatMessageCap;
      if (merged.length >= chatMessageCap) _hasMore = false;
      state = AsyncData(
        ChatMessagesState(messages: merged, hasMore: _hasMore),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingOlder: false));
      rethrow;
    } finally {
      _loadingOlder = false;
    }
  }

  Future<List<Map<String, dynamic>>> _loadPage(
    String chatId,
    int offset,
  ) {
    return _repo.loadMessages(chatId, limit: chatPageSize, offset: offset);
  }

  bool _fullPage(int fetched) => fetched == chatPageSize;
}

/// Messages of a chat (oldest first), decrypted; pagination (last 50 on
/// open, older pages via [ChatMessagesNotifier.loadOlder]) + send + refresh.
final chatMessagesProvider = AsyncNotifierProvider.family<ChatMessagesNotifier,
    ChatMessagesState, String>(ChatMessagesNotifier.new);
