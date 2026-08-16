import 'dart:async';

import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/message_plaintext_store.dart';
import 'package:samay/core/services/realtime_service.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/crypto/codec.dart';
import 'package:samay/crypto/group_cipher.dart';
import 'package:samay/crypto/interfaces.dart';
import 'package:samay/crypto/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Content stored for a message that could not be decrypted (tampered,
/// missing session, or a gap past MAX_SKIP). The UI renders it as
/// "Mensaje no descifrable" via l10n when the row carries
/// `decryptFailed: true` (E2EE-ARCHITECTURE.md §12.2 step 6).
const String chatUndecryptablePlaceholder = '[Mensaje no descifrable]';

/// Mirror of the `chat.message_cap` app_config key (default 1000) enforced
/// server-side by the `enforce_message_cap` trigger (TRIG spec / migration
/// 20260809000001) — the plaintext store is pruned to this per chat so the
/// local cache never outgrows what the server may store.
const int chatMessageCap = 1000;

/// Outcome of a delete-for-everyone attempt (migration 20260815000006).
enum MessageDeleteOutcome {
  /// The row was deleted server-side (audited in `deleted_messages`).
  deleted,

  /// The message is older than the 5-minute window (the SERVER clock's
  /// verdict via `messages.sent_at` — never the client's claim).
  tooOld,

  /// The caller is not the sender (server verdict; the UI restricts the
  /// option to own messages, so this is defensive only).
  notSender,

  /// The message row no longer exists.
  notFound,

  /// Transport/other failure — retry later.
  failed,
}

/// Chat messages: history, sending and realtime delivery.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
///
/// ## E2EE integration (I-38, E2EE-ARCHITECTURE.md §12.2 step 3)
///
/// When the three E2EE dependencies are injected ([E2eeKeyStore],
/// [E2eeSessionStore], [E2eePrekeyService]), `sendMessage` encrypts the
/// payload into a base64url envelope before insert (`messages.content` stays
/// the opaque envelope, E2EE §6.6), and `loadMessages`/`subscribeToMessages`
/// decrypt envelopes on the way out — the server never sees plaintext.
///
/// Without the dependencies the service behaves exactly as before (plaintext
/// path, used by non-E2EE call sites and tests).
///
/// ## Group chat E2EE (ISSUE 4 / D3)
///
/// When [GroupE2eeCipher] is additionally injected (`groupE2eeEnabled`),
/// group chats (`chats.type = 'group'`) route through the Signal sender-key
/// stack: `sendMessage` distributes the sender's chain bundle to every
/// member missing it (per-pairwise X3DH envelope rows addressed with
/// `recipient_id`, inserted BEFORE the single type-0x03 message row) and
/// `loadMessages`/`subscribeToMessages`/`decryptInboxRow` route inbound rows
/// by envelope type (0x03 → the group cipher; 0x01/0x02 → the pairwise
/// session, processing the bundle and hiding the row; `recipient_id` ≠ me →
/// silent skip). The roster is cached per chat and compared on every send:
/// any membership change wipes the group keys (fresh epoch) and
/// re-distributes the sender's chain to every remaining active member.
/// Without the dependency every pre-existing 1:1 path is byte-identical.
class ChatService {
  final SupabaseClient client;
  final RealtimeService realtime;
  final E2eeKeyStore? _e2eeKeyStore;
  final E2eeSessionStore? _e2eeSessionStore;
  final E2eePrekeyService? _e2eePrekeyService;
  final GroupE2eeCipher? _groupCipher;

  /// Encrypted plaintext store (Signal model, 2026-08-16 — the SQLCipher-
  /// equivalent Hive `message_cache` box on devices, in-memory in tests).
  ///
  /// The Double Ratchet is stateful and irreversible: an already-consumed
  /// message can NEVER be re-decrypted after the chain advanced. The server
  /// stores only envelopes, so history re-rendering after an app restart /
  /// update MUST come from this store — the pre-fix in-memory-only cache
  /// (`_decryptedByMessage`) turned every restart into a thread of
  /// "Mensaje no descifrable" bubbles.
  final MessagePlaintextStore? _plaintextStore;

  ChatService({
    required this.client,
    required this.realtime,
    E2eeKeyStore? e2eeKeyStore,
    E2eeSessionStore? e2eeSessionStore,
    E2eePrekeyService? e2eePrekeyService,
    MessagePlaintextStore? plaintextStore,
    GroupE2eeCipher? groupCipher,
  }) : _e2eeKeyStore = e2eeKeyStore,
       _e2eeSessionStore = e2eeSessionStore,
       _e2eePrekeyService = e2eePrekeyService,
       _plaintextStore = plaintextStore,
       _groupCipher = groupCipher;

  GoTrueClient get auth => client.auth;

  /// Whether E2EE is wired (session bootstrap + encrypt/decrypt active).
  bool get e2eeEnabled =>
      _e2eeKeyStore != null && _e2eeSessionStore != null && _e2eePrekeyService != null;

  /// Whether the group E2EE stack (Signal sender keys) is wired. Group chat
  /// routing activates ONLY when this is true — without it every path behaves
  /// exactly like the 1:1 service (backward compatible).
  bool get groupE2eeEnabled => _groupCipher != null;

  /// In-memory per-chat cipher instances (each bound to (chatId, peerUserId)).
  /// The map holds the creation Future so concurrent decrypt/send paths can
  /// never race two sessions into existence for the same chat (I-38).
  final Map<String, Future<E2eeMessageCipher>> _sessions = {};
  final Map<String, String> _peerCache = {};

  /// Cached `chats` row metadata per chat: type + reference_id (ISSUE 4).
  /// Group routing resolves the chat type exactly once per chat per process
  /// — the row is participant-readable (RLS `chats_read_participant`, whose
  /// group branch gates on ACTIVE membership).
  final Map<String, Future<_ChatInfo?>> _chatInfoCache = {};

  /// Cached active roster per group chat (ISSUE 4). Compared against the
  /// freshly fetched roster on every group send: any diff = membership
  /// change → the group keys are wiped (new epoch) and the sender's chain is
  /// re-distributed to every remaining active member.
  final Map<String, Set<String>> _rosterCache = {};

  /// Outbox: own sent envelope → plaintext. The sender cannot decrypt its
  /// own envelopes with the peer-bound session, so sent messages are shown
  /// from this in-memory map (E2EE §8.4: plaintext lives only in memory —
  /// after an app restart, own historical messages render as
  /// [chatUndecryptablePlaceholder], a documented MVP limitation).
  final Map<String, String> _outbox = {};

  /// Decrypted history is cached so re-loading a chat does not re-run the
  /// ratchet over already-consumed messages (an out-of-order replay would
  /// fail its AEAD binding and mark good messages as undecryptable).
  /// Memory-only (§8.4).
  final Map<String, Map<String, String>> _decryptedByMessage = {};

  /// Locally deleted messages (delete-for-me, 2026-08-16): chatId →
  /// messageIds. In-memory MVP tombstone — the server rows stay (the peer
  /// keeps them), only this device's thread hides them.
  final Map<String, Set<String>> _locallyDeleted = {};

  /// Per-chat serial executor for decryption: the ratchet session is
  /// stateful and must never process two envelopes concurrently (realtime
  /// bursts / subscribe+load overlap). Each call chains behind the previous
  /// one for the same chat (I-38).
  final Map<String, Future<void>> _decryptTail = {};

  /// Per-chat serial executor for SENDING (2026-08-16 re-audit, J1): the
  /// cipher state advances on EVERY encrypt — the 1:1 ratchet AND the group
  /// sender-key chain — so two in-flight [sendMessage] calls for the same
  /// chat must never run concurrently. Without serialization both calls
  /// load the same chain position and derive the same AEAD (key, nonce)
  /// (GCM nonce reuse), and the second message also drops as a replay on
  /// receivers. Each call chains the ENTIRE send body behind the previous
  /// one for the same chat (mirror of [_decryptTail]).
  final Map<String, Future<void>> _sendTail = {};

  Future<List<Map<String, dynamic>>> loadMessages(String chatId, {int limit = 50, int offset = 0}) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final stopwatch = Stopwatch()..start();
    final res = await client
        .from('messages')
        // `recipient_id` rides along (ISSUE 4): group distribution rows are
        // addressed to exactly one member — non-targets skip them silently.
        .select('id, sender_id, content, media_url, created_at, read_at, sent_at, recipient_id')
        .eq('chat_id', chatId)
        // `id` is the deterministic tie-break for equal `created_at` values
        // (both simulators supply client clocks; without it the server order
        // — and therefore the E2EE decrypt order — is non-deterministic for
        // same-timestamp rows).
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    final rows = (res as List).reversed.map((e) => Map<String, dynamic>.from(e)).toList();
    if (!e2eeEnabled) return rows;
    final decrypted = [for (final row in rows) await _decryptMessage(chatId, row)];
    // Bounded plaintext store (2026-08-16): keep at most the message cap per
    // chat. Best-effort.
    try {
      await _plaintextStore?.prune(chatId, chatMessageCap);
    } catch (e, st) {
      AppLogger.instance.warn('chat plaintext prune failed chat=$chatId: $e', '$st');
    }
    // Server offload (2026-08-16): rows that are permanently undecryptable
    // (no local session — pre-reinstall history) are deleted server-side so
    // the server never stores bytes nobody can ever read. Best-effort.
    await _deleteUndecryptable(chatId, decrypted);
    AppLogger.instance.debug(
      'chat loadMessages chat=$chatId offset=$offset rows=${rows.length} '
      'ms=${stopwatch.elapsedMilliseconds}',
    );
    return decrypted;
  }

  /// Sends a message: sanitizes [content], encrypts it (when E2EE is wired)
  /// and inserts the row.
  ///
  /// Serialized per chat on [_sendTail] (2026-08-16 re-audit, J1): the
  /// cipher state advances on every encrypt, so two in-flight sends for the
  /// same chat must run one after the other — both the 1:1 ratchet and the
  /// group sender-key chain would otherwise derive two envelopes from the
  /// same chain position (identical AEAD key + nonce = GCM nonce reuse; the
  /// second message also drops as a replay on receivers). The chained
  /// future completes with the SAME errors as the direct call (each caller
  /// observes its own exception).
  Future<void> sendMessage(String chatId, String content, String? mediaUrl) {
    final completer = Completer<void>();
    final tail = _sendTail[chatId] ?? Future<void>.value();
    _sendTail[chatId] = tail.then((_) async {
      try {
        await _sendMessageNow(chatId, content, mediaUrl);
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<void> _sendMessageNow(
    String chatId,
    String content,
    String? mediaUrl,
  ) async {
    final stopwatch = Stopwatch()..start();
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    AppLogger.instance.debug(
      'chat sendMessage start chat=$chatId e2ee=$e2eeEnabled chars=${content.length}',
    );
    var sanitized = InputSanitizer.sanitize(
      content,
      maxLength: InputSanitizer.messageMaxLength,
    );
    E2eeMessageCipher? sentCipher;
    var wasInit = false;
    if (e2eeEnabled) {
      // Session bootstrap (E2EE §12.2 step 2): ensure our own bundle is
      // published before the first X3DH initiate of this chat.
      if (!_sessions.containsKey(chatId)) {
        await _e2eePrekeyService!.publishAll();
        AppLogger.instance.debug(
          'chat sendMessage publishAll done chat=$chatId '
          'ms=${stopwatch.elapsedMilliseconds}',
        );
      }
      // Group chats (ISSUE 4 / D3): Signal sender keys. The 1:1 branch below
      // is NEVER taken for a group chat — _resolvePeerUserId is 1:1-only.
      if (groupE2eeEnabled && (await _chatInfo(chatId))?.type == 'group') {
        await _sendGroupMessage(chatId, sanitized, user.id, stopwatch);
        return;
      }
      sentCipher = await _cipherFor(chatId);
      final envelope = await sentCipher.encrypt(
        chatId: chatId,
        peerUserId: await _resolvePeerUserId(chatId),
        plaintext: sanitized,
      );
      wasInit = sentCipher.envelopeIsInit(envelope);
      AppLogger.instance.debug(
        'chat sendMessage encrypt done chat=$chatId '
        'type=${wasInit ? "init(0x01)" : "ratchet(0x02)"} '
        'envelopeBytes=${envelope.length} ms=${stopwatch.elapsedMilliseconds}',
      );
      _outbox[envelope] = sanitized;
      sanitized = envelope;
    }
    try {
      await client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': user.id,
        'content': sanitized,
        'media_url': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // The PostgREST status/code are the server's verdict on the insert
      // (RLS policy rejection, trigger failure, constraint) — log them raw.
      if (e is PostgrestException) {
        AppLogger.instance.error(
          'chat sendMessage INSERT failed chat=$chatId '
          'code=${e.code} '
          'message="${e.message}" details="${e.details}" hint="${e.hint}" '
          'ms=${stopwatch.elapsedMilliseconds}',
        );
      } else {
        AppLogger.instance.error(
          'chat sendMessage INSERT failed chat=$chatId '
          'type=${e.runtimeType} ms=${stopwatch.elapsedMilliseconds}',
        );
      }
      // Session/insert atomicity (2026-08-15): when the failed envelope was
      // the session's INIT, the peer never received it. The persisted session
      // still believes it did (has_sent_init=true) and the next retry would
      // send an undecryptable ratchet message into a session the peer never
      // saw. Roll the session back so the next send re-initiates fresh X3DH.
      if (wasInit && sentCipher != null) {
        AppLogger.instance.warn(
          'chat sendMessage rolled back session chat=$chatId — init envelope '
          'INSERT failed, next send re-initiates (E2EE session/insert '
          'atomicity)',
        );
        await sentCipher.wipe();
        _sessions.remove(chatId);
      }
      rethrow;
    }
    AppLogger.instance.debug(
      'chat sendMessage ok chat=$chatId ms=${stopwatch.elapsedMilliseconds}',
    );
  }

  /// Group-chat send (ISSUE 4 / D3, Signal sender keys).
  ///
  /// Row order on the wire (realtime delivers in channel order, so receivers
  /// process bundles BEFORE the message):
  ///
  /// (a) one distribution row per member missing the sender's chain —
  ///     `recipient_id` = the target member, `content` = the
  ///     per-pairwise-session envelope (X3DH: the distributor is the
  ///     initiator, the target is the responder) of the bundle JSON;
  /// (b) the single type-0x03 sender-key message row (`recipient_id` NULL).
  ///
  /// Resilient distribution (2026-08-17 live finding: "send does not
  /// allow"): each member's distribution is wrapped in its own try/catch —
  /// a member with NO published prekey bundle (never ran the app / fresh
  /// install) fails the pairwise X3DH `fetchBundle`; pre-fix that ONE
  /// failure threw the whole send. Now the member is logged (id only, never
  /// key material) and SKIPPED — the reachable members still get their
  /// distribution and the message row always lands. The distribution target
  /// is persisted via [GroupE2eeCipher.markSenderKeyDistributed] only AFTER
  /// a successful insert, so a failed member stays missing for the next
  /// send (it is never permanently dropped). The message-row insert sits
  /// OUTSIDE the per-member loop — a distribution failure must never block
  /// the message.
  ///
  /// Roster/epoch management (HARD REQUIREMENT): the active roster is
  /// fetched from `chat_participants` before every send (D1's triggers keep
  /// it equal to the ACTIVE `group_members`; readable via RLS
  /// `cp_read_participant` — the documented roster source) and compared to
  /// the cached roster:
  ///
  /// - any change (member added OR removed) → `wipeGroupKeys` (fresh epoch —
  ///   a removed member's chain copies are useless going forward), which
  ///   bumps the group epoch and clears the registry's distribution sets,
  ///   so `membersMissingSenderKey` reports every other active member and
  ///   the OWN chain is minted fresh + re-distributed to all of them
  ///   (receivers holding the old-epoch record accept the fresh bundle —
  ///   epoch-based rekey);
  /// - no change → lazy heal: distribute to `membersMissingSenderKey(...)`
  ///   only.
  ///
  /// A chat with only the sender distributes to zero members → just the
  /// message row.
  Future<void> _sendGroupMessage(
    String chatId,
    String sanitized,
    String senderId,
    Stopwatch stopwatch,
  ) async {
    // This method is only reachable when groupE2eeEnabled; the local makes
    // the non-null cipher explicit for the whole body.
    final cipher = _groupCipher!;
    final info = await _chatInfo(chatId);
    final groupId = info?.referenceId;
    if (groupId == null) {
      throw Exception('Group chat $chatId has no reference_id');
    }
    final roster = await _fetchRoster(chatId);
    final previous = _rosterCache[chatId];
    if (previous != null && !_sameMembers(previous, roster)) {
      await cipher.wipeGroupKeys(chatId);
      AppLogger.instance.debug(
        'chat group roster CHANGED chat=$chatId — wiped sender keys, '
        're-distributing to every active member (new epoch)',
      );
    }
    _rosterCache[chatId] = roster;

    final missing = await cipher.membersMissingSenderKey(
      groupChatId: chatId,
      senderUserId: senderId,
      activeMemberIds: (roster.toList()..sort()),
    );
    // (a) distribution rows first — per-member: a member whose pairwise
    // session cannot be established (no published prekey bundle) is
    // SKIPPED, never fatal. Only successfully-inserted members are marked
    // distributed, so a failed member stays missing for the next send.
    for (final member in missing) {
      try {
        final bundleJson = await cipher.senderKeyBundleJson(
          groupChatId: chatId,
          senderUserId: senderId,
          groupId: groupId,
        );
        final pair = await _pairwiseCipherFor(chatId, member);
        final envelope = await pair.encrypt(
          chatId: _pairwiseSessionKey(chatId, member),
          peerUserId: member,
          plaintext: bundleJson,
        );
        await client.from('messages').insert({
          'chat_id': chatId,
          'sender_id': senderId,
          'content': envelope,
          'recipient_id': member,
          'created_at': DateTime.now().toIso8601String(),
        });
        await cipher.markSenderKeyDistributed(
          groupChatId: chatId,
          senderUserId: senderId,
          memberIds: [member],
        );
      } catch (e, st) {
        AppLogger.instance.warn(
          'chat sendMessage(group) distribution SKIPPED chat=$chatId '
          'member=$member type=${e.runtimeType} — no pairwise session '
          '(member has no published prekey bundle); the member stays '
          'missing and the next send retries',
          '$st',
        );
      }
    }
    try {
      // (b) the single sender-key message row — OUTSIDE the per-member
      // loop: a distribution failure must never block the message.
      final envelope = await cipher.encrypt(
        groupChatId: chatId,
        senderUserId: senderId,
        groupId: groupId,
        plaintext: sanitized,
      );
      _outbox[envelope] = sanitized;
      await client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': senderId,
        'content': envelope,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (e is PostgrestException) {
        AppLogger.instance.error(
          'chat sendMessage(group) INSERT failed chat=$chatId '
          'code=${e.code} message="${e.message}" details="${e.details}" '
          'hint="${e.hint}" ms=${stopwatch.elapsedMilliseconds}',
        );
      } else {
        AppLogger.instance.error(
          'chat sendMessage(group) failed chat=$chatId '
          'type=${e.runtimeType} ms=${stopwatch.elapsedMilliseconds}',
        );
      }
      rethrow;
    }
    AppLogger.instance.debug(
      'chat sendMessage(group) ok chat=$chatId distributed=${missing.length} '
      'ms=${stopwatch.elapsedMilliseconds}',
    );
  }

  /// The active roster of group chat [chatId], from `chat_participants` (the
  /// trigger-maintained mirror of ACTIVE `group_members` — migration
  /// 20260817000002; RLS `cp_read_participant`). Includes the caller — the
  /// cipher subtracts the sender itself when computing missing members.
  Future<Set<String>> _fetchRoster(String chatId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('chat_participants')
        .select('user_id')
        .eq('chat_id', chatId);
    return (res as List)
        .whereType<Map>()
        .map((e) => e['user_id'] as String)
        .toSet();
  }

  static bool _sameMembers(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  /// Pairwise session for group DISTRIBUTION only (ISSUE 4 / D3): the
  /// synthetic store key `g:<chatId>:<peerUserId>` lives inside the existing
  /// [E2eeSessionStore] (the store is key-agnostic; `sessionIndex` has no
  /// consumers). The recipient resolves the session by the row's sender_id.
  /// NEVER keyed by the real chatId — that is the 1:1 namespace.
  Future<E2eeMessageCipher> _pairwiseCipherFor(
    String groupChatId,
    String peerUserId,
  ) {
    final key = _pairwiseSessionKey(groupChatId, peerUserId);
    return _sessions.putIfAbsent(key, () async {
      return E2eeSession(
        chatId: key,
        peerUserId: peerUserId,
        keyStore: _e2eeKeyStore!,
        sessionStore: _e2eeSessionStore!,
        prekeyService: _e2eePrekeyService!,
      );
    });
  }

  /// The synthetic pairwise-session namespace key for group distribution.
  static String _pairwiseSessionKey(String groupChatId, String peerUserId) =>
      'g:$groupChatId:$peerUserId';

  /// Resolves and caches the `chats` row metadata for [chatId]
  /// (`type`, `reference_id`). Group routing guards on `type == 'group'`.
  /// The row is participant-readable (RLS `chats_read_participant` — the
  /// group branch gates on ACTIVE membership, migration 20260817000002).
  Future<_ChatInfo?> _chatInfo(String chatId) {
    return _chatInfoCache.putIfAbsent(chatId, () async {
      final res = await client
          .from('chats')
          .select('type, reference_id')
          .eq('id', chatId)
          .maybeSingle();
      if (res == null) return null;
      return _ChatInfo(
        type: res['type'] as String? ?? 'direct',
        referenceId: res['reference_id'] as String?,
      );
    });
  }

  /// The `reference_id` of chat [chatId] (the group id for group chats), or
  /// null when the chat row is unreadable/absent. Consumed by callers that
  /// need the domain id behind a chat — e.g. navigating from a group into
  /// its E2EE chat. Group routing resolves this internally (cached).
  Future<String?> getChatReferenceId(String chatId) async {
    final info = await _chatInfo(chatId);
    return info?.referenceId;
  }

  /// Creates (or reuses) a direct chat with [peerUserId] and returns its id.
  ///
  /// Goes through the `create_direct_chat` SECURITY DEFINER RPC (migration
  /// 20260814000001 — the SQL stand-in while EEDG stays blocked, same
  /// pattern as `validate_qr_token`): `chats_insert_related` forbids
  /// client-side direct-chat inserts (the caller is not a participant yet),
  /// so the RPC creates the chat row + both participant rows atomically and
  /// returns the existing chat when the pair already has one. This is the
  /// missing first step of the live E2EE path — without a `chat_participants`
  /// row for the peer, `_resolvePeerUserId` sees an empty peer list and
  /// `sendMessage` throws.
  Future<String> createDirectChat(String peerUserId) async {
    final res = await client.rpc('create_direct_chat', params: {
      'p_peer_id': peerUserId,
    });
    final data = Map<String, dynamic>.from(res as Map);
    final chatId = data['chatId'];
    if (chatId is! String) {
      throw Exception('create_direct_chat returned no chatId');
    }
    return chatId;
  }

  /// The caller's chat inbox (migration 20260815000004): every chat they
  /// participate in, ordered most-recent-first, with the peer identity, the
  /// last message (its `content` is the E2EE envelope — the server never
  /// sees plaintext; the client decrypts for the preview) and the unread
  /// count (messages from the peer newer than the caller's read watermark).
  ///
  /// Rows keep `Map<String, dynamic>` shape (the inbox preview decrypts via
  /// the same per-chat cipher path as the thread).
  Future<List<Map<String, dynamic>>> fetchInbox() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client.rpc('get_chat_inbox');
    return (res as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Bumps the caller's read watermark for [chatId] (self-only RPC) — the
  /// unread badge for that chat drops to zero. Call after a successful
  /// first-page load of the thread.
  Future<void> markChatRead(String chatId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client.rpc('mark_chat_read', params: {'p_chat_id': chatId});
  }

  /// Stamps `read_at` on every unread message FROM THE CALLER'S PEER in
  /// [chatId] (self-only RPC, migration 20260815000005) — the sender's open
  /// thread flips grey → blue double checks via realtime UPDATE events.
  ///
  /// The client calls this only when the caller's own `read_receipts_enabled`
  /// is on: with receipts disabled nothing is ever stamped, so the peer never
  /// sees blue checks (WhatsApp's read-receipts privacy semantics).
  Future<void> markMessagesRead(String chatId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client.rpc('mark_messages_read', params: {'p_chat_id': chatId});
  }

  /// The caller's read-receipts privacy switch (`users.read_receipts_enabled`,
  /// default true). When OFF the client must not call [markMessagesRead] —
  /// no read receipts are sent to peers.
  Future<bool> getReadReceiptsEnabled() async {
    final user = auth.currentUser;
    if (user == null) return true;
    final res = await client
        .from('users')
        .select('read_receipts_enabled')
        .eq('id', user.id)
        .maybeSingle();
    return res?['read_receipts_enabled'] != false;
  }

  /// Persists the caller's read-receipts switch (own-row only — the
  /// `users_update_own` RLS policy; same seam as `discovery_opt_in`).
  Future<void> setReadReceiptsEnabled(bool value) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client
        .from('users')
        .update({'read_receipts_enabled': value})
        .eq('id', user.id);
  }

  /// Subscribes to `read_at` flips for [chatId]'s messages (realtime UPDATE
  /// events on `messages` — RLS restricts delivery to participants). Rows
  /// arrive as raw envelopes and MUST only be used for their `read_at`:
  /// the content field is never touched on this path (no decryption — the
  /// sender already holds the plaintext).
  RealtimeChannel subscribeToMessageReads(
    String chatId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    return realtime.subscribeToChannel(
      'messages:reads:$chatId',
      PostgresChangeEvent.update,
      'messages',
      onUpdate,
    );
  }

  /// Best-effort decryption of an inbox row's last-message envelope — the
  /// same path as the thread ([_decryptMessage]): own messages render from
  /// the outbox, peer envelopes decrypt via the per-chat session,
  /// undecryptable → [chatUndecryptablePlaceholder] + `decryptFailed`.
  /// Never throws. The returned row carries the plaintext under
  /// `last_message_content` (the thread-row contract, prefixed for the
  /// inbox shape).
  Future<Map<String, dynamic>> decryptInboxRow(Map<String, dynamic> row) async {
    final chatId = row['chat_id'];
    if (chatId is! String) {
      return {...row, 'last_message_decrypt_failed': false};
    }
    if (!e2eeEnabled) {
      return {...row, 'last_message_decrypt_failed': false};
    }
    // Group distribution rows (ISSUE 4 / D3, fix round 20260817000004):
    // the inbox carries the last message's recipient_id, so a row addressed
    // to ANOTHER member is skipped BEFORE any decrypt attempt — silently,
    // never a bubble (the per-pairwise envelope is not ours to open).
    final userId = auth.currentUser?.id;
    final recipientId = row['last_message_recipient_id'];
    if (row['type'] == 'group' && recipientId is String && recipientId != userId) {
      return {
        ...row,
        'last_message_content': null,
        'last_message_decrypt_failed': false,
      };
    }
    final last = {
      'id': row['last_message_id'],
      'sender_id': row['last_message_sender_id'],
      'content': row['last_message_content'],
    };
    final decrypted = await _decryptMessage(chatId, last);
    if (decrypted['needsSession'] == true) {
      await _deleteUndecryptable(chatId, [decrypted]);
    }
    if (decrypted['decryptDropped'] == true) {
      // Signal semantics: a protocol-level drop (duplicate/stale) renders
      // NO preview — never the envelope, never the bubble flag.
      return {
        ...row,
        'last_message_content': null,
        'last_message_decrypt_failed': false,
      };
    }
    return {
      ...row,
      'last_message_content': decrypted['content'],
      'last_message_decrypt_failed': decrypted['decryptFailed'] == true,
      'last_message_needs_session': decrypted['needsSession'] == true,
    };
  }

  /// Best-effort server-side cleanup of permanently undecryptable rows
  /// (no-session class, 2026-08-16): after a reinstall/identity change these
  /// rows can never be decrypted by anyone — delete them to offload the
  /// server (`delete_undecryptable_messages`, migration 20260815000006,
  /// participant-gated, audited in `deleted_messages`). Missing-RPC (old
  /// server) or RLS errors are logged and ignored: the rows stay hidden on
  /// this device and the next load retries.
  Future<void> _deleteUndecryptable(
    String chatId,
    List<Map<String, dynamic>> rows,
  ) async {
    // Group chats never carry the no-session class (ISSUE 4 / D3): for
    // groups, undecryptable rows STAY — the roster-change rekey heals them.
    if (groupE2eeEnabled && (await _chatInfo(chatId))?.type == 'group') {
      return;
    }
    final ids = <String>[
      for (final r in rows)
        if (r['needsSession'] == true && r['id'] is String) r['id'] as String,
    ];
    if (ids.isEmpty) return;
    try {
      final res = await client.rpc(
        'delete_undecryptable_messages',
        params: {'p_chat_id': chatId, 'p_message_ids': ids},
      );
      AppLogger.instance.debug(
        'chat undecryptable cleanup chat=$chatId ids=${ids.length} '
        'deleted=$res',
      );
    } catch (e, st) {
      if (e is PostgrestException) {
        AppLogger.instance.warn(
          'chat undecryptable cleanup SKIPPED chat=$chatId '
          'code=${e.code} message="${e.message}" — rows stay hidden, '
          'next load retries',
        );
      } else {
        AppLogger.instance.warn(
          'chat undecryptable cleanup failed chat=$chatId: $e',
          '$st',
        );
      }
    }
  }

  /// Subscribes to live inserts for [chatId]. Rows arrive as raw envelopes
  /// and are decrypted before [onInsert] sees them (E2EE §9.4: realtime
  /// carries ciphertext only). Rows that fail with no session (needsSession)
  /// never reach the UI — they are deleted server-side instead. Returns the
  /// channel so callers can unsubscribe on dispose.
  RealtimeChannel subscribeToMessages(
    String chatId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
    return realtime.subscribeToMessages(chatId, (row) async {
      if (e2eeEnabled) {
        final decrypted = await _decryptMessage(chatId, row);
        if (decrypted['needsSession'] == true) {
          await _deleteUndecryptable(chatId, [decrypted]);
          return;
        }
        if (decrypted['decryptDropped'] == true) {
          // Signal semantics: silently dropped duplicates/stale rows never
          // reach the UI.
          return;
        }
        onInsert(decrypted);
      } else {
        onInsert(row);
      }
    });
  }

  /// Subscribes to live DELETEs for [chatId] (hard deletes — delete-for-
  /// everyone from the sender's device, or the undecryptable cleanup). The
  /// peer's open thread removes the row live (REPLICA IDENTITY FULL delivers
  /// the old record). Returns the channel so callers can unsubscribe.
  RealtimeChannel subscribeToMessageDeletes(
    String chatId,
    void Function(Map<String, dynamic>) onDelete,
  ) {
    return realtime.subscribeToChannel(
      'messages:deletes:$chatId',
      PostgresChangeEvent.delete,
      'messages',
      onDelete,
    );
  }

  /// Delete-for-everyone (migration 20260815000006): sender-only + a 5-minute
  /// window verified with the SERVER's clock (`messages.sent_at` — the
  /// client can never extend it). The outcome drives the UI copy.
  Future<MessageDeleteOutcome> deleteMessageForEveryone(String messageId) async {
    try {
      await client.rpc(
        'delete_message_for_everyone',
        params: {'p_message_id': messageId},
      );
      AppLogger.instance.debug(
        'chat delete-for-everyone ok msg=$messageId',
      );
      return MessageDeleteOutcome.deleted;
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (msg.contains('MESSAGE_TOO_OLD')) return MessageDeleteOutcome.tooOld;
      if (msg.contains('NOT_THE_SENDER')) return MessageDeleteOutcome.notSender;
      if (msg.contains('MESSAGE_NOT_FOUND')) return MessageDeleteOutcome.notFound;
      AppLogger.instance.warn(
        'chat delete-for-everyone FAILED msg=$messageId '
        'code=${e.code} message="$msg"',
      );
      return MessageDeleteOutcome.failed;
    } catch (e, st) {
      AppLogger.instance.warn(
        'chat delete-for-everyone FAILED msg=$messageId '
        'type=${e.runtimeType}',
        '$st',
      );
      return MessageDeleteOutcome.failed;
    }
  }

  /// Delete-for-me (2026-08-16): hides the message on THIS device only —
  /// the server rows stay (the peer keeps them). In-memory MVP tombstone,
  /// plus the encrypted plaintext-store entry is removed (a tombstoned
  /// message must not resurface from the cache).
  Future<void> deleteMessageForMe(String chatId, String messageId) async {
    (_locallyDeleted[chatId] ??= {}).add(messageId);
    _decryptedByMessage[chatId]?.remove(messageId);
    try {
      await _plaintextStore?.delete(chatId, messageId);
    } catch (e, st) {
      AppLogger.instance.warn(
        'chat plaintext cache delete failed chat=$chatId msg=$messageId: $e',
        '$st',
      );
    }
    AppLogger.instance.debug(
      'chat delete-for-me chat=$chatId msg=$messageId',
    );
  }

  /// Whether [messageId] was locally deleted for this chat (delete-for-me
  /// tombstone — the provider drops it from the thread).
  bool isLocallyDeleted(String chatId, String messageId) =>
      _locallyDeleted[chatId]?.contains(messageId) ?? false;

  /// Whether the peer's published identity differs from the one bound to the
  /// stored session (E2EE §7.5 reinstall detection). False when there is no
  /// session yet (nothing bound to compare against). Note: `fetch_prekey_bundle`
  /// is the only read path and consumes one of the peer's one-time prekeys
  /// server-side — called once per chat open, never per message.
  Future<bool> peerNeedsRekey(String chatId) async {
    if (!e2eeEnabled) return false;
    // Groups have no pairwise peer (ISSUE 4): the group rekey machinery is
    // the roster-change wipe in _sendGroupMessage, never the 1:1 identity
    // comparison.
    if (groupE2eeEnabled && (await _chatInfo(chatId))?.type == 'group') {
      return false;
    }
    try {
      final cipher = await _cipherFor(chatId);
      return await cipher.peerIdentityChanged(
        await _resolvePeerUserId(chatId),
      );
    } catch (e, st) {
      AppLogger.instance.warn(
        'chat peerNeedsRekey failed chat=$chatId: $e',
        '$st',
      );
      return false;
    }
  }

  /// Decrypts [row]'s envelope in place. Never throws (E2EE §12.2 step 6):
  /// an undecryptable message yields `decryptFailed: true` with the
  /// [chatUndecryptablePlaceholder] content; a missing session yields the
  /// same marker so the UI can prompt for re-key. Own sent messages render
  /// from the in-memory outbox (the sender's envelopes are not decryptable
  /// with the peer-bound session).
  /// Serialized entry point for [decryptMessageNow] (one envelope at a time
  /// per chat, in delivery order).
  Future<Map<String, dynamic>> _decryptMessage(
    String chatId,
    Map<String, dynamic> row,
  ) {
    final completer = Completer<Map<String, dynamic>>();
    final tail = _decryptTail[chatId] ?? Future<void>.value();
    _decryptTail[chatId] = tail.then((_) async {
      try {
        completer.complete(await _decryptMessageNow(chatId, row));
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<Map<String, dynamic>> _decryptMessageNow(
    String chatId,
    Map<String, dynamic> row,
  ) async {
    final envelope = row['content'];
    if (envelope is! String) return row;
    final messageId = row['id'];
    if (messageId is String) {
      final cached = _decryptedByMessage[chatId]?[messageId];
      if (cached != null) {
        row['content'] = cached;
        row['decryptFailed'] = false;
        return row;
      }
      // Signal plaintext-store (2026-08-16): history re-rendered after an
      // app restart must come from the encrypted cache — the ratchet chain
      // has already advanced past these messages and can never re-decrypt
      // them. Serve the cache BEFORE any crypto.
      final persisted = await _plaintextStore?.get(chatId, messageId);
      if (persisted != null) {
        (_decryptedByMessage[chatId] ??= {})[messageId] = persisted;
        row['content'] = persisted;
        row['decryptFailed'] = false;
        return row;
      }
    }
    final userId = auth.currentUser?.id;
    if (userId != null && row['sender_id'] == userId) {
      final plaintext = _outbox[envelope];
      if (plaintext != null) {
        row['content'] = plaintext;
        row['decryptFailed'] = false;
        if (messageId is String) {
          (_decryptedByMessage[chatId] ??= {})[messageId] = plaintext;
          await _cachePlaintext(chatId, messageId, plaintext);
        }
        return row;
      }
    }
    // Group chat routing (ISSUE 4 / D3): type-0x03 envelopes decrypt via the
    // group cipher; 0x01/0x02 envelopes are pairwise DISTRIBUTION rows
    // (process the bundle, hide the row); rows addressed to another member
    // are skipped silently. The 1:1 cipher path below is never taken for
    // group rows (it would resolve a "peer" and mis-route the row).
    if (groupE2eeEnabled) {
      final info = await _chatInfo(chatId);
      if (info?.type == 'group') {
        return _decryptGroupRow(chatId, row, info!.referenceId);
      }
    }
    try {
      final cipher = await _cipherFor(chatId);
      final result = await cipher.decrypt(
        chatId: chatId,
        peerUserId: await _resolvePeerUserId(chatId),
        envelope: envelope,
      );
      final plaintext = result.plaintext;
      if (plaintext != null) {
        row['content'] = plaintext;
        row['decryptFailed'] = false;
        if (messageId is String) {
          (_decryptedByMessage[chatId] ??= {})[messageId] = plaintext;
          await _cachePlaintext(chatId, messageId, plaintext);
        }
        return row;
      }
      if (result.dropped) {
        // Signal semantics (2026-08-16): a protocol-level drop — replay/
        // duplicate, stale identity, missing prekey material — is SILENT:
        // the row never renders and is never bubble-marked. Against an
        // EXISTING session the server row stays (a later fresh init may
        // still re-establish); with NO session the row is the pre-reinstall
        // class → needsSession (hidden + server-side offload below).
        if (!await _sessionExistsFor(chatId)) {
          row['needsSession'] = true;
          row['decryptFailed'] = false;
          return row;
        }
        row['decryptDropped'] = true;
        row['decryptFailed'] = false;
        return row;
      }
    } catch (e, st) {
      AppLogger.instance.warn(
        'chat decrypt threw chat=$chatId msg=$messageId '
        'type=${e.runtimeType}: $e',
        '$st',
      );
    }
    // No-session class (2026-08-16, Signal reinstall semantics): when NO
    // session exists for the chat, the failure means pre-reinstall history —
    // the old identity/ratchet keys are gone forever, so the message is
    // never decryptable by ANYONE. The UI hides these rows (pure Signal:
    // after a reinstall the thread starts fresh) and the service deletes
    // them server-side (offload). The placeholder bubble survives ONLY for
    // failures against an EXISTING session (tamper / skip-gap — the case
    // Signal itself error-bubbles).
    if (!await _sessionExistsFor(chatId)) {
      row['needsSession'] = true;
      row['decryptFailed'] = false;
      return row;
    }
    AppLogger.instance.warn(
      'chat decrypt failed chat=$chatId msg=$messageId — undecryptable '
      '(genuine failure; see above)',
    );
    row['content'] = chatUndecryptablePlaceholder;
    row['decryptFailed'] = true;
    return row;
  }

  /// Decrypts one group-chat row (ISSUE 4 / D3). Never throws.
  ///
  /// - `recipient_id` set and != me → silent skip: no decrypt attempt, no
  ///   bubble (the distribution envelope is addressed to ONE member).
  /// - type 0x03 (sender-key message) → [GroupE2eeCipher.decrypt]:
  ///   plaintext → bubble AND cached into the plaintext store (the encrypted
  ///   Hive cache must serve group history across restarts, same as 1:1);
  ///   dropped → hidden row; failed → the [chatUndecryptablePlaceholder]
  ///   bubble ("Mensaje no descifrable").
  /// - type 0x01/0x02 (distribution) → the pairwise session with the row's
  ///   sender; a bundle plaintext → [GroupE2eeCipher.processSenderKeyBundle],
  ///   then the row is hidden (never a bubble). Any pairwise failure →
  ///   hidden + logged (the next send re-distributes).
  ///
  /// The no-session class does not apply to groups: undecryptable rows STAY
  /// — the roster-change rekey heals them.
  Future<Map<String, dynamic>> _decryptGroupRow(
    String chatId,
    Map<String, dynamic> row,
    String? groupId,
  ) async {
    // Only reachable when groupE2eeEnabled (see the routing guard); the
    // local makes the non-null cipher explicit for the whole body.
    final cipher = _groupCipher!;
    final userId = auth.currentUser?.id;
    final recipientId = row['recipient_id'];
    if (userId != null && recipientId is String && recipientId != userId) {
      row['decryptDropped'] = true;
      return row;
    }
    final envelope = row['content'];
    final messageId = row['id'];
    if (await cipher.isSenderKeyEnvelope(envelope)) {
      final result = await cipher.decrypt(
        groupChatId: chatId,
        senderUserId: row['sender_id'] as String? ?? '',
        envelope: envelope,
      );
      final plaintext = result.plaintext;
      if (plaintext != null) {
        row['content'] = plaintext;
        row['decryptFailed'] = false;
        if (messageId is String) {
          (_decryptedByMessage[chatId] ??= {})[messageId] = plaintext;
          await _cachePlaintext(chatId, messageId, plaintext);
        }
        return row;
      }
      if (result.dropped) {
        // Signal semantics: replay/duplicate/no-chain — silent, hidden.
        row['decryptDropped'] = true;
        return row;
      }
      AppLogger.instance.warn(
        'chat group decrypt failed chat=$chatId msg=$messageId — '
        'undecryptable (tampering)',
      );
      row['content'] = chatUndecryptablePlaceholder;
      row['decryptFailed'] = true;
      return row;
    }
    // Type 0x01/0x02: a per-pairwise DISTRIBUTION row. Never a bubble.
    final senderId = row['sender_id'];
    if (senderId is String && groupId != null) {
      try {
        final pair = await _pairwiseCipherFor(chatId, senderId);
        // K1 identity binding (2026-08-16 re-audit): the bundle's
        // `sender_ik_dh` is self-attested, so the bundle is only accepted
        // when it matches the identity the pairwise session BOUND to the
        // sender (X3DH, possession-based) — a bundle minted with a learned
        // foreign ik_dh is rejected by GroupE2eeCipher.processSenderKeyBundle.
        // Null (no pairwise session yet — e.g. the very first init envelope
        // establishes it in the decrypt below) keeps the best-effort path.
        final bound = await pair.boundPeerIkDh();
        final result = await pair.decrypt(
          chatId: _pairwiseSessionKey(chatId, senderId),
          peerUserId: senderId,
          envelope: envelope,
        );
        final plaintext = result.plaintext;
        if (plaintext != null &&
            await _groupCipher.isSenderKeyBundle(plaintext)) {
          await _groupCipher.processSenderKeyBundle(
            groupChatId: chatId,
            senderUserId: senderId,
            groupId: groupId,
            bundleJson: plaintext,
            expectedSenderIkDh:
                bound == null ? null : base64UrlNoPadEncode(bound),
          );
          AppLogger.instance.debug(
            'chat group distribution processed chat=$chatId sender=$senderId '
            'msg=$messageId',
          );
        }
      } catch (e, st) {
        AppLogger.instance.warn(
          'chat group distribution row undecryptable chat=$chatId '
          'msg=$messageId sender=$senderId — hidden; the next send '
          're-distributes: $e',
          '$st',
        );
      }
    }
    row['decryptDropped'] = true;
    return row;
  }

  /// Best-effort probe: does a persisted session exist for [chatId]?
  /// (Drives the Signal reinstall classification — no session ⇒ the row is
  /// pre-reinstall history, hidden + server-deleted.)
  Future<bool> _sessionExistsFor(String chatId) async {
    if (!e2eeEnabled) return true;
    try {
      return await _e2eeSessionStore!.loadSession(chatId) != null;
    } catch (e, st) {
      AppLogger.instance.warn(
        'chat session-exists probe failed chat=$chatId: $e',
        '$st',
      );
      return true;
    }
  }

  /// Write-through into the encrypted plaintext store (best-effort — a
  /// store failure must never break the message path; the message stays
  /// served from the memory cache until the next restart).
  Future<void> _cachePlaintext(
    String chatId,
    String messageId,
    String plaintext,
  ) async {
    try {
      await _plaintextStore?.cache(chatId, messageId, plaintext);
    } catch (e, st) {
      AppLogger.instance.warn(
        'chat plaintext cache write failed chat=$chatId msg=$messageId: $e',
        '$st',
      );
    }
  }

  Future<E2eeMessageCipher> _cipherFor(String chatId) {
    return _sessions.putIfAbsent(chatId, () async {
      final session = E2eeSession(
        chatId: chatId,
        peerUserId: await _resolvePeerUserId(chatId),
        keyStore: _e2eeKeyStore!,
        sessionStore: _e2eeSessionStore!,
        prekeyService: _e2eePrekeyService!,
      );
      return session;
    });
  }

  /// The other participant of a direct chat (session peer for 1:1 E2EE).
  /// Cached per chat; group fan-out is a later step (E2EE §9.6).
  Future<String> _resolvePeerUserId(String chatId) async {
    final cached = _peerCache[chatId];
    if (cached != null) return cached;
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('chat_participants')
        .select('user_id')
        .eq('chat_id', chatId);
    final peers = (res as List)
        .whereType<Map>()
        .map((e) => e['user_id'] as String)
        .where((id) => id != user.id)
        .toList();
    AppLogger.instance.debug(
      'chat resolvePeer chat=$chatId participants=${(res as List).length} '
      'peers=${peers.length}',
    );
    if (peers.isEmpty) {
      AppLogger.instance.error(
        'chat resolvePeer FAILED chat=$chatId — no peer participant '
        '(RLS cp_read_participant / is_chat_participant mismatch?)',
      );
      throw Exception('No peer participant in chat $chatId');
    }
    final peer = peers.first;
    _peerCache[chatId] = peer;
    return peer;
  }
}

/// Cached `chats` row metadata used by the group routing (ISSUE 4 / D3):
/// the chat type (group vs direct) and the `reference_id` (the group id —
/// the crypto group the sender-key chains bind to).
class _ChatInfo {
  const _ChatInfo({required this.type, this.referenceId});

  final String type;
  final String? referenceId;
}
