import 'dart:convert';
import 'dart:typed_data';

import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/crypto/codec.dart';
import 'package:samay/crypto/constants.dart';
import 'package:samay/crypto/double_ratchet.dart';
import 'package:samay/crypto/e2ee_primitives.dart';
import 'package:samay/crypto/envelope.dart';
import 'package:samay/crypto/interfaces.dart';
import 'package:samay/crypto/x3dh.dart';

/// Per-chat E2EE orchestrator: X3DH (initiator or responder) + Double
/// Ratchet + envelope framing, persisted after every operation
/// (E2EE-ARCHITECTURE.md §7).
///
/// This is the concrete [E2eeMessageCipher]: the chat layer (I-38) holds
/// one instance per chat and calls [encryptText]/[decryptEnvelope].
///
/// ## Wire behavior
///
/// - The initiator's first outbound message is a **type-0x01 init envelope**
///   (X3DH header + ratchet payload, §5.3 step 7); everything after is
///   **type-0x02** ratchet envelopes.
/// - The responder creates its session by *processing* an init envelope;
///   it cannot send before that (§4.3 — no sending chain yet).
/// - Processing a NEW init envelope while another session exists **replaces**
///   it: last-processed-wins, and the replaced session moves to the head of
///   the inactive list (Sesame §3.2) — bounded at [e2eeMaxInactiveSessions],
///   kept for [e2eeRetiredSessionMaxAge] so in-flight ciphertext from the
///   old session still decrypts (§7.2, Sesame §6.4/§6.5).
/// - A ratchet envelope that fails against the active session is tried
///   against each inactive session; the first match is **activated** and the
///   previous active session becomes inactive (Sesame §3.4 — convergence on
///   simultaneous initiation).
/// - A replayed init envelope (identical `sender_ik_dh ‖ ekA ‖ spk_id ‖
///   opk_id`, persisted marker) is dropped without re-decrypting and without
///   touching the session (X3DH §4.2 replay mitigation).
/// - Undecryptable messages return null and leave the session untouched
///   (atomicity §4.5). A failed init attempt discards all state changes and
///   restores the previously active session (Sesame §3.4 error handling).
class E2eeSession implements E2eeMessageCipher {
  E2eeSession({
    required this.chatId,
    required this.peerUserId,
    required E2eeKeyStore keyStore,
    required E2eeSessionStore sessionStore,
    required E2eePrekeyService prekeyService,
    DateTime Function()? clock,
  }) : _keyStore = keyStore,
       _sessionStore = sessionStore,
       _prekeyService = prekeyService,
       _clock = clock ?? DateTime.now;

  final String chatId;
  final String peerUserId;

  final E2eeKeyStore _keyStore;
  final E2eeSessionStore _sessionStore;
  final E2eePrekeyService _prekeyService;
  final DateTime Function() _clock;

  E2eeIdentityKeys? _identity;
  RatchetState? _ratchet;

  /// Peer identity keys bound to the current session (recomputed AD on
  /// restart, §8.3 "self-describing").
  Uint8List? _peerIkDh;
  Uint8List? _peerIkSig;

  /// Initiator-only: false until the init envelope has been produced.
  bool _hasSentInit = false;

  /// Initiator-only, Signal `unacknowledgedPreKeyMessage` semantics
  /// (2026-08-15): true only after the peer's FIRST successfully decrypted
  /// ratchet reply acknowledged our init. While false, every outbound
  /// message is re-sent as a FRESH init envelope — the peer can always
  /// (re)establish the session, even after app restarts or a lost init.
  /// Old session JSON (no field) restores as false → stale sessions heal on
  /// the next send (the live "Mensaje no descifrable" bug).
  bool _initAcknowledged = false;

  /// Initiator-only: X3DH init fields for the one-time init envelope.
  Uint8List? _ekA;
  int? _spkId;
  int? _opkId;

  /// Sessions displaced by a newer init envelope (Sesame §3.2 inactive
  /// list), head = most recently retired, bounded at
  /// [e2eeMaxInactiveSessions], entries older than
  /// [e2eeRetiredSessionMaxAge] are dropped (Sesame §6.4/§6.5).
  final List<_RetiredSession> _retired = [];

  /// Fingerprint of the last processed init envelope
  /// (`sha256(sender_ik_dh ‖ ekA ‖ spk_id ‖ opk_id)`, base64url) — the X3DH
  /// §4.2 replay blacklist. Persisted with the session JSON so a replay is
  /// still dropped after an app restart.
  String? _lastInitMarker;

  String get _role => _ratchet?.role ?? 'initiator';

  // ---------------------------------------------------------------------------
  // E2eeMessageCipher
  // ---------------------------------------------------------------------------

  @override
  Future<String> encrypt({
    required String chatId,
    required String peerUserId,
    required String plaintext,
  }) {
    assert(chatId == this.chatId && peerUserId == this.peerUserId,
        'E2eeSession is bound to ($this->chatId, $this->peerUserId)');
    return encryptText(plaintext);
  }

  @override
  Future<E2eeDecryptResult> decrypt({
    required String chatId,
    required String peerUserId,
    required String envelope,
  }) {
    assert(chatId == this.chatId && peerUserId == this.peerUserId,
        'E2eeSession is bound to ($this->chatId, $this->peerUserId)');
    return decryptEnvelopeDetailed(envelope);
  }

  @override
  Future<bool> peerIdentityChanged(String peerUserId) async {
    var peer = _peerIkDh;
    // A freshly created cipher instance has no session in memory — the
    // bound peer identity lives in the store. Restore it so the comparison
    // works before any send/decrypt touched the session (2026-08-16 —
    // §7.5 detection must fire on the first chat open after a restart).
    if (peer == null) {
      final saved = await _sessionStore.loadSession(chatId);
      if (saved != null) {
        _restore(saved);
        peer = _peerIkDh;
      }
    }
    // No session bound — nothing to compare against. Returning early ALSO
    // avoids burning one of the peer's one-time prekeys (fetchBundle is the
    // only read path and consumes one per call).
    if (peer == null) return false;
    final bundle = await _prekeyService.fetchBundle(peerUserId);
    if (bundle == null) return false;
    return !constantTimeEquals(bundle.identityKey, peer);
  }

  // ---------------------------------------------------------------------------
  // Core operations
  // ---------------------------------------------------------------------------

  /// Encrypts [plaintext] (UTF-8) for the peer and returns the base64url
  /// envelope string (type 0x01 on the session's first outbound message,
  /// type 0x02 thereafter).
  ///
  /// Throws [E2eeCryptoException] when sending is not yet possible
  /// (responder that has not received the init message).
  Future<String> encryptText(String plaintext) async {
    final identity = await _identityKeys();
    await _ensureSessionReady(identity);

    // Signal unacknowledged-prekey semantics (2026-08-16, getPreKeyMessage):
    // while the peer has not acknowledged our init, every outbound message
    // is RE-WRAPPED as a type-0x01 init envelope with the SAME baseKey and
    // prekey ids persisted on the session — the peer reuses its existing
    // session (baseKey lookup), so nothing is re-fetched and no one-time
    // prekey is ever consumed twice. The pre-fix design re-ran fresh X3DH
    // per send (new ekA + bundle fetch per message), which burned OPKs and
    // made re-processed history permanently undecryptable.
    //
    // Two cases still heal with ONE fresh X3DH:
    //  - a restored LEGACY session JSON without the persisted init fields;
    //  - an idle session past the 90-day expiry (the peer-side session is
    //    gone, so a re-wrapped init could never decrypt there either).
    if (_role == 'initiator' &&
        _hasSentInit &&
        !_initAcknowledged &&
        (_ekA == null ||
            _spkId == null ||
            _opkId == null ||
            _clock().difference(_ratchet!.lastUsedAt) > e2eeSessionMaxAge)) {
      AppLogger.instance.warn(
        'e2ee unacknowledged init chat=$chatId peer=$peerUserId — '
        're-initiating with a fresh X3DH (legacy session or idle past '
        'e2eeSessionMaxAge)',
      );
      await wipe();
      await _ensureSessionReady(identity);
    }

    final ratchet = _ratchet!;
    final (header, ciphertext) = await ratchetEncrypt(
      ratchet,
      utf8.encode(plaintext),
      _adBase(identity, _peerIkDh!, _peerIkSig!),
    );
    ratchet.pruneSkippedKeys(_clock());
    ratchet.lastUsedAt = _clock();

    // An init envelope is sent while our init is unacknowledged — including
    // re-wraps of subsequent messages (Signal getPreKeyMessage); once the
    // peer's reply decrypts (`_initAcknowledged`), ratchet (0x02) resumes.
    final initMessage = _role == 'initiator' && !_initAcknowledged;
    final envelope = SamayEnvelope(
      type: initMessage ? e2eeEnvelopeTypeInit : e2eeEnvelopeTypeRatchet,
      senderIkDh: identity.ikDhPublic,
      senderIkSig: identity.ikSigPublic,
      recipientIkDh: initMessage ? _peerIkDh : null,
      ekA: initMessage ? _ekA : null,
      spkId: initMessage ? _spkId : null,
      opkId: initMessage ? _opkId : null,
      dhPub: header.dh,
      pn: header.pn,
      n: header.n,
      ciphertext: ciphertext,
    );
    if (initMessage) {
      _hasSentInit = true;
    }
    await _persist();
    AppLogger.instance.debug(
      'e2ee encrypt chat=$chatId peer=$peerUserId '
      'type=${initMessage ? "init(0x01)" : "ratchet(0x02)"} '
      'hasSentInit=$_hasSentInit',
    );
    return base64UrlNoPadEncode(envelope.encode());
  }

  /// Whether [envelope] is a type-0x01 init (X3DH first message) — used by
  /// the chat layer to roll the session back when the init's INSERT failed
  /// (the peer never received it; retries must re-initiate, not send ratchet
  /// messages into a session the peer never saw).
  @override
  bool envelopeIsInit(String envelope) {
    final bytes = base64UrlNoPadDecode(envelope);
    if (bytes == null) return false;
    final parsed = SamayEnvelope.tryParse(bytes);
    return parsed?.type == e2eeEnvelopeTypeInit;
  }

  /// Decrypts an envelope string. Returns the plaintext, or null when the
  /// message must be dropped: malformed/unknown envelope, wrong recipient,
  /// unknown session, expired session, or authentication failure.
  /// On failure the session state is preserved (§4.5).
  ///
  /// Compatibility view over [decryptEnvelopeDetailed] — the chat layer
  /// uses the tri-state [decrypt] so protocol-level drops never render as
  /// the undecryptable bubble.
  Future<String?> decryptEnvelope(String envelope) async =>
      (await decryptEnvelopeDetailed(envelope)).plaintext;

  /// The tri-state decrypt ([E2eeDecryptResult]): plaintext, a SILENT drop
  /// (duplicate/replay, stale identity, missing prekey material, no
  /// session — Signal's DuplicateMessage/NoSession classes) or a GENUINE
  /// failure (tampering / ratchet mismatch against an existing session —
  /// the only case that may render the undecryptable bubble).
  Future<E2eeDecryptResult> decryptEnvelopeDetailed(String envelope) async {
    final identity = await _identityKeys();
    final bytes = base64UrlNoPadDecode(envelope);
    if (bytes == null) return const E2eeDecryptResult.dropped();
    final parsed = SamayEnvelope.tryParse(bytes);
    if (parsed == null) return const E2eeDecryptResult.dropped();

    switch (parsed.type) {
      case e2eeEnvelopeTypeInit:
        return _handleInitEnvelope(parsed, identity);
      case e2eeEnvelopeTypeRatchet:
        return _handleRatchetEnvelope(parsed, identity);
      default:
        return const E2eeDecryptResult.dropped();
    }
  }

  /// Discards the session: deletes it from the store and zeroes the
  /// in-memory key material (including inactive sessions and the replay
  /// marker). (Account-level wipe of ALL material is
  /// `E2eeKeyStore.wipeAll()` — §7.6.) The chat layer uses this to roll
  /// back an initiator session whose init INSERT failed — the next encrypt
  /// re-initiates fresh X3DH (2026-08-15 session/insert atomicity).
  @override
  Future<void> wipe() async {
    _ratchet = null;
    _peerIkDh = null;
    _peerIkSig = null;
    _ekA = null;
    _hasSentInit = false;
    _initAcknowledged = false;
    _retired.clear();
    _lastInitMarker = null;
    await _sessionStore.deleteSession(chatId);
  }

  /// Safety fingerprint (§6.1): first 30 bytes of
  /// `HKDF(salt=0x00×32, ikm=AD_base, info="samay.e2ee.fingerprint.v1")`,
  /// displayed as 5×6-hex groups. Symmetric for both parties.
  ///
  /// STRICTLY read-only: it never initiates X3DH (a fresh initiate would
  /// consume one of the peer's one-time prekeys server-side and mint a
  /// session the user did not ask for). Requires an established session —
  /// without one it throws [E2eeCryptoException]; the UI shows the
  /// fingerprint only once the chat session exists.
  Future<Uint8List> computeFingerprint() async {
    final identity = await _identityKeys();
    if (_ratchet == null) {
      final saved = await _sessionStore.loadSession(chatId);
      if (saved != null) _restore(saved);
    }
    if (_ratchet == null || _peerIkDh == null || _peerIkSig == null) {
      throw const E2eeCryptoException(
        'no established session — fingerprint requires an active chat session',
      );
    }
    return hkdfSha256(
      ikm: _adBase(identity, _peerIkDh!, _peerIkSig!),
      salt: Uint8List(32),
      info: utf8Bytes(e2eeFingerprintInfo),
      length: 30,
    );
  }

  /// Serializes the session (§8.3 + chat metadata + inactive sessions +
  /// replay marker). Null before any session state exists.
  String? toJson() {
    final ratchet = _ratchet;
    if (ratchet == null || _peerIkDh == null) return null;
    return jsonEncode({
      ...ratchet.toJson(),
      'version': e2eeSessionJsonVersion,
      'chat_id': chatId,
      'peer_user_id': peerUserId,
      'peer_ik_dh': base64UrlNoPadEncode(_peerIkDh!),
      'peer_ik_sig': base64UrlNoPadEncode(_peerIkSig!),
      'has_sent_init': _hasSentInit,
      'init_acknowledged': _initAcknowledged,
      'last_init_marker': _lastInitMarker,
      // Init fields (2026-08-16): the baseKey + prekey ids the session was
      // built around — the initiator re-wraps unacknowledged sends with them
      // (Signal getPreKeyMessage), the responder matches re-sent inits by
      // them. Null on legacy JSON.
      'ek_a': _ekA == null ? null : base64UrlNoPadEncode(_ekA!),
      'spk_id': _spkId,
      'opk_id': _opkId,
      'retired_sessions': [
        for (final r in _retired)
          {
            'ratchet': r.ratchet.toJson(),
            'peer_ik_dh': base64UrlNoPadEncode(r.peerIkDh),
            'peer_ik_sig': base64UrlNoPadEncode(r.peerIkSig),
            'ek_a': r.aliceBaseKey.isEmpty
                ? null
                : base64UrlNoPadEncode(r.aliceBaseKey),
            'retired_at': r.retiredAt.toIso8601String(),
          },
      ],
    });
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<E2eeIdentityKeys> _identityKeys() async {
    _identity ??= await _keyStore.loadOrCreateIdentity();
    return _identity!;
  }

  Future<void> _ensureSessionReady(E2eeIdentityKeys identity) async {
    if (_ratchet != null) return;
    final saved = await _sessionStore.loadSession(chatId);
    if (saved != null) {
      _restore(saved);
      AppLogger.instance.debug(
        'e2ee session restored from store chat=$chatId peer=$peerUserId',
      );
      return;
    }
    // Initiator path: fresh X3DH run with the peer's current bundle (§5.3).
    final bundle = await _prekeyService.fetchBundle(peerUserId);
    if (bundle == null) {
      AppLogger.instance.error(
        'e2ee session initiate FAILED chat=$chatId peer=$peerUserId — '
        'peer has no published prekey bundle (see fetchBundle log)',
      );
      throw E2eeCryptoException(
        'no prekey bundle for peer $peerUserId — cannot initiate E2EE session',
      );
    }
    AppLogger.instance.debug(
      'e2ee session initiating chat=$chatId peer=$peerUserId '
      'spkId=${bundle.signedPrekeyId} '
      'opkId=${bundle.oneTimePrekeyId ?? e2eeNoOpkId}',
    );
    final init = await x3dhInitiate(
      ourIdentityPrivateKey: identity.ikDhPrivate,
      ourIdentityPublicKey: identity.ikDhPublic,
      bundle: bundle,
    );
    _ratchet = await ratchetInitAlice(
      rootKey: init.sharedSecret,
      bobRatchetKey: bundle.signedPrekey,
      now: _clock(),
    );
    _peerIkDh = Uint8List.fromList(bundle.identityKey);
    _peerIkSig = Uint8List.fromList(bundle.identitySigKey);
    _ekA = init.ephemeralPublicKey;
    _spkId = bundle.signedPrekeyId;
    _opkId = bundle.oneTimePrekeyId ?? e2eeNoOpkId;
    _hasSentInit = false;
  }

  /// Type 0x01: X3DH responder flow (§5.4). A NEW init envelope replaces
  /// any existing session (last-processed-wins, §7.2 / D-11) and moves the
  /// displaced session to the inactive list (Sesame §3.2); a RE-SENT init
  /// (same baseKey — Signal's unacknowledged-prekey re-wrap) is decrypted
  /// via the EXISTING session, never re-running X3DH and never touching a
  /// one-time prekey (SessionBuilder.processV3 `hasSessionState(baseKey)`
  /// — 2026-08-16); a REPLAYED init is dropped without touching the session
  /// (X3DH §4.2). On auth failure all state changes are discarded and the
  /// previous session is restored (Sesame §3.4) — an attacker cannot clobber
  /// a healthy session with a forged init.
  Future<E2eeDecryptResult> _handleInitEnvelope(
    SamayEnvelope env,
    E2eeIdentityKeys identity,
  ) async {
    if (env.recipientIkDh == null ||
        !constantTimeEquals(env.recipientIkDh!, identity.ikDhPublic)) {
      AppLogger.instance.warn(
        'e2ee init envelope DROPPED chat=$chatId — recipient identity does '
        'not match this device (delivery binding §6.5; the sender initiated '
        'against a stale published bundle)',
      );
      return const E2eeDecryptResult.dropped(); // delivery binding (§6.5)
    }
    if (env.ekA == null || env.spkId == null || env.opkId == null) {
      AppLogger.instance.warn(
        'e2ee init envelope DROPPED chat=$chatId — missing X3DH header '
        'fields (ekA/spkId/opkId)',
      );
      return const E2eeDecryptResult.dropped();
    }
    if (constantTimeEquals(env.senderIkDh, identity.ikDhPublic)) {
      AppLogger.instance.warn(
        'e2ee init envelope DROPPED chat=$chatId — our own init echoed back',
      );
      return const E2eeDecryptResult.dropped(); // our own init echoed back
    }

    // Signal `SessionBuilder.processV3`: an init whose baseKey already has a
    // session (active OR inactive) is a RE-SEND of an unacknowledged init —
    // decrypt via the existing session's ratchet (the chain advanced, so the
    // message decrypts like any other). No X3DH, no OPK load/delete, no
    // archive: this is what makes the initiator's re-wrapped prekey messages
    // decryptable even after the one-time prekey was consumed (the pre-fix
    // fresh-X3DH design burned an OPK per send and made re-processed history
    // permanently undecryptable — the live "Mensaje no descifrable" class).
    final reused = await _decryptWithBaseKeySession(env, identity);
    if (reused != null) return reused;

    // Replay blacklist (X3DH §4.2): the marker fingerprints the full init
    // header. Identical bytes → same marker → the message was already
    // processed (the no-OPK variant is fully re-derivable, so only this
    // marker stops the replay). A fresh init from the same sender always
    // carries a new ephemeral key and therefore a new marker.
    final marker = base64UrlNoPadEncode(
      await sha256Digest(concatBytes([
        env.senderIkDh,
        env.ekA!,
        _uint32Bytes(env.spkId!),
        _uint32Bytes(env.opkId!),
      ])),
    );
    if (marker == _lastInitMarker) {
      AppLogger.instance.warn(
        'e2ee init envelope DROPPED chat=$chatId — replay (identical marker '
        'already processed, X3DH §4.2)',
      );
      return const E2eeDecryptResult.dropped();
    }

    final spkPair = await _keyStore.loadSignedPrekeyPrivate(env.spkId!);
    if (spkPair == null) {
      AppLogger.instance.warn(
        'e2ee init envelope DROPPED chat=$chatId — no local signed-prekey '
        'private for spkId=${env.spkId} (the published bundle predates the '
        'local material — stale-row recovery required)',
      );
      return const E2eeDecryptResult.dropped();
    }
    final needsOpk = env.opkId! != e2eeNoOpkId;
    final opkPair = needsOpk
        ? await _keyStore.loadOneTimePrekeyPrivate(env.opkId!)
        : null;
    if (needsOpk && opkPair == null) {
      AppLogger.instance.warn(
        'e2ee init envelope DROPPED chat=$chatId — no local one-time-prekey '
        'private for opkId=${env.opkId} (consumed or from stale material)',
      );
      return const E2eeDecryptResult.dropped();
    }

    // Snapshot for the Sesame §3.4 abort path: on failure, restore.
    final prevRatchet = _ratchet;
    final prevPeerIkDh = _peerIkDh;
    final prevPeerIkSig = _peerIkSig;
    final prevEkA = _ekA;
    final prevSpkId = _spkId;
    final prevOpkId = _opkId;
    final prevRetired = List<_RetiredSession>.from(_retired);

    final sharedSecret = await x3dhRespond(
      ourIdentityPrivateKey: identity.ikDhPrivate,
      ourSignedPrekey: spkPair,
      ourOneTimePrekeyPrivateKey: opkPair?.privateKey,
      theirIdentityPublicKey: env.senderIkDh,
      theirEphemeralPublicKey: env.ekA!,
    );

    final responder = await ratchetInitBob(
      rootKey: sharedSecret,
      bobRatchetKeyPair: spkPair,
      now: _clock(),
    );

    // Sesame §3.2 "insert then activate": the displaced active session moves
    // to the head of the inactive list (bounded, age-pruned). Retire FIRST —
    // the retired entry captures the previous session's own baseKey.
    _retireCurrentSession();
    _ratchet = responder;
    _peerIkDh = Uint8List.fromList(env.senderIkDh);
    _peerIkSig = Uint8List.fromList(env.senderIkSig);
    _ekA = Uint8List.fromList(env.ekA!);
    _spkId = env.spkId;
    _opkId = env.opkId;
    _hasSentInit = true; // responders never send an init envelope

    try {
      final plaintext = await _decryptWith(
        responder,
        _peerIkDh!,
        _peerIkSig!,
        env,
        identity,
      );
      // Consumed OPK: delete now (forward secrecy, R1 §3.4 / §5.4 step 2).
      if (needsOpk) {
        await _keyStore.deleteOneTimePrekey(env.opkId!);
      }
      _lastInitMarker = marker;
      // Signal `clearUnacknowledgedPreKeyMessage` runs on ANY successful
      // decrypt (2026-08-16): processing the peer's init acknowledges our
      // own — the simultaneous-initiation loop converges instead of
      // re-initiating forever.
      _initAcknowledged = true;
      await _persist();
      return E2eeDecryptResult.plaintext(plaintext);
    } on RatchetError {
      // Abort and restore everything (R1 §3.4 / §5.4 step 6 + Sesame §3.4:
      // a failed init must not destroy the established session).
      _ratchet = prevRatchet;
      _peerIkDh = prevPeerIkDh;
      _peerIkSig = prevPeerIkSig;
      _ekA = prevEkA;
      _spkId = prevSpkId;
      _opkId = prevOpkId;
      _retired
        ..clear()
        ..addAll(prevRetired);
      if (needsOpk) {
        await _keyStore.deleteOneTimePrekey(env.opkId!);
      }
      // The init was addressed to us and ALL key material existed — an AEAD
      // failure here means tampering: a genuine undecryptable failure.
      return const E2eeDecryptResult.failed();
    }
  }

  /// Signal `SessionBuilder.processV3` `hasSessionState(version, baseKey)`:
  /// looks up a session (active or inactive) already bound to
  /// `(env.senderIkDh, env.ekA)` and decrypts the re-sent init via its
  /// ratchet. On success a retired match is ACTIVATED (Sesame §3.4) and the
  /// previous active session becomes inactive. Returns null when no session
  /// is bound to this baseKey (a genuinely new init falls through to full
  /// X3DH); an AEAD failure against a matching session is a duplicate →
  /// SILENT drop, never a bubble.
  Future<E2eeDecryptResult?> _decryptWithBaseKeySession(
    SamayEnvelope env,
    E2eeIdentityKeys identity,
  ) async {
    if (_ratchet == null) {
      final saved = await _sessionStore.loadSession(chatId);
      if (saved == null) return null;
      _restore(saved);
    }
    final baseKey = _ekA;
    if (baseKey != null &&
        _peerIkDh != null &&
        constantTimeEquals(env.ekA!, baseKey) &&
        constantTimeEquals(env.senderIkDh, _peerIkDh!)) {
      try {
        final plaintext = await _decryptWith(
          _ratchet!,
          _peerIkDh!,
          _peerIkSig!,
          env,
          identity,
        );
        _initAcknowledged = true;
        await _persist();
        return E2eeDecryptResult.plaintext(plaintext);
      } on RatchetError {
        return const E2eeDecryptResult.dropped();
      }
    }
    for (var i = 0; i < _retired.length; i++) {
      final retired = _retired[i];
      if (!constantTimeEquals(env.ekA!, retired.aliceBaseKey)) continue;
      if (!constantTimeEquals(env.senderIkDh, retired.peerIkDh)) continue;
      if (_clock().difference(retired.ratchet.lastUsedAt) > e2eeSessionMaxAge) {
        continue;
      }
      try {
        final plaintext = await _decryptWith(
          retired.ratchet,
          retired.peerIkDh,
          retired.peerIkSig,
          env,
          identity,
        );
        // Activate (Sesame §3.4): swap active ↔ inactive.
        _retired.removeAt(i);
        final active = _ratchet;
        final peerDh = _peerIkDh;
        final peerSig = _peerIkSig;
        _ratchet = retired.ratchet;
        _peerIkDh = retired.peerIkDh;
        _peerIkSig = retired.peerIkSig;
        if (active != null && peerDh != null) {
          _retired.insert(
            0,
            _RetiredSession(
              ratchet: active,
              peerIkDh: peerDh,
              peerIkSig: peerSig ?? Uint8List(0),
              aliceBaseKey: baseKey ?? Uint8List(0),
              retiredAt: _clock(),
            ),
          );
        }
        _initAcknowledged = true;
        await _persist();
        return E2eeDecryptResult.plaintext(plaintext);
      } on RatchetError {
        // Not this session — try the next one.
      }
    }
    return null;
  }

  /// Type 0x02: existing-session decrypt. Never creates sessions from
  /// ratchet messages (Sesame R3 §3.4 / §6.5). A message that fails against
  /// the active session is tried against each inactive session; the first
  /// match is activated and the previous active session becomes inactive
  /// (Sesame §3.4 — session convergence on simultaneous initiation).
  /// Sessions idle past 90 days are refused even when still in memory (§7.7).
  Future<E2eeDecryptResult> _handleRatchetEnvelope(
    SamayEnvelope env,
    E2eeIdentityKeys identity,
  ) async {
    if (_ratchet == null) {
      final saved = await _sessionStore.loadSession(chatId);
      if (saved == null) {
        AppLogger.instance.warn(
          'e2ee ratchet envelope DROPPED chat=$chatId — no session exists '
          '(the sender resumed a session whose init envelope never reached '
          'this device; a fresh init is required)',
        );
        return const E2eeDecryptResult.dropped();
      }
      _restore(saved);
    }
    final peer = _peerIkDh;
    if (peer == null) {
      AppLogger.instance.warn(
        'e2ee ratchet envelope DROPPED chat=$chatId — no peer identity bound',
      );
      return const E2eeDecryptResult.dropped();
    }
    if (!constantTimeEquals(env.senderIkDh, peer)) {
      AppLogger.instance.warn(
        'e2ee ratchet envelope DROPPED chat=$chatId — sender identity does '
        'not match the bound peer (identity binding, §7.1)',
      );
      return const E2eeDecryptResult.dropped(); // identity binding (§7.1)
    }
    final lastUsed = _ratchet!.lastUsedAt;
    if (_clock().difference(lastUsed) > e2eeSessionMaxAge) {
      await _sessionStore.deleteSession(chatId);
      return const E2eeDecryptResult.dropped(); // idle too long (§7.7)
    }
    try {
      final plaintext = await _decryptWith(
        _ratchet!,
        _peerIkDh!,
        _peerIkSig!,
        env,
        identity,
      );
      // The peer's ratchet reply acknowledges our init (Signal
      // `clearUnacknowledgedPreKeyMessage`) — later sends resume ratchet.
      _initAcknowledged = true;
      await _persist();
      return E2eeDecryptResult.plaintext(plaintext);
    } on RatchetError {
      // Active session could not decrypt — try the inactive sessions.
      final retired = await _decryptWithRetired(env, identity);
      if (retired != null) return E2eeDecryptResult.plaintext(retired);
      // An existing session was bound to this sender but NOTHING decrypts:
      // genuine undecryptable (tampering / skip-gap) — the bubble.
      return const E2eeDecryptResult.failed();
    }
  }

  /// Tries every inactive session (Sesame §3.4 step 2-4): the first one
  /// bound to [env.senderIkDh] that decrypts the message becomes the active
  /// session, and the previous active session moves to the head of the
  /// inactive list. Returns null when no inactive session matches (the
  /// message is dropped; all session state is preserved — atomicity §4.5).
  Future<String?> _decryptWithRetired(
    SamayEnvelope env,
    E2eeIdentityKeys identity,
  ) async {
    _pruneRetired();
    for (var i = 0; i < _retired.length; i++) {
      final retired = _retired[i];
      if (!constantTimeEquals(env.senderIkDh, retired.peerIkDh)) continue;
      if (_clock().difference(retired.ratchet.lastUsedAt) > e2eeSessionMaxAge) {
        continue;
      }
      try {
        final plaintext = await _decryptWith(
          retired.ratchet,
          retired.peerIkDh,
          retired.peerIkSig,
          env,
          identity,
        );
        // Activate (Sesame §3.4 step 4): swap active ↔ inactive.
        _retired.removeAt(i);
        final active = _ratchet;
        final peerDh = _peerIkDh;
        final peerSig = _peerIkSig;
        _ratchet = retired.ratchet;
        _peerIkDh = retired.peerIkDh;
        _peerIkSig = retired.peerIkSig;
        if (active != null && peerDh != null) {
          _retired.insert(
            0,
            _RetiredSession(
              ratchet: active,
              peerIkDh: peerDh,
              peerIkSig: peerSig ?? Uint8List(0),
              aliceBaseKey: _ekA ?? Uint8List(0),
              retiredAt: _clock(),
            ),
          );
        }
        await _persist();
        return plaintext;
      } on RatchetError {
        // Not this session — try the next inactive one.
      }
    }
    return null;
  }

  /// Sesame §3.2: moves the current active session to the head of the
  /// inactive list (bounded at [e2eeMaxInactiveSessions], entries older than
  /// [e2eeRetiredSessionMaxAge] pruned — Sesame §6.4/§6.5). The retired
  /// entry keeps the session's OWN baseKey (`ek_a`) so a re-sent init can be
  /// matched to it (Signal `hasSessionState(version, baseKey)`).
  void _retireCurrentSession() {
    final ratchet = _ratchet;
    final peerDh = _peerIkDh;
    if (ratchet == null || peerDh == null) return;
    _pruneRetired();
    _retired.insert(
      0,
      _RetiredSession(
        ratchet: ratchet,
        peerIkDh: peerDh,
        peerIkSig: _peerIkSig ?? Uint8List(0),
        aliceBaseKey: _ekA ?? Uint8List(0),
        retiredAt: _clock(),
      ),
    );
    if (_retired.length > e2eeMaxInactiveSessions) {
      _retired.removeLast();
    }
  }

  void _pruneRetired() {
    final cutoff = _clock().subtract(e2eeRetiredSessionMaxAge);
    _retired.removeWhere((r) => r.retiredAt.isBefore(cutoff));
  }

  static Uint8List _uint32Bytes(int value) => Uint8List.fromList([
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ]);

  Future<String> _decryptWith(
    RatchetState ratchet,
    Uint8List peerIkDh,
    Uint8List peerIkSig,
    SamayEnvelope env,
    E2eeIdentityKeys identity,
  ) async {
    final header = RatchetHeader(dh: env.dhPub, pn: env.pn, n: env.n);
    final plaintext = await ratchetDecrypt(
      ratchet,
      header,
      env.ciphertext,
      _adBase(identity, peerIkDh, peerIkSig),
      now: _clock(),
    );
    ratchet.pruneSkippedKeys(_clock());
    ratchet.lastUsedAt = _clock();
    return utf8.decode(plaintext);
  }

  /// AD_base = Encode(IK_dh_A) ‖ Encode(IK_dh_B) ‖ Encode(IK_sig_A) ‖
  /// Encode(IK_sig_B), sorted lexicographically by the two DH keys —
  /// role-independent (§6.1). Recomputed from the stored identity and the
  /// session's peer keys ([peerIkDh]/[peerIkSig] — the active session's on
  /// the normal path, an inactive session's on the retired-decrypt path),
  /// never serialized (§8.3).
  Uint8List _adBase(
    E2eeIdentityKeys identity,
    Uint8List peerIkDh,
    Uint8List peerIkSig,
  ) {
    final myDh = identity.ikDhPublic;
    final peerDh = peerIkDh;
    final mySig = identity.ikSigPublic;
    final peerSig = peerIkSig;
    final A = constantTimeEquals(myDh, peerDh) || _lessThan(myDh, peerDh)
        ? myDh
        : peerDh;
    final B = identical(A, myDh) ? peerDh : myDh;
    final sigA = identical(A, myDh) ? mySig : peerSig;
    final sigB = identical(B, myDh) ? mySig : peerSig;
    return concatBytes([A, B, sigA, sigB]);
  }

  static bool _lessThan(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] < b[i];
    }
    return false;
  }

  void _restore(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    _ratchet = RatchetState.fromJson(map);
    _peerIkDh = base64UrlNoPadDecode(map['peer_ik_dh'] as String);
    _peerIkSig = base64UrlNoPadDecode(map['peer_ik_sig'] as String);
    _hasSentInit = map['has_sent_init'] as bool? ?? true;
    // Old JSON (pre-2026-08-15) has no field → false → an unacknowledged
    // init heals on the next send (Signal unacknowledged-prekey semantics).
    _initAcknowledged = map['init_acknowledged'] as bool? ?? false;
    _lastInitMarker = map['last_init_marker'] as String?;
    // Init fields (2026-08-16, Signal getPreKeyMessage): the initiator's
    // baseKey + prekey ids, persisted so an unacknowledged init RE-WRAPS
    // instead of re-running fresh X3DH. On the responder they record the
    // init this session was built from (baseKey matching for re-sent inits).
    // Absent on legacy JSON → the initiator heals with one fresh X3DH.
    final ekA = map['ek_a'];
    _ekA = ekA is String ? base64UrlNoPadDecode(ekA) : null;
    _spkId = map['spk_id'] as int?;
    _opkId = map['opk_id'] as int?;
    _retired.clear();
    final cutoff = _clock().subtract(e2eeRetiredSessionMaxAge);
    for (final entry in map['retired_sessions'] as List<dynamic>? ?? const []) {
      final r = Map<String, dynamic>.from(entry as Map);
      final retiredAt = DateTime.tryParse(r['retired_at'] as String? ?? '');
      final peerDh = base64UrlNoPadDecode(r['peer_ik_dh'] as String);
      final peerSig = base64UrlNoPadDecode(r['peer_ik_sig'] as String);
      if (retiredAt == null || peerDh == null || peerSig == null) continue;
      if (retiredAt.isBefore(cutoff)) continue; // retention window passed
      final retiredEkA = r['ek_a'];
      _retired.add(_RetiredSession(
        ratchet: RatchetState.fromJson(Map<String, dynamic>.from(r['ratchet'] as Map)),
        peerIkDh: peerDh,
        peerIkSig: peerSig,
        aliceBaseKey: retiredEkA is String
            ? base64UrlNoPadDecode(retiredEkA) ?? Uint8List(0)
            : Uint8List(0),
        retiredAt: retiredAt,
      ));
    }
  }

  Future<void> _persist() async {
    final json = toJson();
    if (json != null) {
      await _sessionStore.saveSession(chatId, json);
    }
  }
}

/// A session displaced by a newer init envelope (Sesame §3.2 inactive
/// list). Kept for [e2eeRetiredSessionMaxAge] so in-flight ciphertext from
/// the old session still decrypts; deleted once the retention window passes
/// (Sesame §6.4/§6.5). [aliceBaseKey] is the baseKey (`ek_a`) this session
/// was built around — re-sent inits are matched to it (Signal
/// `hasSessionState(version, baseKey)`, 2026-08-16).
class _RetiredSession {
  _RetiredSession({
    required this.ratchet,
    required this.peerIkDh,
    required this.peerIkSig,
    required this.aliceBaseKey,
    required this.retiredAt,
  });

  final RatchetState ratchet;
  final Uint8List peerIkDh;
  final Uint8List peerIkSig;
  final Uint8List aliceBaseKey;
  final DateTime retiredAt;
}
