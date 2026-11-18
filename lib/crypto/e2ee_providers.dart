import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/crypto/e2ee_key_store.dart';
import 'package:samay/crypto/e2ee_prekey_service.dart';
import 'package:samay/crypto/interfaces.dart';

/// Compile-time switch for E2EE key/session storage:
/// `true` → flutter_secure_storage ([SecureE2eeKeyStore]/[SecureE2eeSessionStore],
/// iOS Keychain / Android Keystore, §8.2 namespaces, platform backup and
/// entitlement hardening).
/// `false` → in-memory stores (the two-party harness only).
///
/// With the secure stores, identity/prekey/ratchet material survives
/// app restarts at rest, protected by the platform keystore (E2EE §8).
///
/// Slim build note: chat is out of scope for this version, but multi-device
/// MINIGAME answers keep using the round-key layer, so this key material and
/// its stores stay.
const bool useSecureE2eeKeyStore = true;

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

/// Prekey publishing + bundle fetch against Supabase
/// (`e2ee_identity_keys` + `fetch_prekey_bundle` RPC).
final e2eePrekeyServiceProvider = Provider<E2eePrekeyService>((ref) {
  return SupabaseE2eePrekeyService(
    client: ref.watch(supabaseClientProvider),
    keyStore: ref.watch(e2eeKeyStoreProvider),
  );
});
