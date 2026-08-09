import 'dart:convert';
import 'dart:typed_data';

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
/// - Processing an init envelope while another session exists **replaces**
///   it: last-processed-wins (decision D-11, §7.2).
/// - Undecryptable messages return null and leave the session untouched
///   (atomicity §4.5).
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

  /// Initiator-only: X3DH init fields for the one-time init envelope.
  Uint8List? _ekA;
  int? _spkId;
  int? _opkId;

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
  Future<String?> decrypt({
    required String chatId,
    required String peerUserId,
    required String envelope,
  }) {
    assert(chatId == this.chatId && peerUserId == this.peerUserId,
        'E2eeSession is bound to ($this->chatId, $this->peerUserId)');
    return decryptEnvelope(envelope);
  }

  @override
  Future<bool> peerIdentityChanged(String peerUserId) async {
    final bundle = await _prekeyService.fetchBundle(peerUserId);
    final peer = _peerIkDh;
    if (bundle == null || peer == null) return false;
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

    final ratchet = _ratchet!;
    final (header, ciphertext) = await ratchetEncrypt(
      ratchet,
      utf8.encode(plaintext),
      _adBase(identity),
    );
    ratchet.pruneSkippedKeys(_clock());
    ratchet.lastUsedAt = _clock();

    final initMessage = _role == 'initiator' && !_hasSentInit;
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
    return base64UrlNoPadEncode(envelope.encode());
  }

  /// Decrypts an envelope string. Returns the plaintext, or null when the
  /// message must be dropped: malformed/unknown envelope, wrong recipient,
  /// unknown session, expired session, or authentication failure.
  /// On failure the session state is preserved (§4.5).
  Future<String?> decryptEnvelope(String envelope) async {
    final identity = await _identityKeys();
    final bytes = base64UrlNoPadDecode(envelope);
    if (bytes == null) return null;
    final parsed = SamayEnvelope.tryParse(bytes);
    if (parsed == null) return null;

    switch (parsed.type) {
      case e2eeEnvelopeTypeInit:
        return _handleInitEnvelope(parsed, identity);
      case e2eeEnvelopeTypeRatchet:
        return _handleRatchetEnvelope(parsed, identity);
      default:
        return null;
    }
  }

  /// Discards the session: deletes it from the store and zeroes the
  /// in-memory key material. (Account-level wipe of ALL material is
  /// `E2eeKeyStore.wipeAll()` — §7.6.)
  void wipe() {
    _ratchet = null;
    _peerIkDh = null;
    _peerIkSig = null;
    _ekA = null;
    _hasSentInit = false;
    _sessionStore.deleteSession(chatId);
  }

  /// Safety fingerprint (§6.1): first 30 bytes of
  /// `HKDF(salt=0x00×32, ikm=AD_base, info="samay.e2ee.fingerprint.v1")`,
  /// displayed as 5×6-hex groups. Symmetric for both parties.
  ///
  /// Loads the session from the store first, so a freshly-restarted session
  /// object can compute it without any prior operation.
  Future<Uint8List> computeFingerprint() async {
    final identity = await _identityKeys();
    await _ensureSessionReady(identity);
    return hkdfSha256(
      ikm: _adBase(identity),
      salt: Uint8List(32),
      info: utf8Bytes(e2eeFingerprintInfo),
      length: 30,
    );
  }

  /// Serializes the session (§8.3 + chat metadata). Null before any
  /// session state exists.
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
      return;
    }
    // Initiator path: fresh X3DH run with the peer's current bundle (§5.3).
    final bundle = await _prekeyService.fetchBundle(peerUserId);
    if (bundle == null) {
      throw E2eeCryptoException(
        'no prekey bundle for peer $peerUserId — cannot initiate E2EE session',
      );
    }
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

  /// Type 0x01: X3DH responder flow (§5.4). Replaces any existing session
  /// (last-processed-wins, §7.2 / D-11). On auth failure everything is
  /// discarded (R1 §3.4) and the consumed OPK private key is deleted.
  Future<String?> _handleInitEnvelope(
    SamayEnvelope env,
    E2eeIdentityKeys identity,
  ) async {
    if (env.recipientIkDh == null ||
        !constantTimeEquals(env.recipientIkDh!, identity.ikDhPublic)) {
      return null; // delivery binding (§6.5)
    }
    if (env.ekA == null || env.spkId == null || env.opkId == null) {
      return null;
    }
    if (constantTimeEquals(env.senderIkDh, identity.ikDhPublic)) {
      return null; // our own init echoed back — never process
    }

    final spkPair = await _keyStore.loadSignedPrekeyPrivate(env.spkId!);
    if (spkPair == null) return null;
    final needsOpk = env.opkId! != e2eeNoOpkId;
    final opkPair = needsOpk
        ? await _keyStore.loadOneTimePrekeyPrivate(env.opkId!)
        : null;
    if (needsOpk && opkPair == null) return null;

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
    _ratchet = responder;
    _peerIkDh = Uint8List.fromList(env.senderIkDh);
    _peerIkSig = Uint8List.fromList(env.senderIkSig);
    _hasSentInit = true; // responders never send an init envelope

    try {
      final plaintext = await _decryptWith(responder, env, identity);
      // Consumed OPK: delete now (forward secrecy, R1 §3.4 / §5.4 step 2).
      if (needsOpk) {
        await _keyStore.deleteOneTimePrekey(env.opkId!);
      }
      await _persist();
      return plaintext;
    } on RatchetError {
      // Abort and discard everything (R1 §3.4 / §5.4 step 6).
      _ratchet = null;
      _peerIkDh = null;
      _peerIkSig = null;
      if (needsOpk) {
        await _keyStore.deleteOneTimePrekey(env.opkId!);
      }
      return null;
    }
  }

  /// Type 0x02: existing-session decrypt. Never creates sessions from
  /// ratchet messages (Sesame R3 §3.4 / §6.5). Sessions idle past 90 days
  /// are refused even when still in memory (§7.7).
  Future<String?> _handleRatchetEnvelope(
    SamayEnvelope env,
    E2eeIdentityKeys identity,
  ) async {
    if (_ratchet == null) {
      final saved = await _sessionStore.loadSession(chatId);
      if (saved == null) return null;
      _restore(saved);
    }
    final peer = _peerIkDh;
    if (peer == null) return null;
    if (!constantTimeEquals(env.senderIkDh, peer)) {
      return null; // identity binding (§7.1)
    }
    final lastUsed = _ratchet!.lastUsedAt;
    if (_clock().difference(lastUsed) > e2eeSessionMaxAge) {
      await _sessionStore.deleteSession(chatId);
      return null; // idle too long — session retired (§7.7)
    }
    try {
      final plaintext = await _decryptWith(_ratchet!, env, identity);
      await _persist();
      return plaintext;
    } on RatchetError {
      return null; // dropped message, session preserved (atomicity)
    }
  }

  Future<String> _decryptWith(
    RatchetState ratchet,
    SamayEnvelope env,
    E2eeIdentityKeys identity,
  ) async {
    final header = RatchetHeader(dh: env.dhPub, pn: env.pn, n: env.n);
    final plaintext = await ratchetDecrypt(
      ratchet,
      header,
      env.ciphertext,
      _adBase(identity),
      now: _clock(),
    );
    ratchet.pruneSkippedKeys(_clock());
    ratchet.lastUsedAt = _clock();
    return utf8.decode(plaintext);
  }

  /// AD_base = Encode(IK_dh_A) ‖ Encode(IK_dh_B) ‖ Encode(IK_sig_A) ‖
  /// Encode(IK_sig_B), sorted lexicographically by the two DH keys —
  /// role-independent (§6.1). Recomputed from the stored identity + the
  /// session's peer keys, never serialized (§8.3).
  Uint8List _adBase(E2eeIdentityKeys identity) {
    final myDh = identity.ikDhPublic;
    final peerDh = _peerIkDh!;
    final mySig = identity.ikSigPublic;
    final peerSig = _peerIkSig!;
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
  }

  Future<void> _persist() async {
    final json = toJson();
    if (json != null) {
      await _sessionStore.saveSession(chatId, json);
    }
  }
}
