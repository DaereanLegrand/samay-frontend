import 'package:samay/core/services/storage_service.dart';

/// Encrypted plaintext store for decrypted chat history (Signal model —
/// SQLCipher-equivalent, 2026-08-16).
///
/// The Double Ratchet is stateful and irreversible: an already-consumed
/// message can NEVER be re-decrypted after the ratchet chain advanced. The
/// server stores only E2EE envelopes, so re-rendering history after an app
/// restart (or an update) is only possible from stored plaintext — Signal
/// apps persist plaintext in an encrypted local DB (SQLCipher); Samay
/// persists it in the AES-256 encrypted Hive `message_cache` box, whose key
/// lives in the platform Keystore/Keychain (`samay.hive.key`).
///
/// This is the load-bearing half of the "Mensaje no descifrable after
/// restart" fix: cache-first serving in `ChatService._decryptMessageNow`
/// means history never re-touches the ratchet after a restart.
///
/// Security posture: identical to the previous "no plaintext caching"
/// policy's intent (E2EE-ARCHITECTURE.md §8.4 was amended) — at rest the
/// cache is AES-256 encrypted, the key never leaves the Keystore/Keychain,
/// and the box is wiped together with the key material on account deletion /
/// switch (`HiveService` key-loss degradation re-creates it empty, SEC-10).
abstract class MessagePlaintextStore {
  /// Stores the decrypted [plaintext] of message [messageId] in chat
  /// [chatId]. Overwrites any previous entry.
  Future<void> cache(String chatId, String messageId, String plaintext);

  /// The stored plaintext of message [messageId] in chat [chatId], or null
  /// when not cached.
  Future<String?> get(String chatId, String messageId);

  /// Removes the entry for message [messageId] in chat [chatId] (delete-for-
  /// me must also clear the cached copy).
  Future<void> delete(String chatId, String messageId);

  /// Drops the OLDEST entries of chat [chatId] until at most [maxPerChat]
  /// remain (bounded storage, aligned with the server message cap).
  Future<void> prune(String chatId, int maxPerChat);
}

/// Hive-backed store over [HiveService.messageBoxName] (encrypted with the
/// keystore-keyed AES-256 cipher, SEC-10/M-32). Keys are `chatId::messageId`;
/// values are `{"t": iso8601, "p": plaintext}` so pruning is deterministic
/// by cache time.
///
/// Requires `HiveService.init()` to have opened the message box (the app
/// does this at startup, `main.dart`).
class HiveMessagePlaintextStore implements MessagePlaintextStore {
  HiveMessagePlaintextStore(this._hive);

  final HiveService _hive;

  @override
  Future<void> cache(String chatId, String messageId, String plaintext) =>
      _hive.cacheMessage(chatId, messageId, plaintext);

  @override
  Future<String?> get(String chatId, String messageId) =>
      Future.value(_hive.getCachedMessage(chatId, messageId));

  @override
  Future<void> delete(String chatId, String messageId) =>
      _hive.deleteCachedMessage(chatId, messageId);

  @override
  Future<void> prune(String chatId, int maxPerChat) =>
      _hive.pruneCachedMessages(chatId, maxPerChat);
}

/// In-memory twin for tests and the two-party harness — the persisted
/// plaintext store's behavior with nothing persisted (a store instance
/// shared across "restarts" mirrors the device's encrypted Hive box).
class MemoryMessagePlaintextStore implements MessagePlaintextStore {
  final Map<String, String> _entries = {};
  final Map<String, DateTime> _insertedAt = {};

  @override
  Future<void> cache(String chatId, String messageId, String plaintext) async {
    final key = '$chatId::$messageId';
    _entries[key] = plaintext;
    _insertedAt[key] = DateTime.now();
  }

  @override
  Future<String?> get(String chatId, String messageId) async =>
      _entries['$chatId::$messageId'];

  @override
  Future<void> delete(String chatId, String messageId) async {
    final key = '$chatId::$messageId';
    _entries.remove(key);
    _insertedAt.remove(key);
  }

  @override
  Future<void> prune(String chatId, int maxPerChat) async {
    final prefix = '$chatId::';
    final entries = _entries.entries
        .where((e) => e.key.startsWith(prefix))
        .toList()
      ..sort((a, b) =>
          (_insertedAt[a.key] ?? DateTime(0)).compareTo(_insertedAt[b.key] ?? DateTime(0)));
    final excess = entries.length - maxPerChat;
    if (excess <= 0) return;
    for (final entry in entries.take(excess)) {
      _entries.remove(entry.key);
      _insertedAt.remove(entry.key);
    }
  }
}
