library;
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
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

/// Resilient [FlutterSecureStorage] write wrapper (2026-08-31 on-device fix).
///
/// Two iOS Keychain failure modes, both handled here:
///
/// 1. **Duplicate item (`-25299` / `errSecDuplicateItem`)** — the plugin's
///    `write()` is a delete-then-set; on iOS the delete can race an
///    in-flight write to the SAME key (the minigame bundle delivery runs
///    parallel [Future.wait] envelopes), leaving a stale item that the set
///    then reports as already-existing. Retried as an explicit
///    `delete()` → `write()`.
/// 2. **Concurrent writes to the keychain** — all writes are serialized
///    through a per-instance future chain so parallel `_deliverBundle`
///    envelopes never touch the keychain at the same instant.
///
/// Reads/deletes pass straight through (they are not the racy path).
class _ResilientSecureStorage {
  _ResilientSecureStorage(FlutterSecureStorage storage) : _storage = storage;

  final FlutterSecureStorage _storage;
  Future<void> _writeTail = Future.value();

  Future<String?> read({required String key}) => _storage.read(key: key);

  Future<void> delete({required String key}) => _storage.delete(key: key);

  Future<Map<String, String>> readAll() => _storage.readAll();

  /// Serialized resilient write: chain onto the queue, then (if the direct
  /// write reports a duplicate item) delete + retry. The chain guarantees
  /// the keychain is only ever touched by one write at a time.
  Future<void> write({required String key, required String? value}) {
    final op = _writeTail.then((_) async {
      try {
        await _storage.write(key: key, value: value);
      } on PlatformException catch (e) {
        // iOS Keychain "The specified item already exists" — the stale item
        // from a raced delete-then-set. Clear it and retry the write.
        if (e.code == '-25299' || e.code == 'errSecDuplicateItem') {
          await _storage.delete(key: key);
          await _storage.write(key: key, value: value);
        } else {
          rethrow;
        }
      }
    });
    // Keep the chain alive regardless of an op's success so one failure does
    // not wedge the queue; the caller still sees the op's own error.
    _writeTail = op.catchError((Object _) {});
    return op;
  }
}

/// A retired signed prekey with its rotation-out timestamp — the 7-day
/// retention window (§5.2) counts from retirement, not from creation.
class _RetiredSpk {
  _RetiredSpk({required this.record, required this.retiredAt});

  final SignedPrekeyRecord record;
  final DateTime retiredAt;
}

// ---------------------------------------------------------------------------
// E2eeKeyStore
// ---------------------------------------------------------------------------

class MemoryE2eeKeyStore implements E2eeKeyStore {
  MemoryE2eeKeyStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  E2eeIdentityKeys? _identity;
  String? _owner;
  final Map<int, SignedPrekeyRecord> _signedPrekeys = {};
  final Map<int, _RetiredSpk> _retiredSignedPrekeys = {};
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
    _pruneExpiredRetired();
    final ids = _signedPrekeys.keys.toList()..sort();
    final oldId = ids.isNotEmpty ? ids.last : null;
    final id = (oldId ?? -1) + 1;
    final keyPair = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);
    final signature = await ed25519Sign(identity.ikSigPrivate, keyPair.publicKey);
    if (oldId != null) {
      final retired = _signedPrekeys.remove(oldId);
      if (retired != null) {
        _retiredSignedPrekeys[oldId] = _RetiredSpk(
          record: retired,
          retiredAt: _clock(),
        );
      }
    }
    _signedPrekeys[id] = SignedPrekeyRecord(
      id: id,
      keyPair: keyPair,
      signature: signature,
      createdAt: _clock(),
    );
  }

  /// Drops retired SPKs past their 7-day retention window (§5.2 — forward
  /// secrecy: the private key must not outlive the retention period).
  void _pruneExpiredRetired() {
    final cutoff = _clock().subtract(e2eeSignedPrekeyRetentionAge);
    _retiredSignedPrekeys.removeWhere((_, r) => r.retiredAt.isBefore(cutoff));
  }

  @override
  Future<E2eeKeyPair?> loadSignedPrekeyPrivate(int id) async {
    final current = _signedPrekeys[id];
    if (current != null) return current.keyPair;
    final retired = _retiredSignedPrekeys[id];
    if (retired == null) return null;
    if (_clock().difference(retired.retiredAt) > e2eeSignedPrekeyRetentionAge) {
      _retiredSignedPrekeys.remove(id);
      return null;
    }
    return retired.record.keyPair;
  }

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
  Future<String?> ownerUid() async => _owner;

  @override
  Future<void> setOwnerUid(String uid) async {
    _owner = uid;
  }

  @override
  Future<void> wipeAll() async {
    _identity = null;
    _owner = null;
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
  }) : _storage = _ResilientSecureStorage(
         secureStorage ?? const FlutterSecureStorage(),
       ),
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
  static const ownerUidKey = 'samay.e2ee.owner_uid';

  final _ResilientSecureStorage _storage;
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
    // Only current + 1 retained (§5.2): the grand-retired key file (from
    // the previous rotation) is deleted now.
    final prevRetired = meta?['retired_id'] as int?;
    if (prevRetired != null && prevRetired != oldId) {
      await _storage.delete(key: '$spkPrivPrefix$prevRetired');
    }
    await _storage.write(
      key: spkMetaKey,
      value: jsonEncode({
        'current_id': id,
        'rotated_at': _clock().toIso8601String(),
        'retired_id': oldId,
        'retired_at': oldId == null ? null : _clock().toIso8601String(),
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
    final meta = await _readSpkMeta();
    if (meta == null) return null;
    final currentId = meta['current_id'] as int?;
    if (id == currentId) {
      return _loadSpkPrivate(id);
    }
    if (id == meta['retired_id'] as int?) {
      // Retained for 7 days after rotation (§5.2), then deleted.
      final retiredAt = DateTime.tryParse(meta['retired_at'] as String? ?? '');
      if (retiredAt != null &&
          _clock().difference(retiredAt) > e2eeSignedPrekeyRetentionAge) {
        await _storage.delete(key: '$spkPrivPrefix$id');
        return null;
      }
      return _loadSpkPrivate(id);
    }
    // Unknown id (stale meta from an older app version): purge the orphan
    // key file — it is not current and not within any retention window.
    await _storage.delete(key: '$spkPrivPrefix$id');
    return null;
  }

  Future<E2eeKeyPair?> _loadSpkPrivate(int id) async {
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
  Future<String?> ownerUid() async => _storage.read(key: ownerUidKey);

  @override
  Future<void> setOwnerUid(String uid) async {
    await _storage.write(key: ownerUidKey, value: uid);
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
  Future<void> wipeAll() async {
    _sessions.clear();
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
  }) : _storage = _ResilientSecureStorage(
         secureStorage ?? const FlutterSecureStorage(),
       ),
       _clock = clock ?? DateTime.now;

  static const sessionKeyPrefix = 'samay.e2ee.session.';
  static const indexKey = 'samay.e2ee.session.index';

  final _ResilientSecureStorage _storage;
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
  Future<void> wipeAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(sessionKeyPrefix) || key == indexKey) {
        await _storage.delete(key: key);
      }
    }
  }

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
