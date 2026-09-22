library;
import 'dart:typed_data';

import 'package:samay/crypto/codec.dart';
import 'package:samay/crypto/constants.dart';
import 'package:samay/crypto/e2ee_primitives.dart';

/// The Signal Double Ratchet as specced in
/// E2EE-ARCHITECTURE.md §4 — non-HE variant with the recommended algorithms
/// of §7.2 and nonces derived from the message key.
///
///
/// `ratchetDecrypt` runs on a deep copy of the state and only commits the
/// copy back to the caller's state object after the AEAD step succeeds.
/// Any failure — auth error, skip-limit exceeded — leaves the state
/// byte-for-byte unchanged.
/// Raised on protocol-level ratchet failures (skip limit, missing chains,
/// authentication failure after decryption). The message must be dropped;
/// per the atomicity rule the state is untouched.
class RatchetError extends E2eeCryptoException {
  const RatchetError(super.message);
}

/// Double Ratchet message header: the sender's ratchet public key
/// plus the previous-chain length and message number.
class RatchetHeader {
  const RatchetHeader({required this.dh, required this.pn, required this.n});

  /// 32-byte sender ratchet public key.
  final Uint8List dh;
  final int pn;
  final int n;
}

/// Value-equality key for the skipped-message-key map `(dh_pub, n)` (§4.6).
class SkippedKeyIndex {
  const SkippedKeyIndex({required this.dh, required this.n});
  final Uint8List dh;
  final int n;

  @override
  bool operator ==(Object other) =>
      other is SkippedKeyIndex &&
      other.n == n &&
      constantTimeEquals(other.dh, dh);

  @override
  int get hashCode => Object.hash(n, Object.hashAll(dh));
}

/// Mutable Double Ratchet state.
///
/// Field names follow the mission contract: `rootKey` (RK),
/// `sendingChainKey` (CKs), `receivingChainKey` (CKr),
/// `sendingMsgKeyIdx` (Ns), `receivingMsgKeyIdx` (Nr),
/// `prevSendingChainLen` (PN), `remoteRatchetKey` (DHr),
/// `localRatchetKey` (DHs).
class RatchetState {
  RatchetState({
    required this.localRatchetKey,
    required this.remoteRatchetKey,
    required this.rootKey,
    required this.sendingChainKey,
    required this.receivingChainKey,
    required this.role,
    required DateTime now,
  }) : sendingMsgKeyIdx = 0,
       receivingMsgKeyIdx = 0,
       prevSendingChainLen = 0,
       createdAt = now,
       lastUsedAt = now;

  /// Self ratchet keypair (sending).
  E2eeKeyPair localRatchetKey;

  /// Remote ratchet public key (32 bytes), null until first receive.
  Uint8List? remoteRatchetKey;

  /// Root key (32 bytes).
  Uint8List rootKey;

  /// Sending chain key (32 bytes), null until initialized by a DH ratchet.
  Uint8List? sendingChainKey;

  /// Receiving chain key (32 bytes), null until the first DH ratchet.
  Uint8List? receivingChainKey;

  /// Sending message number (`Ns`).
  int sendingMsgKeyIdx = 0;

  /// Receiving message number (`Nr`).
  int receivingMsgKeyIdx = 0;

  /// Messages in the previous sending chain (`PN`).
  int prevSendingChainLen = 0;

  /// Skipped message keys indexed by (ratchet pub, message number) (§4.6).
  Map<SkippedKeyIndex, Uint8List> skippedMessageKeys = {};

  /// Insertion time of each skipped key (drives the 30-day pruning, §4.6).
  Map<SkippedKeyIndex, DateTime> skippedKeyInsertedAt = {};

  /// `'initiator'` (Alice, X3DH initiator) or `'responder'` (Bob).
  final String role;

  final DateTime createdAt;

  /// Touched on every successful encrypt/decrypt (drives 90-day expiry).
  DateTime lastUsedAt;

  /// Deep copy used by the atomic decrypt path.
  RatchetState clone() {
    final copy = RatchetState(
      localRatchetKey: localRatchetKey,
      remoteRatchetKey: remoteRatchetKey == null
          ? null
          : Uint8List.fromList(remoteRatchetKey!),
      rootKey: Uint8List.fromList(rootKey),
      sendingChainKey: sendingChainKey == null
          ? null
          : Uint8List.fromList(sendingChainKey!),
      receivingChainKey: receivingChainKey == null
          ? null
          : Uint8List.fromList(receivingChainKey!),
      role: role,
      now: createdAt,
    );
    copy.sendingMsgKeyIdx = sendingMsgKeyIdx;
    copy.receivingMsgKeyIdx = receivingMsgKeyIdx;
    copy.prevSendingChainLen = prevSendingChainLen;
    copy.skippedMessageKeys = {
      for (final e in skippedMessageKeys.entries)
        SkippedKeyIndex(dh: Uint8List.fromList(e.key.dh), n: e.key.n): Uint8List.fromList(e.value),
    };
    copy.skippedKeyInsertedAt = Map.from(skippedKeyInsertedAt);
    copy.lastUsedAt = lastUsedAt;
    return copy;
  }

  /// Commits `work` (the decrypted working copy) into this state.
  void commit(RatchetState work) {
    localRatchetKey = work.localRatchetKey;
    remoteRatchetKey = work.remoteRatchetKey;
    rootKey = work.rootKey;
    sendingChainKey = work.sendingChainKey;
    receivingChainKey = work.receivingChainKey;
    sendingMsgKeyIdx = work.sendingMsgKeyIdx;
    receivingMsgKeyIdx = work.receivingMsgKeyIdx;
    prevSendingChainLen = work.prevSendingChainLen;
    skippedMessageKeys = work.skippedMessageKeys;
    skippedKeyInsertedAt = work.skippedKeyInsertedAt;
    lastUsedAt = work.lastUsedAt;
  }

  /// Drops skipped message keys older than 30 days.
  /// Called on session save after every successful decrypt.
  void pruneSkippedKeys(DateTime now) {
    final cutoff = now.subtract(e2eeSkippedKeyMaxAge);
    final expired = skippedKeyInsertedAt.entries
        .where((e) => e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
    for (final key in expired) {
      skippedMessageKeys.remove(key);
      skippedKeyInsertedAt.remove(key);
    }
  }

  /// Serializes the ratchet state (§8.3). Bytes are base64url, no padding.
  Map<String, dynamic> toJson() {
    final skipped = <Map<String, dynamic>>[];
    for (final entry in skippedMessageKeys.entries) {
      skipped.add({
        'dh': base64UrlNoPadEncode(entry.key.dh),
        'n': entry.key.n,
        'mk': base64UrlNoPadEncode(entry.value),
        'at': skippedKeyInsertedAt[entry.key]?.toIso8601String(),
      });
    }
    return {
      'role': role,
      'dhs_priv': base64UrlNoPadEncode(localRatchetKey.privateKey),
      'dhs_pub': base64UrlNoPadEncode(localRatchetKey.publicKey),
      'dhr_pub': remoteRatchetKey == null
          ? null
          : base64UrlNoPadEncode(remoteRatchetKey!),
      'rk': base64UrlNoPadEncode(rootKey),
      'cks': sendingChainKey == null
          ? null
          : base64UrlNoPadEncode(sendingChainKey!),
      'ckr': receivingChainKey == null
          ? null
          : base64UrlNoPadEncode(receivingChainKey!),
      'ns': sendingMsgKeyIdx,
      'nr': receivingMsgKeyIdx,
      'pn': prevSendingChainLen,
      'skipped': skipped,
      'created_at': createdAt.toIso8601String(),
      'last_used_at': lastUsedAt.toIso8601String(),
    };
  }

  factory RatchetState.fromJson(Map<String, dynamic> json) {
    final localKey = E2eeKeyPair(
      privateKey: base64UrlNoPadDecode(json['dhs_priv'] as String)!,
      publicKey: base64UrlNoPadDecode(json['dhs_pub'] as String)!,
      type: E2eeKeyType.x25519,
    );
    final state = RatchetState(
      localRatchetKey: localKey,
      remoteRatchetKey: json['dhr_pub'] == null
          ? null
          : base64UrlNoPadDecode(json['dhr_pub'] as String),
      rootKey: base64UrlNoPadDecode(json['rk'] as String)!,
      sendingChainKey: json['cks'] == null
          ? null
          : base64UrlNoPadDecode(json['cks'] as String),
      receivingChainKey: json['ckr'] == null
          ? null
          : base64UrlNoPadDecode(json['ckr'] as String),
      role: json['role'] as String,
      now: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
    state.sendingMsgKeyIdx = json['ns'] as int;
    state.receivingMsgKeyIdx = json['nr'] as int;
    state.prevSendingChainLen = json['pn'] as int;
    for (final entry in (json['skipped'] as List<dynamic>? ?? const [])) {
      final map = Map<String, dynamic>.from(entry as Map);
      final index = SkippedKeyIndex(
        dh: base64UrlNoPadDecode(map['dh'] as String)!,
        n: map['n'] as int,
      );
      state.skippedMessageKeys[index] = base64UrlNoPadDecode(map['mk'] as String)!;
      final at = map['at'];
      if (at is String) {
        state.skippedKeyInsertedAt[index] = DateTime.tryParse(at) ?? DateTime.now();
      }
    }
    final lastUsed = json['last_used_at'];
    if (lastUsed is String) {
      state.lastUsedAt = DateTime.tryParse(lastUsed) ?? state.lastUsedAt;
    }
    return state;
  }
}

/// `KDF_RK(rk, dh_out)`: HKDF-SHA256(salt = rk, ikm = dh_out,
/// info = "samay.e2ee.rk.v1", L = 64) → (rk', ck) — first 32 bytes the new
/// root key, last 32 the chain key (E2EE §4.1).
Future<({Uint8List rootKey, Uint8List chainKey})> kdfRootKey(
  Uint8List rootKey,
  Uint8List dhOutput,
) async {
  final out = await hkdfSha256(
    ikm: dhOutput,
    salt: rootKey,
    info: utf8Bytes(e2eeRatchetInfo),
    length: 64,
  );
  return (
    rootKey: Uint8List.sublistView(out, 0, 32),
    chainKey: Uint8List.sublistView(out, 32, 64),
  );
}

/// `KDF_CK(ck)` → `(ck_next, mk)` with the 0x02/0x01 HMAC constants (§4.1).
Future<({Uint8List nextChainKey, Uint8List messageKey})> kdfChainKey(
  Uint8List chainKey,
) =>
    deriveMessageKey(chainKey);

/// RatchetInitAlice: the X3DH initiator. `rootKey` is
/// the X3DH shared secret `SK`; `bobRatchetKey` is Bob's signed prekey
/// public key (SPKB).
Future<RatchetState> ratchetInitAlice({
  required Uint8List rootKey,
  required Uint8List bobRatchetKey,
  DateTime? now,
}) async {
  final dhs = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);
  final dhOut = await dh(dhs, bobRatchetKey);
  final derived = await kdfRootKey(rootKey, dhOut);
  return RatchetState(
    localRatchetKey: dhs,
    remoteRatchetKey: bobRatchetKey,
    rootKey: derived.rootKey,
    sendingChainKey: derived.chainKey,
    receivingChainKey: null,
    role: 'initiator',
    now: now ?? DateTime.now(),
  );
}

/// RatchetInitBob: the X3DH responder. `rootKey` is
/// the X3DH shared secret `SK`; `bobRatchetKeyPair` is Bob's stored signed
/// prekey keypair.
Future<RatchetState> ratchetInitBob({
  required Uint8List rootKey,
  required E2eeKeyPair bobRatchetKeyPair,
  DateTime? now,
}) async {
  return RatchetState(
    localRatchetKey: bobRatchetKeyPair,
    remoteRatchetKey: null,
    rootKey: rootKey,
    sendingChainKey: null,
    receivingChainKey: null,
    role: 'responder',
    now: now ?? DateTime.now(),
  );
}

/// RatchetEncrypt: advances the sending chain, produces the
/// header + ciphertext. [adBase] is the 128-byte AD_base (§6.1); the AEAD
/// associated data is `adBase ‖ header_bytes` (CONCAT rule, fixed-length
/// header so no length prefix is needed).
///
/// Throws [RatchetError] when there is no sending chain yet (responder
/// before receiving the init message).
Future<(RatchetHeader, Uint8List)> ratchetEncrypt(
  RatchetState state,
  Uint8List plaintext,
  Uint8List adBase,
) async {
  final cks = state.sendingChainKey;
  if (cks == null) {
    throw const RatchetError('no sending chain: receive a message first');
  }
  final step = await kdfChainKey(cks);
  state.sendingChainKey = step.nextChainKey;
  final n = state.sendingMsgKeyIdx;
  state.sendingMsgKeyIdx += 1;
  final header = RatchetHeader(dh: state.localRatchetKey.publicKey, pn: state.prevSendingChainLen, n: n);
  final expanded = await expandMessageKey(step.messageKey);
  final ciphertext = await aesGcmEncrypt(
    key: Uint8List.sublistView(expanded, 0, e2eeAeadKeyLength),
    nonce: Uint8List.sublistView(expanded, e2eeAeadKeyLength),
    plaintext: plaintext,
    aad: concatBytes([
      adBase,
      encodeHeaderBytes(header.dh, header.pn, header.n),
    ]),
  );
  state.lastUsedAt = DateTime.now();
  return (header, ciphertext);
}

/// RatchetDecrypt: full receive path — skipped keys,
/// DH ratchet on new ratchet keys, symmetric-ratchet step, AEAD decrypt.
///
/// Runs atomically on a deep copy: on any failure (auth, skip limit) the
/// caller's state is left untouched and a [RatchetError] is thrown.
Future<Uint8List> ratchetDecrypt(
  RatchetState state,
  RatchetHeader header,
  Uint8List ciphertext,
  Uint8List adBase, {
  DateTime? now,
}) async {
  final timestamp = now ?? DateTime.now();
  final work = state.clone();
  var mk = _trySkippedMessageKeys(work, header);
  if (mk == null) {
    if (!constantTimeEquals(header.dh, work.remoteRatchetKey ?? Uint8List(0))) {
      await _skipMessageKeys(work, header.pn, timestamp);
      await _dhRatchet(work, header);
    }
    await _skipMessageKeys(work, header.n, timestamp);
    final ckr = work.receivingChainKey;
    if (ckr == null) {
      throw const RatchetError('no receiving chain for this message');
    }
    final step = await kdfChainKey(ckr);
    work.receivingChainKey = step.nextChainKey;
    work.receivingMsgKeyIdx += 1;
    work.lastUsedAt = timestamp;
    mk = step.messageKey;
  }
  final expanded = await expandMessageKey(mk);
  final plaintext = await aesGcmDecrypt(
    key: Uint8List.sublistView(expanded, 0, e2eeAeadKeyLength),
    nonce: Uint8List.sublistView(expanded, e2eeAeadKeyLength),
    ciphertext: ciphertext,
    aad: concatBytes([
      adBase,
      encodeHeaderBytes(header.dh, header.pn, header.n),
    ]),
  );
  if (plaintext == null) {
    throw const RatchetError('message authentication failed');
  }
  state.commit(work);
  return plaintext;
}

/// `TrySkippedMessageKeys`: pops (header.dh, header.n) from MKSKIPPED.
Uint8List? _trySkippedMessageKeys(RatchetState state, RatchetHeader header) {
  final index = SkippedKeyIndex(dh: header.dh, n: header.n);
  final mk = state.skippedMessageKeys.remove(index);
  if (mk != null) {
    state.skippedKeyInsertedAt.remove(index);
    state.lastUsedAt = DateTime.now();
  }
  return mk;
}

/// `SkipMessageKeys(until)`: advances the receiving chain storing every
/// skipped message key. Throws when the gap exceeds MAX_SKIP.
Future<void> _skipMessageKeys(RatchetState state, int until, DateTime now) async {
  if (state.receivingMsgKeyIdx + e2eeMaxSkip < until) {
    throw const RatchetError('skip limit exceeded');
  }
  final ckr = state.receivingChainKey;
  if (ckr == null) return;
  var chainKey = ckr;
  while (state.receivingMsgKeyIdx < until) {
    final step = await kdfChainKey(chainKey);
    final index = SkippedKeyIndex(dh: state.remoteRatchetKey!, n: state.receivingMsgKeyIdx);
    state.skippedMessageKeys[index] = step.messageKey;
    state.skippedKeyInsertedAt[index] = now;
    state.receivingChainKey = step.nextChainKey;
    state.receivingMsgKeyIdx += 1;
    chainKey = step.nextChainKey;
  }
}

/// `DHRatchet(header)`: seals the previous sending chain, installs the new
/// remote ratchet key and derives fresh receiving + sending chains
Future<void> _dhRatchet(RatchetState state, RatchetHeader header) async {
  state.prevSendingChainLen = state.sendingMsgKeyIdx;
  state.sendingMsgKeyIdx = 0;
  state.receivingMsgKeyIdx = 0;
  state.remoteRatchetKey = header.dh;
  final dh1 = await dh(state.localRatchetKey, header.dh);
  final first = await kdfRootKey(state.rootKey, dh1);
  state.rootKey = first.rootKey;
  state.receivingChainKey = first.chainKey;
  state.localRatchetKey = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);
  final dh2 = await dh(state.localRatchetKey, header.dh);
  final second = await kdfRootKey(state.rootKey, dh2);
  state.rootKey = second.rootKey;
  state.sendingChainKey = second.chainKey;
}
