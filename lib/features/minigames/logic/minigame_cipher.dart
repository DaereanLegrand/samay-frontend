import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/crypto/codec.dart';
import 'package:samay/crypto/constants.dart';
import 'package:samay/crypto/e2ee_primitives.dart';
import 'package:samay/crypto/interfaces.dart';
import 'package:samay/crypto/session.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';

/// Minigame E2EE answer cipher (202_minigame_play_v2, round-key model).
///
/// Truth/dare answers (text + image) must be readable ONLY by the match's
/// participants — the server never sees plaintext, never sees keys. The
/// per-ROUND group key `K_r` (random 32 bytes) encrypts every answer of
/// round `r` with AES-256-GCM; the server only stores the ciphertext in
/// `minigame_answers` (and, for images, only the Storage bucket path).
///
/// ## Round-key model
///
/// - A per-round key `K_r` is a fresh `Random.secure()` 32-byte value minted
///   by the HOST (the creator acts as key custodian).
/// - Keys are ADDITIVE, never wiped: a player who accepts at round N receives
///   the FULL history `K_1..K_N` and can decrypt every round they were a part
///   of. There is NO epoch/rekey machinery and no group-key wipe.
/// - Each answer is AES-256-GCM-encrypted with the round's own key and an AAD
///   binding session + round (`samay.minigame.<sessionId>.<round>`).
///
/// ## Host-as-key-custodian + additive-history delivery
///
/// The host distributes (a bundle of) round keys to each participant through
/// the existing `minigame_e2ee_bundles` table (via [MinigameService.putE2eeBundle]
/// / [getE2eeBundles]) inside the existing [E2eeSession] (X3DH + Double
/// Ratchet) pairwise envelopes — the same synthetic pairwise namespace
/// pattern as the chat group-key distribution. Each bundle payload is a JSON
/// map `{ 'rounds': { '<round>': base64url(K_r),... } }`.
///
/// - On accept, the host calls [distributeHistoryKeys] to hand the new player
///   the full `K_1..K_N` it has minted so far.
/// - On kick, the host calls [rotateRoundKey] to mint `K_{r+1}` and
///   distribute it ONLY to the remaining participants — the kicked player is
///   forward-rotated out (their stored keys still decrypt past rounds, but
///   future rounds are revoked because they never receive `K_{r+1}`).
///
/// Distribution is best-effort: a peer with no published prekey
/// ([E2eeCryptoException] from the pairwise session) is skipped and stays
/// missing — it is retried on the next roster change. Distribution failures
/// never throw to the caller.
///
/// ## Self-heal
///
/// Round keys are persisted locally (via [E2eeSessionStore], keys like
/// `minigame:<sessionId>:round:<r>`) the moment they are minted or learned.
/// A device that lost its keys (fresh install, second device) calls
/// [ensureRoundKey] to pull its own-recipient bundles from the server and
/// decrypt them with the sender's pairwise session — no host redistribution
/// needed.
///
/// ## Image model (Storage bucket)
///
/// `encryptAnswerImage` returns the RAW AEAD bytes
/// `nonce(12) ‖ ciphertext ‖ tag` — NO base64. The bytes are uploaded to the
/// object Storage bucket; the DB stores only the bucket path. On read, the
/// app downloads the bytes and calls [decryptAnswerImageBytes] to recover the
/// original image bytes.
///
/// ## No-wipe directive
///
/// Round keys are device-scoped and never wiped on roster change. Only
/// [wipe] removes them (account/device cleanup); forward rotation is the ONLY
/// revoke mechanism.
class MinigameCipher {
  MinigameCipher({
    required this.sessionId,
    required String ownerUserId,
    required E2eeKeyStore keyStore,
    required E2eeSessionStore sessionStore,
    required E2eePrekeyService prekeyService,
    required MinigameService service,
  }) : _ownerUserId = ownerUserId,
       _keyStore = keyStore,
       _sessionStore = sessionStore,
       _prekeyService = prekeyService,
       _service = service;

  final String sessionId;
  final E2eeKeyStore _keyStore;
  final E2eeSessionStore _sessionStore;
  final E2eePrekeyService _prekeyService;
  final MinigameService _service;
  final String _ownerUserId;

  /// In-memory round keys (never logged): round number → 32-byte key.
  final Map<int, Uint8List> _roundKeys = {};

  /// Cached pairwise distribution sessions, keyed by the synthetic namespace
  /// (`g:minigame:<sessionId>:<peerId>`) — mirrors
  /// `chat_service._pairwiseCipherFor`'s `putIfAbsent`. Reusing the SAME
  /// [E2eeSession] across [distributeHistoryKeys] / [rotateRoundKey] means a
  /// still-unacknowledged init RE-WRAPS with the same base key (Signal
  /// unacknowledged-prekey semantics) instead of re-running fresh X3DH and
  /// burning the peer's one-time prekeys.
  final Map<String, E2eeSession> _sessions = {};

  /// The store key for one round key.
  String _roundStoreKey(int round) => 'minigame:$sessionId:round:$round';

  /// The store key for the round-key index (the persisted round numbers of
  /// this session) — a cheap `hasKey()` without scanning every round key.
  String get _roundIndexKey => 'minigame:$sessionId:rounds';

  /// The synthetic pairwise-session namespace key for [peerUserId] — mirrors
  /// `chat_service._pairwiseSessionKey` (`g:<chatId>:<peerUserId>`), so the
  /// sender and the recipient resolve the SAME namespace for a (session,
  /// peer) pair.
  String _pairwiseSessionKey(String peerUserId) =>
      'g:minigame:$sessionId:$peerUserId';

  /// A cached pairwise [E2eeSession] to [peerUserId] for bundle distribution —
  /// the recipient resolves its side of the session by the ENVELOPE'S SENDER
  /// id (see [ensureRoundKey]).
  E2eeSession _pairwiseSession(String peerUserId) => _sessions.putIfAbsent(
    _pairwiseSessionKey(peerUserId),
    () => E2eeSession(
      chatId: _pairwiseSessionKey(peerUserId),
      peerUserId: peerUserId,
      keyStore: _keyStore,
      sessionStore: _sessionStore,
      prekeyService: _prekeyService,
    ),
  );

  /// The pairwise session with the envelope's [senderId] — the namespace key
  /// is derived from the SENDER (the envelope's source), not from our own id.
  E2eeSession _pairwiseSessionFromSender(String senderId) =>
      _pairwiseSession(senderId);

  /// Distributes the FULL history bundle of [roundKeys] to every [peerIds]
  /// participant (host → players at accept-time). Each envelope is the
  /// plaintext of a pairwise [E2eeSession] with the synthetic namespace
  /// `g:minigame:<sessionId>:<peerId>`, stored as one `minigame_e2ee_bundles`
  /// row addressed to that peer.
  ///
  /// Best-effort: a peer with no published prekey ([E2eeCryptoException]) is
  /// skipped (logged) and stays missing — retried on the next roster change.
  /// Failures never throw to the caller.
  Future<void> distributeHistoryKeys({
    required List<String> peerIds,
    required Map<int, Uint8List> roundKeys,
  }) async {
    AppLogger.instance.debug(
      'minigame distributeHistoryKeys enter session=$sessionId '
      'peers=${peerIds.length} history=${roundKeys.keys.toList()}',
    );
    // Persist our own minted keys first — the host on a fresh device can
    // recover them locally.
    for (final entry in roundKeys.entries) {
      await _cacheRoundKey(entry.key, entry.value);
    }

    final payload = _encodeRoundKeys(roundKeys);
    await Future.wait([
      for (final peer in peerIds) _deliverBundle(peer, payload),
    ]);
  }

  /// Mints `K_round` (random 32 bytes), persists it locally and delivers the
  /// cumulative history `K_1..K_round` to [peerIds] — the kick path passes the
  /// REMAINING participants, so the kicked player is forward-rotated out.
  ///
  /// The bundle carries the full history (not just the delta) because the
  /// bundle table holds ONE row per (session, sender, recipient): a delta
  /// would clobber the earlier rounds and a fresh device self-healing from the
  /// server would only ever recover the latest round.
  Future<void> rotateRoundKey({
    required List<String> peerIds,
    required int round,
  }) async {
    AppLogger.instance.debug(
      'minigame rotateRoundKey enter session=$sessionId round=$round '
      'peers=${peerIds.length}',
    );
    final key = _randomKey();
    await _cacheRoundKey(round, key);

    final history = <int, Uint8List>{};
    // Include round 0 — the first playable round is round 0, so K_0 must be
    // part of the delivered history.
    for (var r = 0; r <= round; r++) {
      final k = await _keyForRound(r);
      if (k != null) history[r] = k;
    }
    final payload = _encodeRoundKeys(history);
    AppLogger.instance.debug(
      'minigame rotateRoundKey minted session=$sessionId round=$round '
      'historyRounds=${history.keys.toList()} payloadBytes=${payload.length}',
    );
    await Future.wait([
      for (final peer in peerIds) _deliverBundle(peer, payload),
    ]);
  }

  /// Mints `K_round` (random 32 bytes) if not already known, persists it
  /// locally and distributes the FULL cumulative history `K_0..K_round` to
  /// [peerIds]. The host calls this at the countdown → playing transition so
  /// every participant holds the first round's key BEFORE any answer is
  /// submitted.
  ///
  /// Best-effort like [rotateRoundKey]: a peer with no published prekey is
  /// skipped (logged) and stays missing — retried on the next roster change.
  Future<void> mintRoundKeyAndDistribute({
    required List<String> peerIds,
    required int round,
  }) async {
    final known = await _keyForRound(round);
    AppLogger.instance.debug(
      'minigame mintRoundKeyAndDistribute enter session=$sessionId round=$round '
      'keyKnown=${known != null} peers=${peerIds.length}',
    );
    if (known == null) {
      await _cacheRoundKey(round, _randomKey());
    }
    final history = <int, Uint8List>{};
    // Include round 0 — the first playable round is round 0, so K_0 must be
    // distributed.
    for (var r = 0; r <= round; r++) {
      final k = await _keyForRound(r);
      if (k != null) history[r] = k;
    }
    final payload = _encodeRoundKeys(history);
    AppLogger.instance.debug(
      'minigame mintRoundKeyAndDistribute built session=$sessionId round=$round '
      'historyRounds=${history.keys.toList()} payloadBytes=${payload.length} '
      'sendingTo=${peerIds.length}',
    );
    await Future.wait([
      for (final peer in peerIds) _deliverBundle(peer, payload),
    ]);
  }

  /// The round keys this device currently knows for the session —
  /// `{round: key}` from memory + the persisted store. Used by the accept /
  /// roster-change distributions to hand newcomers the REAL history (not an
  /// empty bundle).
  Future<Map<int, Uint8List>> knownRoundKeys() async {
    final known = await _loadKnownRounds();
    final out = <int, Uint8List>{};
    for (final r in known) {
      final k = await _keyForRound(r);
      if (k != null) out[r] = k;
    }
    AppLogger.instance.debug(
      'minigame knownRoundKeys session=$sessionId '
      'persistedRounds=${known.toList()} knownRounds=${out.keys.toList()}',
    );
    return out;
  }

  /// Ensures `K_round` is cached/persisted. When missing, pulls the caller's
  /// OWN-recipient bundles from the server, decrypts each envelope with the
  /// sender's pairwise session and caches every round key found.
  Future<void> ensureRoundKey({required int round}) async {
    if (_hasRoundKey(round)) return;

    final rows = await _service.getE2eeBundles(sessionId);
    AppLogger.instance.debug(
      'minigame ensureRoundKey session=$sessionId round=$round '
      'selfRecipientBundles=${rows.length}',
    );
    var foundAny = false;
    for (final row in rows) {
      final senderId = row['sender_id'];
      final bundle = row['bundle_ciphertext'];
      if (senderId is! String || bundle is! String) continue;
      try {
        final envelope = _pairwiseSessionFromSender(senderId);
        final plaintext = await envelope.decryptEnvelope(bundle);
        if (plaintext == null) continue;
        final decoded = _decodeRoundKeys(plaintext);
        foundAny = foundAny || decoded.isNotEmpty;
        for (final entry in decoded.entries) {
          await _cacheRoundKey(entry.key, entry.value);
        }
      } catch (e, st) {
        AppLogger.instance.warn(
          'minigame e2ee bundle decrypt failed session=$sessionId '
              'sender=$senderId type=${e.runtimeType}: $e',
          '$st',
        );
      }
    }

    if (foundAny) {
      AppLogger.instance.debug(
        'minigame ensureRoundKey recovered keys session=$sessionId round=$round '
        'nowHasRound=${_hasRoundKey(round)}',
      );
    } else if (!_hasRoundKey(round)) {
      AppLogger.instance.debug(
        'minigame e2ee round key missing after self-heal session=$sessionId '
        'round=$round bundles=${rows.length}',
      );
    }
  }

  /// Encrypts [plaintext] with `K_round` (AES-256-GCM, AAD
  /// `samay.minigame.<sessionId>.<round>`) and returns the base64url
  /// `nonce(12) ‖ ciphertext‖tag` blob for `minigame_answers`.
  ///
  /// Ensures the key exists first (self-heal via [ensureRoundKey]); throws a
  /// clear [StateError] when the round key is still missing so the WRITE path
  /// never submits plaintext-as-ciphertext.
  Future<String> encryptAnswerText(String plaintext, int round) async {
    final key = await _ensureKeyForWrite(round);
    return _encryptRound(key, utf8Bytes(plaintext), round);
  }

  /// Encrypts image [bytes] with `K_round` (same AEAD) and returns the RAW
  /// ciphertext BYTES `nonce(12) ‖ ciphertext‖tag` (no base64) — for the
  /// Storage bucket upload. Throws [StateError] when the round key is
  /// missing (same write-path guard as [encryptAnswerText]).
  Future<Uint8List> encryptAnswerImage(Uint8List bytes, int round) async {
    final key = await _ensureKeyForWrite(round);
    final nonce = _randomNonce();
    final box = await aesGcmEncrypt(
      key: key,
      nonce: nonce,
      plaintext: bytes,
      aad: _roundAad(round),
    );
    return concatBytes([nonce, box]);
  }

  /// Decrypts a base64url answer blob into UTF-8 text, or null on missing
  /// key / any authentication failure.
  Future<String?> decryptAnswerText(String ciphertext, int round) async {
    final key = await _keyForRound(round);
    if (key == null) return null;
    final clear = await _decryptRound(key, ciphertext, round);
    if (clear == null) return null;
    try {
      return utf8.decode(clear);
    } on FormatException {
      return null;
    }
  }

  /// Encrypts the STRUCTURED answer payload — the author's [text] plus the
  /// on-canvas [layout] — as ONE E2EE blob, so the server never
  /// sees the text OR where it was placed.
  Future<String> encryptAnswerPayload({
    required String text,
    required MinigameAnswerLayout layout,
    required int round,
  }) async {
    final key = await _ensureKeyForWrite(round);
    final body = jsonEncode({
      'text': text,
      'x': layout.x,
      'y': layout.y,
      'r': layout.rotation,
      's': layout.scale,
    });
    return _encryptRound(key, utf8Bytes(body), round);
  }

  /// Decrypts an answer blob into text + layout, or null on missing key /
  /// authentication failure. A LEGACY plain-text answer (pre-layout) decodes
  /// as its text with the default centered layout.
  Future<MinigameAnswerPayload?> decryptAnswerPayload(
    String ciphertext,
    int round,
  ) async {
    final clear = await decryptAnswerText(ciphertext, round);
    if (clear == null) return null;
    try {
      final decoded = jsonDecode(clear);
      if (decoded is Map && decoded.containsKey('text')) {
        return MinigameAnswerPayload(
          text: decoded['text'] as String?,
          layout: MinigameAnswerLayout.fromJson(
            Map<String, dynamic>.from(decoded),
          ),
        );
      }
    } on FormatException {
      // Not a structured payload — a plain-text answer.
    }
    return MinigameAnswerPayload(text: clear);
  }

  /// Decrypts RAW image bytes `nonce(12) ‖ ciphertext‖tag`, or null on
  /// missing key / authentication failure.
  Future<Uint8List?> decryptAnswerImageBytes(
    Uint8List ciphertext,
    int round,
  ) async {
    final key = await _keyForRound(round);
    if (key == null) return null;
    if (ciphertext.length < e2eeAeadNonceLength + e2eeTagLength) return null;
    return aesGcmDecrypt(
      key: key,
      nonce: Uint8List.sublistView(ciphertext, 0, e2eeAeadNonceLength),
      ciphertext: Uint8List.sublistView(ciphertext, e2eeAeadNonceLength),
      aad: _roundAad(round),
    );
  }

  /// Device-scoped cleanup: deletes ALL round keys for this session from the
  /// local store and memory (round keys + the rounds index; the pairwise
  /// distribution sessions are per-session too).
  Future<void> wipe() async {
    final known = await _loadKnownRounds();
    for (final round in known) {
      await _sessionStore.deleteSession(_roundStoreKey(round));
    }
    await _sessionStore.deleteSession(_roundIndexKey);
    _roundKeys.clear();
    _knownRounds = null;
    _sessions.clear();
  }

  /// Whether ANY round key for this session is present locally (in memory or
  /// persisted in the store).
  Future<bool> hasKey() async {
    if (_roundKeys.isNotEmpty) return true;
    final known = await _loadKnownRounds();
    for (final round in known) {
      if (_roundKeys.containsKey(round)) return true;
      final saved = await _sessionStore.loadSession(_roundStoreKey(round));
      if (saved != null && base64UrlNoPadDecode(saved)?.length == 32) {
        return true;
      }
    }
    return false;
  }

  // Internals

  Future<Uint8List> _ensureKeyForWrite(int round) async {
    var source = 'memory';
    var key = _roundKeys[round];
    if (key == null) {
      final saved = await _sessionStore.loadSession(_roundStoreKey(round));
      final decoded = saved == null ? null : base64UrlNoPadDecode(saved);
      if (decoded != null && decoded.length == 32) {
        key = decoded;
        _roundKeys[round] = key;
        source = 'store';
      }
    }
    if (key == null) {
      source = 'self-heal';
      await ensureRoundKey(round: round);
      key = _roundKeys[round];
    }
    if (key == null) {
      AppLogger.instance.error(
        'minigame round key missing for WRITE session=$sessionId round=$round '
        'source=$source inMemory=${_roundKeys.containsKey(round)} '
        'knownRounds=${await _loadKnownRounds()}',
      );
      throw StateError('round key $round missing');
    }
    AppLogger.instance.debug(
      'minigame round key ready for write session=$sessionId round=$round '
      'source=$source',
    );
    return key;
  }

  /// The round key for [round] — in memory, from the store, or recovered via
  /// [ensureRoundKey]. Null when unavailable.
  Future<Uint8List?> _keyForRound(int round) async {
    var key = _roundKeys[round];
    if (key != null) return key;
    final saved = await _sessionStore.loadSession(_roundStoreKey(round));
    final decoded = saved == null ? null : base64UrlNoPadDecode(saved);
    if (decoded != null && decoded.length == 32) {
      _roundKeys[round] = decoded;
      return decoded;
    }
    await ensureRoundKey(round: round);
    return _roundKeys[round];
  }

  bool _hasRoundKey(int round) => _roundKeys[round] != null;

  /// Caches [key] for [round] in memory AND persists it — a host on a fresh
  /// device recovers its own minted keys without a peer redistribution. The
  /// rounds index (persisted) keeps [hasKey] cheap.
  Future<void> _cacheRoundKey(int round, Uint8List key) async {
    _roundKeys[round] = key;
    await _sessionStore.saveSession(
      _roundStoreKey(round),
      base64UrlNoPadEncode(key),
    );
    final index = _decodeRoundsIndex(
      await _sessionStore.loadSession(_roundIndexKey),
    );
    index.add(round);
    await _sessionStore.saveSession(_roundIndexKey, _encodeRoundsIndex(index));
    AppLogger.instance.debug(
      'minigame round key cached session=$sessionId round=$round '
      'index=${index.toList()}',
    );
  }

  /// The persisted set of round numbers for this session (loaded lazily and
  /// cached) — [hasKey] reads this instead of probing every round key.
  Set<int>? _knownRounds;

  Future<Set<int>> _loadKnownRounds() async {
    var known = _knownRounds;
    if (known != null) return known;
    known = _decodeRoundsIndex(await _sessionStore.loadSession(_roundIndexKey));
    _knownRounds = known;
    return known;
  }

  String _encodeRoundsIndex(Set<int> rounds) =>
      jsonEncode({'rounds': rounds.toList()..sort()});

  Set<int> _decodeRoundsIndex(String? raw) {
    if (raw == null) return <int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <int>{};
      final rounds = decoded['rounds'];
      if (rounds is! List) return <int>{};
      return {
        for (final r in rounds)
          if (r is int) r,
      };
    } on FormatException {
      return <int>{};
    }
  }

  /// Pairwise-delivers one [payload] bundle to [peerUserId]. A peer with no
  /// published prekey throws [E2eeCryptoException] from the pairwise session
  /// — skipped (logged), stays missing, retried on the next roster change.
  ///
  /// Returns true only when the envelope actually reached the server (a
  /// caller may then clear the requester marker — 206_minigame_key_request).
  Future<bool> _deliverBundle(String peerUserId, String payload) async {
    try {
      final envelope = _pairwiseSession(peerUserId);
      final bundle = await envelope.encryptText(payload);
      AppLogger.instance.debug(
        'minigame e2ee bundle encrypting session=$sessionId '
        'recipient=$peerUserId envelope=${_pairwiseSessionKey(peerUserId)} '
        'payloadBytes=${payload.length} bundleBytes=${bundle.length}',
      );
      await _service.putE2eeBundle(
        sessionId,
        senderId: _ownerUserId,
        recipientId: peerUserId,
        bundleCiphertext: bundle,
      );
      AppLogger.instance.debug(
        'minigame e2ee bundle delivered session=$sessionId '
        'recipient=$peerUserId',
      );
      return true;
    } on E2eeCryptoException catch (e) {
      AppLogger.instance.warn(
        'minigame e2ee bundle SKIPPED session=$sessionId recipient=$peerUserId '
        '— peer has no published prekey: $e',
      );
      return false;
    } catch (e, st) {
      AppLogger.instance.warn(
        'minigame e2ee bundle delivery failed session=$sessionId '
            'recipient=$peerUserId type=${e.runtimeType}: $e',
        '$st',
      );
      return false;
    }
  }

  /// Whether this device currently holds `K_round` (memory OR the secure
  /// store). Unlike [ensureRoundKey] it does NOT self-heal — a caller uses it
  /// to distinguish "the key is genuinely gone from this device" (a reinstall
  /// wiped the E2EE identity) from "the key exists but the decrypt failed"
  /// (a tamper / auth failure). 206_minigame_key_request.
  Future<bool> hasRoundKey(int round) async {
    if (_roundKeys[round] != null) return true;
    final saved = await _sessionStore.loadSession(_roundStoreKey(round));
    if (saved == null) return false;
    final decoded = base64UrlNoPadDecode(saved);
    return decoded != null && decoded.length == 32;
  }

  /// Re-wraps THIS device's full additive key history `K_0..K_<latest>` to
  /// each [requesterId]: the requester
  /// lost its device-local E2EE state (fresh identity), so the host's old
  /// pairwise bundles can never decrypt on it. ANY participant who still
  /// holds the keys may serve — the ring is not host-dependent.
  ///
  /// Each delivery is a fresh pairwise X3DH init against the requester's
  /// CURRENT published bundle (the E2eeSession init path). Returns the
  /// requesters a bundle actually reached (so the caller clears only those
  /// markers); a peer with no published prekey is skipped and stays flagged.
  Future<List<String>> shareRoundHistoryWith(List<String> requesterIds) async {
    final history = await knownRoundKeys();
    if (history.isEmpty) {
      AppLogger.instance.debug(
        'minigame key-ring share skipped session=$sessionId — no round keys '
        'held on this device',
      );
      return const [];
    }
    final payload = _encodeRoundKeys(history);
    AppLogger.instance.debug(
      'minigame key-ring share session=$sessionId requesters=${requesterIds.length} '
      'historyRounds=${history.keys.toList()}',
    );
    final served = <String>[];
    for (final requester in requesterIds) {
      if (requester == _ownerUserId) continue;
      final ok = await _deliverBundle(requester, payload);
      if (ok) served.add(requester);
    }
    return served;
  }

  /// The requester side of the key ring (206_minigame_key_request): flags this
  /// device on the server, then polls its OWN-recipient bundle rows until a
  /// holder's fresh re-wrap lands (or [timeout] elapses). Returns true when
  /// `K_round` became available. Server-blind — the marker carries no key.
  ///
  /// Best-effort: the caller shows a friendly "waiting for a participant to
  /// resend the key" state while this runs; a false return means no holder was
  /// online (the caller may surface a Reintentar action).
  Future<bool> requestRoundKeyShare(
    int round, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (await hasRoundKey(round)) return true;
    AppLogger.instance.debug(
      'minigame key-ring request session=$sessionId round=$round — flagging',
    );
    try {
      await _service.requestMinigameRoundKeys(sessionId);
    } catch (e, st) {
      AppLogger.instance.warn(
        'minigame key-ring request RPC failed session=$sessionId round=$round '
            'type=${e.runtimeType}: $e',
        '$st',
      );
      return false;
    }
    // Poll own-recipient bundles — every poll re-tries the pairwise decrypt
    // against this device's CURRENT identity, so a holder's fresh init lands.
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await hasRoundKey(round)) return true;
      // ensureRoundKey re-pulls + decrypts every own-recipient row.
      await ensureRoundKey(round: round);
      if (await hasRoundKey(round)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    AppLogger.instance.debug(
      'minigame key-ring request timed out session=$sessionId round=$round — '
      'no holder served',
    );
    return false;
  }

  /// Serializes a round-key map into the bundle JSON:
  /// `{ 'rounds': { '<round>': base64url(K_r),... } }`.
  String _encodeRoundKeys(Map<int, Uint8List> roundKeys) => jsonEncode({
    'rounds': {
      for (final entry in roundKeys.entries)
        '${entry.key}': base64UrlNoPadEncode(entry.value),
    },
  });

  /// Parses a bundle JSON payload back into a `{round: key}` map. Tolerant:
  /// unparseable/malformed payloads yield an empty map (never throw).
  Map<int, Uint8List> _decodeRoundKeys(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return const {};
      final rounds = decoded['rounds'];
      if (rounds is! Map) return const {};
      final out = <int, Uint8List>{};
      for (final entry in rounds.entries) {
        final round = int.tryParse('${entry.key}');
        final key = entry.value is String
            ? base64UrlNoPadDecode(entry.value as String)
            : null;
        if (round == null || key == null || key.length != 32) continue;
        out[round] = key;
      }
      return out;
    } on FormatException {
      return const {};
    }
  }

  /// The AAD binding session + round.
  Uint8List _roundAad(int round) =>
      utf8Bytes('samay.minigame.$sessionId.$round');

  /// AES-256-GCM `nonce(12) ‖ ciphertext‖tag` as base64url (answer text).
  Future<String> _encryptRound(
    Uint8List key,
    Uint8List plaintext,
    int round,
  ) async {
    final nonce = _randomNonce();
    final box = await aesGcmEncrypt(
      key: key,
      nonce: nonce,
      plaintext: plaintext,
      aad: _roundAad(round),
    );
    return base64UrlNoPadEncode(concatBytes([nonce, box]));
  }

  Future<Uint8List?> _decryptRound(
    Uint8List key,
    String ciphertext,
    int round,
  ) async {
    final bytes = base64UrlNoPadDecode(ciphertext);
    if (bytes == null || bytes.length < e2eeAeadNonceLength + e2eeTagLength) {
      return null;
    }
    return aesGcmDecrypt(
      key: key,
      nonce: Uint8List.sublistView(bytes, 0, e2eeAeadNonceLength),
      ciphertext: Uint8List.sublistView(bytes, e2eeAeadNonceLength),
      aad: _roundAad(round),
    );
  }

  Uint8List _randomKey() =>
      Uint8List.fromList(List<int>.generate(32, (_) => _randomByte()));

  Uint8List _randomNonce() =>
      Uint8List.fromList(List<int>.generate(12, (_) => _randomByte()));

  int _randomByte() => _random.nextInt(256);

  final Random _random = Random.secure();
}
