import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/crypto/e2ee_key_store.dart';
import 'package:samay/crypto/e2ee_prekey_service.dart';
import 'package:samay/crypto/interfaces.dart';

/// Compile-time flag: when `true`, E2EE key/session material lives in
/// flutter_secure_storage ([SecureE2eeKeyStore]/[SecureE2eeSessionStore]).
/// Defaults to the in-memory stores until the secure-storage production
/// wiring lands (Android backup rules `allowBackup=false` + iOS keychain
/// entitlements — M-27/M-28 scope, E2EE-ARCHITECTURE.md §8.4); the memory
/// fallback is what tests and the current dev build use (documented).
const bool useSecureE2eeKeyStore = false;

/// Device-local E2EE key material (identity, SPKs, OPKs).
final e2eeKeyStoreProvider = Provider<E2eeKeyStore>((ref) {
  if (useSecureE2eeKeyStore) return SecureE2eeKeyStore();
  return MemoryE2eeKeyStore();
});

/// Per-chat session JSON persistence (§8.2/§8.3).
final e2eeSessionStoreProvider = Provider<E2eeSessionStore>((ref) {
  if (useSecureE2eeKeyStore) return SecureE2eeSessionStore();
  return MemoryE2eeSessionStore();
});

/// Prekey publishing + bundle fetch against Supabase (migration
/// 20260809000003 `e2ee_identity_keys` + `fetch_prekey_bundle` RPC).
final e2eePrekeyServiceProvider = Provider<E2eePrekeyService>((ref) {
  return SupabaseE2eePrekeyService(
    client: ref.watch(supabaseClientProvider),
    keyStore: ref.watch(e2eeKeyStoreProvider),
  );
});

/// The E2EE-wired [ChatService] used by the chat screen: encrypts on send,
/// decrypts on load and on realtime delivery (E2EE §12.2 step 3).
final chatE2eeServiceProvider = Provider<ChatService>((ref) {
  return ChatService(
    client: ref.watch(supabaseClientProvider),
    realtime: ref.watch(realtimeServiceProvider),
    e2eeKeyStore: ref.watch(e2eeKeyStoreProvider),
    e2eeSessionStore: ref.watch(e2eeSessionStoreProvider),
    e2eePrekeyService: ref.watch(e2eePrekeyServiceProvider),
  );
});

class ChatMessagesNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  @override
  Future<List<Map<String, dynamic>>> build(String chatId) async {
    return ref.read(chatE2eeServiceProvider).loadMessages(chatId);
  }

  /// Re-runs [build] (after sending, pull-to-refresh).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Sends a message and reloads the thread. [chatE2eeServiceProvider]
  /// encrypts before insert; the reload path decrypts.
  Future<void> send(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    await ref.read(chatE2eeServiceProvider).sendMessage(chatId, text, null);
    await refresh();
  }

  /// Appends a realtime-delivered row, deduplicated by `id` (dispose-safe
  /// subscription wiring lives in the chat screen).
  void addMessage(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String) return;
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncData([row]);
      return;
    }
    if (current.any((m) => m['id'] == id)) return;
    state = AsyncData([...current, row]);
  }
}

/// Messages of a chat (oldest first), decrypted; send + refresh.
final chatMessagesProvider = AsyncNotifierProvider.family<ChatMessagesNotifier,
    List<Map<String, dynamic>>, String>(ChatMessagesNotifier.new);
