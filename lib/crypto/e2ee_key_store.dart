library;
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:samay/crypto/codec.dart';
import 'package:samay/crypto/constants.dart';
import 'package:samay/crypto/e2ee_primitives.dart';
import 'package:samay/crypto/interfaces.dart';

/// Device-local key and session storage (E2EE-ARCHITECTURE.md §8).
///
/// - [SecureE2eeKeyStore] / [SecureE2eeSessionStore]: flutter_secure_storage
///   backed (iOS Keychain / Android Keystore), namespaces per §8.2,
///   90-day expiry sweep (§7.7), `wipeAll()` for account deletion (§7.6).
/// - [MemoryE2eeKeyStore] / [MemoryE2eeSessionStore]: in-memory twins for
///   tests and the two-party integration harness.
///
/// Both secure stores take the storage plugin as a **constructor parameter**
/// (the injectable seam) — tests substitute a mock; the plugin is never
/// hardcoded inside the classes.
/// Generates a registration id in [1, 0x3FFF] (libsignal-compatible).
int _generateRegistrationId() => Random.secure().nextInt(0x3FFF) + 1;

// ---------------------------------------------------------------------------
// E2eeKeyStore
// ---------------------------------------------------------------------------

class MemoryE2eeKeyStore implements E2eeKeyStore {
  MemoryE2eeKeyStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  E2eeIdentityKeys? _identity;
  final Map<int, SignedPrekeyRecord> _signedPrekeys = {};
  final Map<int, SignedPrekeyRecord> _retiredSignedPrekeys = {};
  final Map<int, OneTimePrekeyRecord> _oneTimePrekeys = {};
  int _nextOpkId = 0;

  @override
  Future<E2eeIdentityKeys> loadOrCreateIdentity() async {
    if (_identity != null) return _identity!;
    final dh = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);
    final sig = await E2eeKeyPair.generate(type: E2eeKeyType.ed25519);
    return _identity = E2eeIdentityKeys(
      ikDhPrivate: Uint8List.fromList(dh.privateKey),
      ikDhPublic: Uint8List.fromList(dh.publicKey),
      ikSigPrivate: Uint8List.fromList(sig.privateKey),
      ikSigPublic: Uint8List.fromList(sig.publicKey),
      registrationId: _generateRegistrationId(),
    );
  }

  @override
  Future<SignedPrekeyRecord> currentSignedPrekey() async {
    if (_signedPrekeys.isEmpty || _needsRotation()) {
      await rotateSignedPrekey();
    }
    final ids = _signedPrekeys.keys.toList()..sort();
    return _signedPrekeys[ids.last]!;
  }

  bool _needsRotation() {
    final newest = _signedPrekeys.values
        .map((r) => r.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return _clock().difference(newest) >= e2eeSignedPrekeyRotationAge;
  }

  @override
  Future<void> rotateSignedPrekey() async {
    final identity = await loadOrCreateIdentity();
    final ids = _signedPrekeys.keys.toList()..sort();
    final oldId = ids.isNotEmpty ? ids.last : null;
    final id = (oldId ?? -1) + 1;
    final keyPair = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);
    final signature = await ed25519Sign(identity.ikSigPrivate, keyPair.publicKey);
    if (oldId != null) {
      final retired = _signedPrekeys.remove(oldId);
      if (retired != null) {
        _retiredSignedPrekeys[oldId] = retired;
      }
    }
    _signedPrekeys[id] = SignedPrekeyRecord(
      id: id,
      keyPair: keyPair,
      signature: signature,
      createdAt: _clock(),
    );
  }

  @override
  Future<E2eeKeyPair?> loadSignedPrekeyPrivate(int id) async =>
      _signedPrekeys[id]?.keyPair ?? _retiredSignedPrekeys[id]?.keyPair;

  @override
  Future<int> oneTimePrekeyCount() async => _oneTimePrekeys.length;

  @override
  Future<List<OneTimePrekeyRecord>> generateOneTimePrekeys(int n) async {
    final records = <OneTimePrekeyRecord>[];
    for (var i = 0; i < n; i++) {
      final keyPair = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);
      final record = OneTimePrekeyRecord(
        id: _nextOpkId++,
        keyPair: keyPair,
        createdAt: _clock(),
      );
      _oneTimePrekeys[record.id] = record;
      records.add(record);
    }
    return records;
  }

  @override
  Future<E2eeKeyPair?> loadOneTimePrekeyPrivate(int id) async =>
      _oneTimePrekeys[id]?.keyPair;

  @override
  Future<void> deleteOneTimePrekey(int id) async {
    _oneTimePrekeys.remove(id);
  }

  @override
  Future<void> wipeAll() async {
    _identity = null;
    _signedPrekeys.clear();
    _retiredSignedPrekeys.clear();
    _oneTimePrekeys.clear();
    _nextOpkId = 0;
  }
}

/// flutter_secure_storage-backed key store. Namespaces per §8.2:
///
/// | Key | Contents |
/// |-----|----------|
/// | `samay.e2ee.identity.dh.priv` / `.pub` | X25519 identity (raw 32 B, base64url) |
/// | `samay.e2ee.identity.sig.priv` / `.pub` | Ed25519 identity |
/// | `samay.e2ee.registration_id` | u32 as decimal string |
/// | `samay.e2ee.spk.priv.<id>` | signed prekey private keys (current + 1 retained) |
/// | `samay.e2ee.spk.meta` | JSON `{current_id, rotated_at, retired_id}` |
/// | `samay.e2ee.opk.priv.<id>` | one-time prekey private keys |
/// | `samay.e2ee.opk.meta` | JSON `{count, next_id}` |
class SecureE2eeKeyStore implements E2eeKeyStore {
  SecureE2eeKeyStore({
    FlutterSecureStorage? secureStorage,
    DateTime Function()? clock,
  }) : _storage = secureStorage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  static const identityDhPrivKey = 'samay.e2ee.identity.dh.priv';
  static const identityDhPubKey = 'samay.e2ee.identity.dh.pub';
  static const identitySigPrivKey = 'samay.e2ee.identity.sig.priv';
  static const identitySigPubKey = 'samay.e2ee.identity.sig.pub';
  static const registrationIdKey = 'samay.e2ee.registration_id';
  static const spkMetaKey = 'samay.e2ee.spk.meta';
  static const spkPrivPrefix = 'samay.e2ee.spk.priv.';
  static const opkMetaKey = 'samay.e2ee.opk.meta';
  static const opkPrivPrefix = 'samay.e2ee.opk.priv.';

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;

  @override
  Future<E2eeIdentityKeys> loadOrCreateIdentity() async {
    final existing = await _readIdentity();
    if (existing != null) return existing;

    final dh = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);
    final sig = await E2eeKeyPair.generate(type: E2eeKeyType.ed25519);
    final registrationId = _generateRegistrationId();
    await _storage.write(key: identityDhPrivKey, value: base64UrlNoPadEncode(dh.privateKey));
    await _storage.write(key: identityDhPubKey, value: base64UrlNoPadEncode(dh.publicKey));
    await _storage.write(key: identitySigPrivKey, value: base64UrlNoPadEncode(sig.privateKey));
    await _storage.write(key: identitySigPubKey, value: base64UrlNoPadEncode(sig.publicKey));
    await _storage.write(key: registrationIdKey, value: '$registrationId');
    return E2eeIdentityKeys(
      ikDhPrivate: Uint8List.fromList(dh.privateKey),
      ikDhPublic: Uint8List.fromList(dh.publicKey),
      ikSigPrivate: Uint8List.fromList(sig.privateKey),
      ikSigPublic: Uint8List.fromList(sig.publicKey),
      registrationId: registrationId,
    );
  }

  Future<E2eeIdentityKeys?> _readIdentity() async {
    final dhPriv = await _storage.read(key: identityDhPrivKey);
    final dhPub = await _storage.read(key: identityDhPubKey);
    final sigPriv = await _storage.read(key: identitySigPrivKey);
    final sigPub = await _storage.read(key: identitySigPubKey);
    final reg = await _storage.read(key: registrationIdKey);
    if (dhPriv == null || dhPub == null || sigPriv == null || sigPub == null || reg == null) {
      return null;
    }
    return E2eeIdentityKeys(
      ikDhPrivate: base64UrlNoPadDecode(dhPriv)!,
      ikDhPublic: base64UrlNoPadDecode(dhPub)!,
      ikSigPrivate: base64UrlNoPadDecode(sigPriv)!,
      ikSigPublic: base64UrlNoPadDecode(sigPub)!,
      registrationId: int.parse(reg),
    );
  }

  @override
  Future<SignedPrekeyRecord> currentSignedPrekey() async {
    final meta = await _readSpkMeta();
    if (meta == null || _needsRotation(meta)) {
      return rotateSignedPrekey();
    }
    final priv = await _storage.read(key: '$spkPrivPrefix${meta['current_id']}');
    if (priv == null) return rotateSignedPrekey();
    final signature = meta['sig'] is String
        ? base64UrlNoPadDecode(meta['sig'] as String)!
        : Uint8List(0);
    return SignedPrekeyRecord(
      id: meta['current_id'] as int,
      keyPair: await _pairFromPrivate(priv),
      signature: signature,
      createdAt: DateTime.parse(meta['rotated_at'] as String),
    );
  }

  bool _needsRotation(Map<String, dynamic> meta) {
    final rotatedAt = DateTime.parse(meta['rotated_at'] as String);
    return _clock().difference(rotatedAt) >= e2eeSignedPrekeyRotationAge;
  }

  @override
  Future<SignedPrekeyRecord> rotateSignedPrekey() async {
    final identity = await loadOrCreateIdentity();
    final meta = await _readSpkMeta();
    final oldId = meta?['current_id'] as int?;
    final id = (oldId ?? -1) + 1;
    final keyPair = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);
    final signature = await ed25519Sign(identity.ikSigPrivate, keyPair.publicKey);
    await _storage.write(key: '$spkPrivPrefix$id', value: base64UrlNoPadEncode(keyPair.privateKey));
    await _storage.write(
      key: spkMetaKey,
      value: jsonEncode({
        'current_id': id,
        'rotated_at': _clock().toIso8601String(),
        'retired_id': oldId,
        'sig': base64UrlNoPadEncode(signature),
      }),
    );
    return SignedPrekeyRecord(id: id, keyPair: keyPair, signature: signature, createdAt: _clock());
  }

  Future<Map<String, dynamic>?> _readSpkMeta() async {
    final raw = await _storage.read(key: spkMetaKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<E2eeKeyPair?> loadSignedPrekeyPrivate(int id) async {
    final priv = await _storage.read(key: '$spkPrivPrefix$id');
    if (priv == null) return null;
    return _pairFromPrivate(priv);
  }

  Future<E2eeKeyPair> _pairFromPrivate(String b64) =>
      E2eeKeyPair.fromSeed(base64UrlNoPadDecode(b64)!, type: E2eeKeyType.x25519);

  @override
  Future<int> oneTimePrekeyCount() async {
    final meta = await _readOpkMeta();
    return meta?['count'] as int? ?? 0;
  }

  @override
  Future<List<OneTimePrekeyRecord>> generateOneTimePrekeys(int n) async {
    final meta = await _readOpkMeta() ?? <String, dynamic>{};
    var nextId = meta['next_id'] as int? ?? 0;
    final records = <OneTimePrekeyRecord>[];
    for (var i = 0; i < n; i++) {
      final keyPair = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);
      await _storage.write(key: '$opkPrivPrefix$nextId', value: base64UrlNoPadEncode(keyPair.privateKey));
      records.add(OneTimePrekeyRecord(id: nextId, keyPair: keyPair, createdAt: _clock()));
      nextId += 1;
    }
    await _storage.write(
      key: opkMetaKey,
      value: jsonEncode({'count': (meta['count'] as int? ?? 0) + n, 'next_id': nextId}),
    );
    return records;
  }

  Future<Map<String, dynamic>?> _readOpkMeta() async {
    final raw = await _storage.read(key: opkMetaKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<E2eeKeyPair?> loadOneTimePrekeyPrivate(int id) async {
    final priv = await _storage.read(key: '$opkPrivPrefix$id');
    if (priv == null) return null;
    return _pairFromPrivate(priv);
  }

  @override
  Future<void> deleteOneTimePrekey(int id) async {
    await _storage.delete(key: '$opkPrivPrefix$id');
    final meta = await _readOpkMeta();
    if (meta != null) {
      final count = (meta['count'] as int? ?? 1) - 1;
      await _storage.write(
        key: opkMetaKey,
        value: jsonEncode({...meta, 'count': count < 0 ? 0 : count}),
      );
    }
  }

  @override
  Future<void> wipeAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith('samay.e2ee.')) {
        await _storage.delete(key: key);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// E2eeSessionStore
// ---------------------------------------------------------------------------

class MemoryE2eeSessionStore implements E2eeSessionStore {
  MemoryE2eeSessionStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, String> _sessions = {};

  @override
  Future<String?> loadSession(String chatId) async {
    final json = _sessions[chatId];
    if (json == null) return null;
    if (_isExpired(json)) {
      await deleteSession(chatId);
      return null;
    }
    return json;
  }

  @override
  Future<void> saveSession(String chatId, String json) async {
    _sessions[chatId] = json;
  }

  @override
  Future<void> deleteSession(String chatId) async {
    _sessions.remove(chatId);
  }

  @override
  Future<Map<String, String>> sessionIndex() async {
    final index = <String, String>{};
    for (final entry in _sessions.entries) {
      final peer = _peerIkDh(entry.value);
      if (peer != null) index[peer] = entry.key;
    }
    return index;
  }

  @override
  Future<void> sweepExpiredSessions({int maxAgeDays = 90}) async {
    for (final chatId in _sessions.keys.toList()) {
      if (_isExpired(_sessions[chatId]!, maxAgeDays: maxAgeDays)) {
        _sessions.remove(chatId);
      }
    }
  }

  bool _isExpired(String json, {int maxAgeDays = 90}) {
    final lastUsed = _lastUsedAt(json);
    if (lastUsed == null) return false;
    return _clock().difference(lastUsed) > Duration(days: maxAgeDays);
  }
}

class SecureE2eeSessionStore implements E2eeSessionStore {
  SecureE2eeSessionStore({
    FlutterSecureStorage? secureStorage,
    DateTime Function()? clock,
  }) : _storage = secureStorage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  static const sessionKeyPrefix = 'samay.e2ee.session.';
  static const indexKey = 'samay.e2ee.session.index';

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;

  @override
  Future<String?> loadSession(String chatId) async {
    final json = await _storage.read(key: '$sessionKeyPrefix$chatId');
    if (json == null) return null;
    final lastUsed = _lastUsedAt(json);
    if (lastUsed != null && _clock().difference(lastUsed) > e2eeSessionMaxAge) {
      await deleteSession(chatId);
      return null;
    }
    return json;
  }

  @override
  Future<void> saveSession(String chatId, String json) async {
    await _storage.write(key: '$sessionKeyPrefix$chatId', value: json);
    final peer = _peerIkDh(json);
    if (peer != null) {
      final index = await _readIndex();
      index[peer] = chatId;
      await _writeIndex(index);
    }
  }

  @override
  Future<void> deleteSession(String chatId) async {
    final json = await _storage.read(key: '$sessionKeyPrefix$chatId');
    await _storage.delete(key: '$sessionKeyPrefix$chatId');
    final peer = json == null ? null : _peerIkDh(json);
    if (peer != null) {
      final index = await _readIndex();
      if (index.remove(peer) != null) {
        await _writeIndex(index);
      }
    }
  }

  @override
  Future<Map<String, String>> sessionIndex() => _readIndex();

  @override
  Future<void> sweepExpiredSessions({int maxAgeDays = 90}) async {
    final all = await _storage.readAll();
    for (final entry in all.entries) {
      if (!entry.key.startsWith(sessionKeyPrefix)) continue;
      final lastUsed = _lastUsedAt(entry.value);
      if (lastUsed != null && _clock().difference(lastUsed) > Duration(days: maxAgeDays)) {
        await deleteSession(entry.key.substring(sessionKeyPrefix.length));
      }
    }
  }

  Future<Map<String, String>> _readIndex() async {
    final raw = await _storage.read(key: indexKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeIndex(Map<String, String> index) =>
      _storage.write(key: indexKey, value: jsonEncode(index));
}

// ---------------------------------------------------------------------------
// Shared lifecycle helpers (kept out of the JSON contract — the stores only
// peek at lifecycle fields; the full state is parsed by E2eeSession).
// ---------------------------------------------------------------------------

DateTime? _lastUsedAt(String json) {
  try {
    final raw = (jsonDecode(json) as Map)['last_used_at'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  } on FormatException {
    return null;
  }
}

String? _peerIkDh(String json) {
  try {
    final raw = (jsonDecode(json) as Map)['peer_ik_dh'];
    if (raw is! String) return null;
    return raw;
  } on FormatException {
    return null;
  }
}
