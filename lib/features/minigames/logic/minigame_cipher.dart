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
/// map `{ 'rounds': { '<round>': base64url(K_r), ... } }`.
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
  E2eeSession _pairwiseSession(String peerUserId) =>
      _sessions.putIfAbsent(_pairwiseSessionKey(peerUserId), () => E2eeSession(
        chatId: _pairwiseSessionKey(peerUserId),
        peerUserId: peerUserId,
        keyStore: _keyStore,
        sessionStore: _sessionStore,
        prekeyService: _prekeyService,
      ));

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
    // Persist our own minted keys first — the host on a fresh device can
    // recover them locally.
    for (final entry in roundKeys.entries) {
      await _cacheRoundKey(entry.key, entry.value);
    }

    final payload = _encodeRoundKeys(roundKeys);
    await Future.wait([
      for (final peer in peerIds)
        _deliverBundle(peer, payload),
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
    final key = _randomKey();
    await _cacheRoundKey(round, key);

    final history = <int, Uint8List>{};
    for (var r = 1; r <= round; r++) {
      final k = await _keyForRound(r);
      if (k != null) history[r] = k;
    }
    final payload = _encodeRoundKeys(history);
    await Future.wait([
      for (final peer in peerIds)
        _deliverBundle(peer, payload),
    ]);
  }

  /// Mints `K_round` (random 32 bytes) if not already known, persists it
  /// locally and distributes the FULL cumulative history `K_1..K_round` to
  /// [peerIds]. The host calls this at the countdown → playing transition so
  /// every participant holds the first round's key BEFORE any answer is
  /// submitted (2026-08-31 on-device fix: previously the first key was only
  /// minted on kick, so `K_0`/`K_1` never existed and the subject's submit
  /// failed with "round key 0 missing").
  ///
  /// Best-effort like [rotateRoundKey]: a peer with no published prekey is
  /// skipped (logged) and stays missing — retried on the next roster change.
  Future<void> mintRoundKeyAndDistribute({
    required List<String> peerIds,
    required int round,
  }) async {
    final known = await _keyForRound(round);
    if (known == null) {
      await _cacheRoundKey(round, _randomKey());
    }
    final history = <int, Uint8List>{};
    for (var r = 1; r <= round; r++) {
      final k = await _keyForRound(r);
      if (k != null) history[r] = k;
    }
    final payload = _encodeRoundKeys(history);
    await Future.wait([
      for (final peer in peerIds)
        _deliverBundle(peer, payload),
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
    return out;
  }

  /// Ensures `K_round` is cached/persisted. When missing, pulls the caller's
  /// OWN-recipient bundles from the server, decrypts each envelope with the
  /// sender's pairwise session and caches every round key found.
  Future<void> ensureRoundKey({required int round}) async {
    if (_hasRoundKey(round)) return;

    final rows = await _service.getE2eeBundles(sessionId);
    for (final row in rows) {
      final senderId = row['sender_id'];
      final bundle = row['bundle_ciphertext'];
      if (senderId is! String || bundle is! String) continue;
      try {
        final envelope = _pairwiseSessionFromSender(senderId);
        final plaintext = await envelope.decryptEnvelope(bundle);
        if (plaintext == null) continue;
        final decoded = _decodeRoundKeys(plaintext);
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

    if (!_hasRoundKey(round)) {
      AppLogger.instance.debug(
        'minigame e2ee round key missing after self-heal session=$sessionId '
        'round=$round',
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

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<Uint8List> _ensureKeyForWrite(int round) async {
    var key = _roundKeys[round];
    if (key == null) {
      final saved = await _sessionStore.loadSession(_roundStoreKey(round));
      final decoded = saved == null ? null : base64UrlNoPadDecode(saved);
      if (decoded != null && decoded.length == 32) {
        key = decoded;
        _roundKeys[round] = key;
      }
    }
    if (key == null) {
      await ensureRoundKey(round: round);
      key = _roundKeys[round];
    }
    if (key == null) {
      throw StateError('round key $round missing');
    }
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

  bool _hasRoundKey(int round) =>
      _roundKeys[round] != null;

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
  }

  /// The persisted set of round numbers for this session (loaded lazily and
  /// cached) — [hasKey] reads this instead of probing every round key.
  Set<int>? _knownRounds;

  Future<Set<int>> _loadKnownRounds() async {
    var known = _knownRounds;
    if (known != null) return known;
    known = _decodeRoundsIndex(
      await _sessionStore.loadSession(_roundIndexKey),
    );
    _knownRounds = known;
    return known;
  }

  String _encodeRoundsIndex(Set<int> rounds) => jsonEncode({
    'rounds': rounds.toList()..sort(),
  });

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
  Future<void> _deliverBundle(String peerUserId, String payload) async {
    try {
      final envelope = _pairwiseSession(peerUserId);
      final bundle = await envelope.encryptText(payload);
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
    } on E2eeCryptoException catch (e) {
      AppLogger.instance.warn(
        'minigame e2ee bundle SKIPPED session=$sessionId recipient=$peerUserId '
        '— peer has no published prekey: $e',
      );
    } catch (e, st) {
      AppLogger.instance.warn(
        'minigame e2ee bundle delivery failed session=$sessionId '
        'recipient=$peerUserId type=${e.runtimeType}: $e',
        '$st',
      );
    }
  }

  /// Serializes a round-key map into the bundle JSON:
  /// `{ 'rounds': { '<round>': base64url(K_r), ... } }`.
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
  Uint8List _roundAad(int round) => utf8Bytes('samay.minigame.$sessionId.$round');

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
    if (bytes == null ||
        bytes.length < e2eeAeadNonceLength + e2eeTagLength) {
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
