import 'dart:async';

import 'package:samay/core/services/realtime_service.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/crypto/interfaces.dart';
import 'package:samay/crypto/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Content stored for a message that could not be decrypted (tampered,
/// missing session, or a gap past MAX_SKIP). The UI renders it as
/// "Mensaje no descifrable" via l10n when the row carries
/// `decryptFailed: true` (E2EE-ARCHITECTURE.md §12.2 step 6).
const String chatUndecryptablePlaceholder = '[Mensaje no descifrable]';

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
class ChatService {
  final SupabaseClient client;
  final RealtimeService realtime;
  final E2eeKeyStore? _e2eeKeyStore;
  final E2eeSessionStore? _e2eeSessionStore;
  final E2eePrekeyService? _e2eePrekeyService;

  ChatService({
    required this.client,
    required this.realtime,
    E2eeKeyStore? e2eeKeyStore,
    E2eeSessionStore? e2eeSessionStore,
    E2eePrekeyService? e2eePrekeyService,
  }) : _e2eeKeyStore = e2eeKeyStore,
       _e2eeSessionStore = e2eeSessionStore,
       _e2eePrekeyService = e2eePrekeyService;

  GoTrueClient get auth => client.auth;

  /// Whether E2EE is wired (session bootstrap + encrypt/decrypt active).
  bool get e2eeEnabled =>
      _e2eeKeyStore != null && _e2eeSessionStore != null && _e2eePrekeyService != null;

  /// In-memory per-chat cipher instances (each bound to (chatId, peerUserId)).
  /// The map holds the creation Future so concurrent decrypt/send paths can
  /// never race two sessions into existence for the same chat (I-38).
  final Map<String, Future<E2eeMessageCipher>> _sessions = {};
  final Map<String, String> _peerCache = {};

  /// Outbox: own sent envelope → plaintext. The sender cannot decrypt its
  /// own envelopes with the peer-bound session, so sent messages are shown
  /// from this in-memory map (E2EE §8.4: plaintext lives only in memory —
  /// after an app restart, own historical messages render as
  /// [chatUndecryptablePlaceholder], a documented MVP limitation).
  final Map<String, String> _outbox = {};

  /// chatId → messageId → decrypted plaintext. Decrypted history is cached
  /// so re-loading a chat does not re-run the ratchet over already-consumed
  /// messages (an out-of-order replay would fail its AEAD binding and mark
  /// good messages as undecryptable). Memory-only (§8.4).
  final Map<String, Map<String, String>> _decryptedByMessage = {};

  /// Per-chat serial executor for decryption: the ratchet session is
  /// stateful and must never process two envelopes concurrently (realtime
  /// bursts / subscribe+load overlap). Each call chains behind the previous
  /// one for the same chat (I-38).
  final Map<String, Future<void>> _decryptTail = {};

  Future<List<Map<String, dynamic>>> loadMessages(String chatId, {int limit = 50, int offset = 0}) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('messages')
        .select('id, sender_id, content, media_url, created_at')
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final rows = (res as List).reversed.map((e) => Map<String, dynamic>.from(e)).toList();
    if (!e2eeEnabled) return rows;
    return [for (final row in rows) await _decryptMessage(chatId, row)];
  }

  Future<void> sendMessage(String chatId, String content, String? mediaUrl) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    var sanitized = InputSanitizer.sanitize(
      content,
      maxLength: InputSanitizer.messageMaxLength,
    );
    if (e2eeEnabled) {
      // Session bootstrap (E2EE §12.2 step 2): ensure our own bundle is
      // published before the first X3DH initiate of this chat.
      if (!_sessions.containsKey(chatId)) {
        await _e2eePrekeyService!.publishAll();
      }
      final cipher = await _cipherFor(chatId);
      final envelope = await cipher.encrypt(
        chatId: chatId,
        peerUserId: await _resolvePeerUserId(chatId),
        plaintext: sanitized,
      );
      _outbox[envelope] = sanitized;
      sanitized = envelope;
    }
    await client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': user.id,
      'content': sanitized,
      'media_url': mediaUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
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

  /// Subscribes to live inserts for [chatId]. Rows arrive as raw envelopes
  /// and are decrypted before [onInsert] sees them (E2EE §9.4: realtime
  /// carries ciphertext only). Returns the channel so callers can
  /// unsubscribe on dispose.
  RealtimeChannel subscribeToMessages(
    String chatId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
    return realtime.subscribeToMessages(chatId, (row) async {
      if (e2eeEnabled) {
        onInsert(await _decryptMessage(chatId, row));
      } else {
        onInsert(row);
      }
    });
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
    }
    final userId = auth.currentUser?.id;
    if (userId != null && row['sender_id'] == userId) {
      final plaintext = _outbox[envelope];
      if (plaintext != null) {
        row['content'] = plaintext;
        row['decryptFailed'] = false;
        if (messageId is String) {
          (_decryptedByMessage[chatId] ??= {})[messageId] = plaintext;
        }
        return row;
      }
    }
    try {
      final cipher = await _cipherFor(chatId);
      final plaintext = await cipher.decrypt(
        chatId: chatId,
        peerUserId: await _resolvePeerUserId(chatId),
        envelope: envelope,
      );
      if (plaintext != null) {
        row['content'] = plaintext;
        row['decryptFailed'] = false;
        if (messageId is String) {
          (_decryptedByMessage[chatId] ??= {})[messageId] = plaintext;
        }
        return row;
      }
    } catch (_) {
      // Fall through to the marker (atomicity §4.5 keeps the session safe).
    }
    row['content'] = chatUndecryptablePlaceholder;
    row['decryptFailed'] = true;
    return row;
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
    if (peers.isEmpty) {
      throw Exception('No peer participant in chat $chatId');
    }
    final peer = peers.first;
    _peerCache[chatId] = peer;
    return peer;
  }
}
