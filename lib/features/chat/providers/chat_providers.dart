import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/config/chat_constants.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/chat_repository.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/core/services/message_plaintext_store.dart';
import 'package:samay/core/utils/pagination.dart';
import 'package:samay/crypto/e2ee_key_store.dart';
import 'package:samay/crypto/e2ee_prekey_service.dart';
import 'package:samay/crypto/group_cipher.dart';
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
/// decrypts on load and on realtime delivery (E2EE §12.2 step 3). Decrypted
/// history is persisted in the encrypted Hive `message_cache` box (Signal
/// plaintext-store semantics, 2026-08-16) so a restart/update never turns
/// readable history into "Mensaje no descifrable" bubbles. The
/// [GroupE2eeCipher] (Signal sender keys, ISSUE 4 / D3) rides the same
/// key/session stores and enables the group-chat routing in the service.
final chatE2eeServiceProvider = Provider<ChatService>((ref) {
  return ChatService(
    client: ref.watch(supabaseClientProvider),
    realtime: ref.watch(realtimeServiceProvider),
    e2eeKeyStore: ref.watch(e2eeKeyStoreProvider),
    e2eeSessionStore: ref.watch(e2eeSessionStoreProvider),
    e2eePrekeyService: ref.watch(e2eePrekeyServiceProvider),
    plaintextStore: HiveMessagePlaintextStore(ref.watch(hiveServiceProvider)),
    groupCipher: GroupE2eeCipher(
      keyStore: ref.watch(e2eeKeyStoreProvider),
      sessionStore: ref.watch(e2eeSessionStoreProvider),
    ),
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

  /// Decrypted rows, oldest first, deterministically ordered by
  /// (`created_at`, `id`) — realtime arrivals are inserted at their sorted
  /// position ([insertMessage]) so a late-delivered older row can never sit
  /// at the tail of the thread (the pre-fix disorder: `addMessage` appended).
  ///
  /// `needsSession` rows (no local session — pre-reinstall history, Signal
  /// reinstall semantics 2026-08-16) and `decryptDropped` rows (protocol
  /// drops — replay/duplicate/stale identity, Signal silent-drop semantics
  /// 2026-08-16) are HIDDEN: after a reinstall the thread starts fresh and
  /// dropped rows never render. They remain in the paged core (pagination
  /// math counts raw rows; the service deletes the needsSession class
  /// server-side) — only the display surface filters them.
  List<Map<String, dynamic>> get messages => [
    for (final m in _paged.items)
      if (m['needsSession'] != true && m['decryptDropped'] != true) m,
  ];

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

  /// Deterministic thread order: (`created_at` asc, `id` asc). The secondary
  /// key makes same-timestamp rows stable (both devices supply client clocks,
  /// so equal timestamps are real) and matches the server's `id` tie-break.
  static int compareRows(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ta = _rowTime(a);
    final tb = _rowTime(b);
    if (ta != null && tb != null && ta != tb) return ta.compareTo(tb);
    final sa = a['created_at'];
    final sb = b['created_at'];
    if (sa is String && sb is String && sa != sb) return sa.compareTo(sb);
    final ia = a['id'];
    final ib = b['id'];
    if (ia is String && ib is String) return ia.compareTo(ib);
    return 0;
  }

  /// `created_at` as an epoch micros, or null when absent/unparseable.
  static int? _rowTime(Map<String, dynamic> row) {
    final raw = row['created_at'];
    if (raw is DateTime) return raw.microsecondsSinceEpoch;
    if (raw is String) return DateTime.tryParse(raw)?.microsecondsSinceEpoch;
    return null;
  }

  /// Sorts [rows] in thread order ([compareRows]) — the invariant applied at
  /// every mutation point (realtime insert, send, page merge).
  static List<Map<String, dynamic>> sortRows(List<Map<String, dynamic>> rows) {
    final sorted = [...rows]..sort(compareRows);
    return sorted;
  }

  /// The sender's id, if any, of a message row.
  static String? _senderIdOf(Map<String, dynamic> message) =>
      message['sender_id'] is String ? message['sender_id'] as String : null;

  /// Wraps a [PageLoader]-produced [PagedState] back into the chat state
  /// shape ([ChatMessagesNotifier] never does paging arithmetic itself).
  /// The merged rows are re-sorted in thread order — the page seam returns
  /// server order, which must never leak display disorder into the state.
  factory ChatMessagesState.fromPaged(
    PagedState<Map<String, dynamic>> paged,
  ) {
    return ChatMessagesState(
      messages: sortRows(paged.items),
      hasMore: paged.hasMore,
      loadingOlder: paged.loadingMore,
      pageSize: paged.pageSize,
      nextOffset: paged.nextOffset,
    );
  }

  /// A copy with [row] inserted at its sorted position (dedupe by id — the
  /// caller has already decided the row is new). Optimistic pending rows
  /// (`pending: true`) from the SAME sender are dropped when the confirmed
  /// server row arrives, so the placeholder can never survive next to its
  /// twin; a peer's row (or an unowned row) never touches local pendings.
  ChatMessagesState insertMessage(Map<String, dynamic> row) {
    final incomingSender = _senderIdOf(row);
    final committed = [
      for (final m in messages)
        if (m['pending'] != true || _senderIdOf(m) != incomingSender) m,
      row,
    ];
    return copyWith(messages: sortRows(committed));
  }

  /// A copy with the `read_at` of message [id] set to [readAt] — the live
  /// read-receipt flip (grey → blue double check). No-op when the message is
  /// not present.
  ChatMessagesState markRead(String id, DateTime? readAt) {
    final updated = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m['id'] == id) {
        updated.add({...m, if (readAt != null) 'read_at': readAt.toIso8601String()});
      } else {
        updated.add(m);
      }
    }
    return copyWith(messages: updated);
  }

  /// The per-member read receipts of [row] (20260817000006): the embedded
  /// `message_reads(user_id, read_at)` list, or an empty list when absent
  /// (1:1 rows, plaintext service, or old servers). Each entry is a
  /// `{user_id, read_at}` map — readers are OTHER members only (the RPC
  /// never marks the sender's own messages).
  static List<Map<String, dynamic>> readersOf(Map<String, dynamic> row) {
    final raw = row['message_reads'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// True when EVERY other member of a group has read [row] — the group
  /// blue-check gate (the ISSUE fix: blue ticks must require all readers,
  /// not just the first one). [otherMemberIds] is the CURRENT active
  /// roster's other-member ids: the readers must be a SUPERSET of them —
  /// a departed member's stale receipt can never satisfy the check (the
  /// verifier fix, 2026-08-17: reader count alone false-blues when a leaver
  /// read before leaving). Conservative: an unknown/empty roster never
  /// claims all-read (grey ticks — honest under stale data).
  static bool isReadByAll(Map<String, dynamic> row, Set<String> otherMemberIds) {
    if (otherMemberIds.isEmpty) return false;
    final reads = readersOf(row);
    if (reads.isEmpty) return false;
    final readers = reads.map((r) => r['user_id']).whereType<String>().toSet();
    return otherMemberIds.every(readers.contains);
  }

  /// A copy with one reader merged into message [id]'s `message_reads` set —
  /// the realtime `message-reads` INSERT merge (a member's device just
  /// marked the chat read). No-op when the message is not present.
  ChatMessagesState markMessageRead(String id, String userId, DateTime readAt) {
    final updated = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m['id'] == id) {
        final existing = readersOf(m);
        if (existing.any((r) => r['user_id'] == userId)) {
          updated.add(m);
          continue;
        }
        updated.add({
          ...m,
          'message_reads': [
            ...existing,
            {'user_id': userId, 'read_at': readAt.toIso8601String()},
          ],
        });
      } else {
        updated.add(m);
      }
    }
    return copyWith(messages: updated);
  }

  /// A copy without the pending (optimistic) message [id] — used to roll
  /// back a failed send.
  ChatMessagesState removeMessage(String id) {
    return copyWith(
      messages: [for (final m in messages) if (m['id'] != id) m],
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
  ///
  /// Optimistic pending row: the message bubble appears immediately (single
  /// grey check — WhatsApp "sent") instead of after the insert round-trip;
  /// the confirm path (refresh + the realtime echo) replaces it with the
  /// committed row (double grey check). On failure the pending row is
  /// removed and the error rethrown (the screen surfaces the snackbar).
  Future<void> send(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    final stopwatch = Stopwatch()..start();
    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final me = ref.read(authStateProvider).valueOrNull?.user?['id'];
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          messages: ChatMessagesState.sortRows([
            ...current.messages,
            {
              'id': pendingId,
              'sender_id': me,
              'content': text.trim(),
              'media_url': null,
              'created_at': DateTime.now().toIso8601String(),
              'pending': true,
            },
          ]),
        ),
      );
    }
    try {
      await _repo.sendMessage(chatId, text, null);
      await refresh();
      AppLogger.instance.debug(
        'chat provider send ok chat=$chatId ms=${stopwatch.elapsedMilliseconds}',
      );
    } catch (e, st) {
      final now = state.valueOrNull;
      if (now != null) {
        state = AsyncData(now.removeMessage(pendingId));
      }
      AppLogger.instance.error(
        'chat provider send failed chat=$chatId '
        'type=${e.runtimeType} ms=${stopwatch.elapsedMilliseconds}',
        '$st',
      );
      rethrow;
    }
  }

  /// Appends a realtime-delivered row at its sorted position, deduplicated
  /// by `id` (dispose-safe subscription wiring lives in the chat screen).
  /// Sorting is the disorder fix: a late-delivered older row can no longer
  /// sit at the tail of the thread.
  void addMessage(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String) return;
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncData(ChatMessagesState(messages: [row], hasMore: true));
      return;
    }
    if (current.messages.any((m) => m['id'] == id)) return;
    state = AsyncData(current.insertMessage(row));
  }

  /// Live read-receipt flip: message [id]'s `read_at` was stamped by the
  /// peer (realtime UPDATE event). Only the status field is merged — never
  /// content (the raw update row carries the envelope; this path is
  /// decrypt-free by design, see [ChatRepository.subscribeToMessageReads]).
  void updateMessageRead(String id, DateTime? readAt) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.markRead(id, readAt));
  }

  /// Live per-member read flip in a GROUP chat (20260817000006): one
  /// (message_id, user_id, read_at) receipt from the `message-reads`
  /// channel is merged into the row's read set — the sender's ticks flip
  /// blue only when EVERY other member has read.
  void markMessageRead(String messageId, String userId, DateTime readAt) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.markMessageRead(messageId, userId, readAt));
  }

  /// Delete-for-everyone (migration 20260815000006): the server verifies the
  /// sender + the 5-minute window with ITS clock; on success the row leaves
  /// the thread here and the peer's open thread removes it live via the
  /// realtime DELETE channel. The returned [MessageDeleteOutcome] drives the
  /// screen's copy (too-old snackbar etc.).
  Future<MessageDeleteOutcome> deleteForEveryone(
    String chatId,
    String messageId,
  ) async {
    final outcome = await _repo.deleteMessageForEveryone(messageId);
    if (outcome == MessageDeleteOutcome.deleted) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.removeMessage(messageId));
      }
    }
    return outcome;
  }

  /// Delete-for-me: hides the message on this device only (in-memory
  /// tombstone) — the server rows stay for the peer.
  Future<void> deleteForMe(String chatId, String messageId) async {
    await _repo.deleteMessageForMe(chatId, messageId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.removeMessage(messageId));
    }
  }

  /// A realtime DELETE event for [messageId] (the sender deleted for
  /// everyone, or the undecryptable cleanup): the row leaves the thread
  /// live.
  void removeDeletedMessage(String messageId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.removeMessage(messageId));
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
    this.referenceId,
    this.peerId,
    this.peerUsername,
    this.peerAvatarUrl,
    this.lastMessageId,
    this.lastMessageSenderId,
    this.lastMessageContent,
    this.lastMessageAt,
    this.lastActivityAt,
    this.lastActivityKind,
    this.lastNoticeSessionId,
    this.lastNoticeGameType,
    this.lastNoticeStatus,
    required this.unreadCount,
    this.decryptFailed = false,
  });

  final String chatId;
  final String type;

  /// The RPC row's `reference_id` — the group id for group chats (ISSUE 4:
  /// the chat screen uses it to open a group thread with sender labels).
  final String? referenceId;

  final String? peerId;
  final String? peerUsername;
  final String? peerAvatarUrl;
  final String? lastMessageId;
  final String? lastMessageSenderId;
  final String? lastMessageContent;
  final DateTime? lastMessageAt;

  /// The chat's most recent activity timestamp (a real message OR a minigame
  /// group notice, 210/P1) — the row's sort/time label.
  final DateTime? lastActivityAt;

  /// `message` | `minigame_notice` (210/P1). When `minigame_notice`, the tile
  /// previews the minigame notice instead of the (empty) message preview.
  final String? lastActivityKind;
  final String? lastNoticeSessionId;
  final String? lastNoticeGameType;
  final String? lastNoticeStatus;

  final int unreadCount;

  /// Whether the last-message envelope could not be decrypted (the UI
  /// renders [ChatService.chatUndecryptablePlaceholder] / "Tú: …").
  final bool decryptFailed;

  factory ChatInboxItem.fromRow(Map<String, dynamic> row) {
    final lastAt = row['last_message_created_at'];
    // No-session last message (pre-reinstall history): NO preview text — the
    // thread starts fresh (Signal reinstall semantics); the row is being
    // deleted server-side by the cleanup.
    final needsSession = row['last_message_needs_session'] == true;
    return ChatInboxItem(
      chatId: row['chat_id'] as String? ?? '',
      type: row['type'] as String? ?? 'direct',
      referenceId: row['reference_id'] as String?,
      peerId: row['peer_id'] as String?,
      peerUsername: row['peer_username'] as String?,
      peerAvatarUrl: row['peer_avatar_url'] as String?,
      lastMessageId: row['last_message_id'] as String?,
      lastMessageSenderId: row['last_message_sender_id'] as String?,
      lastMessageContent: needsSession
          ? null
          : row['last_message_content'] as String?,
      lastMessageAt: lastAt is String ? DateTime.tryParse(lastAt) : null,
      lastActivityAt: row['last_activity_at'] is String
          ? DateTime.tryParse(row['last_activity_at'] as String)
          : null,
      lastActivityKind: row['last_activity_kind'] as String?,
      lastNoticeSessionId: row['last_notice_session_id'] as String?,
      lastNoticeGameType: row['last_notice_game_type'] as String?,
      lastNoticeStatus: row['last_notice_status'] as String?,
      unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
      decryptFailed: !needsSession && row['last_message_decrypt_failed'] == true,
    );
  }

  ChatInboxItem copyWith({int? unreadCount, bool? decryptFailed}) {
    return ChatInboxItem(
      chatId: chatId,
      type: type,
      referenceId: referenceId,
      peerId: peerId,
      peerUsername: peerUsername,
      peerAvatarUrl: peerAvatarUrl,
      lastMessageId: lastMessageId,
      lastMessageSenderId: lastMessageSenderId,
      lastMessageContent: lastMessageContent,
      lastMessageAt: lastMessageAt,
      lastActivityAt: lastActivityAt,
      lastActivityKind: lastActivityKind,
      lastNoticeSessionId: lastNoticeSessionId,
      lastNoticeGameType: lastNoticeGameType,
      lastNoticeStatus: lastNoticeStatus,
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

/// The caller's read-receipts privacy switch (`users.read_receipts_enabled`,
/// default ON — WhatsApp's "read receipts" setting, 2026-08-15).
///
/// When OFF the reader's device stops calling `mark_messages_read`, so no
/// `read_at` is ever stamped and the peer never sees blue checks. The reader
/// always sees its own peers' receipts (symmetric by construction — each side
/// decides whether it SENDS them). Optimistic toggle with rollback; failures
/// are logged and surfaced to the settings row.
class ReadReceiptsNotifier extends AsyncNotifier<bool> {
  ChatRepository get _repo => ref.read(chatE2eeRepositoryProvider);

  @override
  Future<bool> build() async {
    try {
      return await _repo.getReadReceiptsEnabled();
    } catch (e, st) {
      AppLogger.instance.warn(
        'read receipts pref unreadable ($e); using default ON.',
        '$st',
      );
      return true;
    }
  }

  /// Toggles the switch. Optimistic; on persistence failure the value rolls
  /// back and the error is rethrown (the settings row surfaces it).
  Future<void> setEnabled(bool value) async {
    state = AsyncData(value);
    try {
      await _repo.setReadReceiptsEnabled(value);
    } catch (e, st) {
      AppLogger.instance.error(
        'read receipts pref save failed (rolling back): $e',
        '$st',
      );
      state = AsyncData(!value);
      rethrow;
    }
  }
}

/// The read-receipts privacy switch (autoDispose — a fresh read whenever the
/// settings row or a chat screen mounts).
final readReceiptsEnabledProvider = AsyncNotifierProvider<ReadReceiptsNotifier,
    bool>(ReadReceiptsNotifier.new);
