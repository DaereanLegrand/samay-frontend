import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:samay/core/logging/app_logger.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> storeToken(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> retrieveToken(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> deleteToken(String key) async {
    await _storage.delete(key: key);
  }
}

/// Hive-backed local cache (config, photo URLs, messages, notifications).
///
/// All boxes are encrypted with AES-256 (Hive's built-in cipher). The 32-byte
/// key never touches disk beside the data: it lives in `flutter_secure_storage`
/// (iOS Keychain / Android Keystore) as base64 under [hiveKeyStorageName].
///
/// Key-loss degradation: if the stored key no longer matches the on-disk boxes
/// (e.g. fresh install after a backup restore that did not carry the keychain
/// entry), opening fails and the box is re-created empty. This trades data for
/// availability — acceptable because these caches are disposable and rebuilt
/// from the backend. See SEC-10 / M-32.
class HiveService {
  static const configBoxName = 'config_cache';
  static const photoBoxName = 'photo_cache';
  static const messageBoxName = 'message_cache';
  static const notificationBoxName = 'notification_cache';
  static const friendsBoxName = 'friends_cache';
  static const minigameSummaryBoxName = 'minigame_summary_cache';
  static const feedBoxName = 'feed_cache';

  /// Secure-storage key under which the base64-encoded Hive encryption key
  /// (32 bytes = 256 bit, AES-256) is persisted.
  static const hiveKeyStorageName = 'samay.hive.key';

  final FlutterSecureStorage _secureStorage;
  final HiveInterface _hive;

  HiveService({FlutterSecureStorage? secureStorage, HiveInterface? hive})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _hive = hive ?? Hive;

  Future<Uint8List> _obtainEncryptionKey() async {
    final stored = await _secureStorage.read(key: hiveKeyStorageName);
    if (stored != null) {
      try {
        final decoded = base64Decode(stored);
        if (decoded.length == 32) return decoded;
      } on FormatException {
        // Corrupt stored key — regenerate below.
      }
    }
    final key = Uint8List.fromList(_hive.generateSecureKey());
    await _secureStorage.write(
      key: hiveKeyStorageName,
      value: base64Encode(key),
    );
    return key;
  }

  Future<Box<String>> _openBox(String name, Uint8List key) async {
    // runZonedGuarded's result is null when the guarded body fails; keep the
    // zone alive one extra microtask turn so the leaked duplicate error is
    // delivered to the onError below.
    final result = await runZonedGuarded<Future<Box<String>>>(
      () async {
        try {
          return await _hive.openBox<String>(
            name,
            encryptionCipher: HiveAesCipher(key),
            crashRecovery: false,
          );
        } on HiveError catch (error) {
          // Key CRC/checksum mismatch — the box was written with a different
          // key. (hive's default crashRecovery would silently truncate the box
          // here; we disable it so the mismatch surfaces and the disposable
          // cache is re-created instead.)
          AppLogger.instance.warn(
            'Hive box "$name" unreadable ($error); re-creating empty.',
          );
          return _recreateBox(name, key);
        } on ArgumentError catch (error) {
          // Wrong key produces an AES padding failure at open time.
          AppLogger.instance.warn(
            'Hive box "$name" key mismatch ($error); re-creating empty.',
          );
          return _recreateBox(name, key);
        }
      },
      (error, stackTrace) {
        // hive 2.2.3's HiveImpl._openBox completes the box-opening completer
        // with the same error it rethrows, leaking an unhandled async error
        // on every failed open. Absorb it here so it never reaches the app's
        // global error handlers (main.dart FlutterError/PlatformDispatcher).
        AppLogger.instance.warn(
          'Hive open of "$name" leaked a duplicate error: $error',
        );
      },
    );
    await Future<void>.delayed(Duration.zero);
    if (result == null) {
      throw StateError('Hive box "$name" could not be opened.');
    }
    return result;
  }

  /// Re-creates a box whose on-disk data was written with a different key.
  ///
  /// hive 2.2.3's failed-open path is NOT re-creation-safe: its `_openBox`
  /// catch closes the half-initialized box WITHOUT awaiting the close (the
  /// lock file's flock is released asynchronously), so deleting the box files
  /// and immediately re-opening the same name can deadlock on the still-held
  /// lock — an intermittent 30s+ hang under load (EF-04, reproduced ~50% of
  /// full-suite runs). Mitigations here:
  ///
  /// 1. `deleteBoxFromDisk` is retried — its exists→delete race throws
  ///    `FileSystemException` when hive's own deferred close deleted the lock
  ///    file in between; that must never abort the reset.
  /// 2. The re-open is bounded with a timeout; on contention, the retry's
  ///    delete unlinks the lock file (unlink of an open+locked file succeeds
  ///    on macOS), so the next open locks a fresh file and cannot block.
  ///
  /// Worst case (pathological contention on every box): ~19 s for the four
  /// caches — a bounded failure, never an unbounded hang.
  Future<Box<String>> _recreateBox(String name, Uint8List key) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _hive.deleteBoxFromDisk(name);
      } on FileSystemException {
        // The failed open's deferred cleanup may still be deleting the files;
        // give it one turn and retry the whole reset.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      }
      try {
        return await _hive.openBox<String>(
          name,
          encryptionCipher: HiveAesCipher(key),
          crashRecovery: false,
        ).timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // The leaked flock from the failed open is still blocking lock()
        // acquisition. Next attempt unlinks the lock file, creating a fresh
        // inode the leaked fd cannot contend with.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    throw StateError('Hive box "$name" could not be re-created after key loss.');
  }

  Future<void> init({bool initializeFlutter = true}) async {
    if (initializeFlutter) {
      await _hive.initFlutter();
    }
    final key = await _obtainEncryptionKey();
    await _openBox(configBoxName, key);
    await _openBox(photoBoxName, key);
    await _openBox(messageBoxName, key);
    await _openBox(notificationBoxName, key);
    await _openBox(friendsBoxName, key);
    await _openBox(minigameSummaryBoxName, key);
    await _openBox(feedBoxName, key);
  }

  Future<void> cacheConfig(Map<String, String> config) async {
    final box = _hive.box<String>(configBoxName);
    await box.putAll(config);
  }

  Map<String, String>? getCachedConfig() {
    final box = _hive.box<String>(configBoxName);
    if (box.isEmpty) return null;
    return box.toMap().map((k, v) => MapEntry(k, v));
  }

  // ---------------------------------------------------------------------------
  // On-device friend list cache (2026-08-29 — invite/buscar <5-char contract)
  // ---------------------------------------------------------------------------
  // The user's friend list is fetched in the BACKGROUND at app launch and
  // persisted here so the invite/buscar/search pickers can render it for
  // short (0–4 char) and empty queries WITHOUT network I/O and WITHOUT the
  // N+1 profile-fetch error path that used to surface as
  // "Error del servidor". Keyed by user id so an account switch never leaks
  // the previous account's friends.
  //
  // The stored value is the JSON-encoded list of search-shaped friend rows
  // (`UserSearchResult`: id/username/avatar_url, friendship_status=accepted)
  // — the exact shape the pickers render.

  /// Persists [friends] (search-shaped rows) for [userId].
  Future<void> cacheFriends(String userId, List<Map<String, dynamic>> friends) async {
    final box = _hive.box<String>(friendsBoxName);
    await box.put(userId, jsonEncode(friends));
  }

  /// The cached friends of [userId] as search-shaped maps, or null when the
  /// cache is cold for that user (no fetch happens here — pure disk read).
  List<Map<String, dynamic>>? getCachedFriends(String userId) {
    final box = _hive.box<String>(friendsBoxName);
    final raw = box.get(userId);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } on FormatException {
      return null;
    }
  }

  /// Removes the cached friends of [userId] (account switch / logout).
  Future<void> clearCachedFriends(String userId) async {
    final box = _hive.box<String>(friendsBoxName);
    await box.delete(userId);
  }

  // ---------------------------------------------------------------------------
  // Message plaintext cache (Signal plaintext-store backend, 2026-08-16 —
  // companion: lib/core/services/message_plaintext_store.dart)
  // ---------------------------------------------------------------------------
  // The Double Ratchet is stateful and irreversible: after the chain
  // advanced, an already-decrypted envelope can never be decrypted again.
  // The server stores only envelopes, so history re-rendering after a
  // restart MUST come from this cache (AES-256 at rest, key in the platform
  // Keystore/Keychain — the SQLCipher-equivalent). Keys are
  // `chatId::messageId`; values are `{"t": <iso8601>, "p": <plaintext>}` so
  // pruning is deterministic by cache time.

  /// Stores the decrypted [plaintext] of message [messageId] in chat
  /// [chatId] (write-through on every successful decrypt/send).
  Future<void> cacheMessage(
    String chatId,
    String messageId,
    String plaintext,
  ) async {
    final box = _hive.box<String>(messageBoxName);
    await box.put(
      '$chatId::$messageId',
      jsonEncode({
        't': DateTime.now().toIso8601String(),
        'p': plaintext,
      }),
    );
  }

  /// The stored plaintext of message [messageId] in chat [chatId], or null
  /// when not cached.
  String? getCachedMessage(String chatId, String messageId) {
    final box = _hive.box<String>(messageBoxName);
    final raw = box.get('$chatId::$messageId');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map)['p'] as String?;
    } on FormatException {
      return null;
    }
  }

  /// Removes the cached entry of message [messageId] in chat [chatId]
  /// (delete-for-me must not leave the tombstoned plaintext behind).
  Future<void> deleteCachedMessage(String chatId, String messageId) async {
    final box = _hive.box<String>(messageBoxName);
    await box.delete('$chatId::$messageId');
  }

  /// Drops the OLDEST entries of chat [chatId] until at most [maxPerChat]
  /// remain (bounded storage, aligned with the server message cap).
  Future<void> pruneCachedMessages(String chatId, int maxPerChat) async {
    final box = _hive.box<String>(messageBoxName);
    final prefix = '$chatId::';
    final entries = box.toMap().entries
        .where((e) => e.key.startsWith(prefix))
        .toList();
    final excess = entries.length - maxPerChat;
    if (excess <= 0) return;
    entries.sort((a, b) {
      final ta = _cacheTimestamp(a.value);
      final tb = _cacheTimestamp(b.value);
      if (ta == null || tb == null) return 0;
      return ta.compareTo(tb);
    });
    for (final entry in entries.take(excess)) {
      await box.delete(entry.key);
    }
  }

  static DateTime? _cacheTimestamp(String raw) {
    try {
      final t = (jsonDecode(raw) as Map)['t'];
      return t is String ? DateTime.tryParse(t) : null;
    } on FormatException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // On-device minigame match summary (202_minigame_play_v2 — the history /
  // summary lives on the device; the user directive said the server would
  // purge it later, so the device copy is the durable record).
  // ---------------------------------------------------------------------------
  // Keys are `minigame:<sessionId>`; values are the JSON-encoded summary map:
  // `{results, answers, reactions, aliases}` written when the match finishes.
  // AES-256 at rest (same box cipher as every Hive cache).

  /// Persists the finished match [summary] for [sessionId] on-device.
  Future<void> cacheMinigameSummary(
    String sessionId,
    Map<String, dynamic> summary,
  ) async {
    final box = _hive.box<String>(minigameSummaryBoxName);
    await box.put('minigame:$sessionId', jsonEncode(summary));
  }

  /// The on-device match summary for [sessionId], or null when the device has
  /// no record yet.
  Map<String, dynamic>? getCachedMinigameSummary(String sessionId) {
    final box = _hive.box<String>(minigameSummaryBoxName);
    final raw = box.get('minigame:$sessionId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
    } on FormatException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // On-device agnostic feed cache (2026-09-20). The feed is a mix of event
  // and minigame-match items; the JSON-encoded list is cached under the user
  // id so an account switch never leaks the previous account's feed, and the
  // tab renders instantly from disk before the network refresh lands.
  // ---------------------------------------------------------------------------

  /// Persists the [items] feed payload (JSON-encoded list) for [userId].
  Future<void> cacheFeed(String userId, List<Map<String, dynamic>> items) async {
    final box = _hive.box<String>(feedBoxName);
    await box.put(userId, jsonEncode(items));
  }

  /// The cached feed payload of [userId] as maps, or null when the cache is
  /// cold (pure disk read, no network).
  List<Map<String, dynamic>>? getCachedFeed(String userId) {
    final box = _hive.box<String>(feedBoxName);
    final raw = box.get(userId);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on FormatException {
      return null;
    }
  }

  /// Removes the cached feed of [userId] (account switch / logout).
  Future<void> clearCachedFeed(String userId) async {
    final box = _hive.box<String>(feedBoxName);
    await box.delete(userId);
  }
}
