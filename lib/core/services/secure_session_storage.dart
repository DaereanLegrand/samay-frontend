import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/secure_storage_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Supabase session persistence backed by `flutter_secure_storage`
///
/// Wired into `Supabase.initialize` as `authOptions.localStorage`
/// (see `lib/main.dart`), replacing the SDK's default in-memory/shared-preferences
/// persistence: the session JSON (access JWT + refresh token) now lives in the
/// iOS Keychain / Android Keystore instead of plain-text app storage, and
/// survives app restarts (MASTG-BEST-0004 — sensitive
/// data in platform keychain, never on disk beside app data).
///
/// The session string is stored under [persistSessionKey] (`samay.auth.session`).
/// The contract mirrors `SharedPreferencesLocalStorage` (supabase_flutter
/// 2.12.4 source): [initialize] runs before any other method, then
/// [hasAccessToken]/[accessToken] restore a persisted session at cold start,
/// [persistSession] runs on every `SIGNED_IN`/`TOKEN_REFRESHED` event and
/// [removePersistedSession] on `SIGNED_OUT`.
///
/// ## Graceful degradation (never crash)
///
/// `flutter_secure_storage` is a platform plugin (MethodChannel). If it throws
/// — missing plugin, broken channel, keychain-unavailable platform — every
/// method falls back to an in-memory map for the rest of the app session and
/// logs a warning. The user stays signed in for the current run; only
/// *persistence across restarts* is lost. The fallback is one-way: once the
/// plugin has failed, all further operations stay in memory so behavior is
/// deterministic (no read-again-maybe-throws flip-flopping).
class SecureSessionStorage extends LocalStorage {
  /// Creates a storage backed by [secureStorage]; tests inject a fake, the
  /// app uses the real plugin.
  SecureSessionStorage({FlutterSecureStorage? secureStorage})
      : _store = _FallbackAwareStore(secureStorage ?? samaySecureStorage());

  /// Secure-storage key under which the session JSON is persisted.
  static const persistSessionKey = 'samay.auth.session';

  final _FallbackAwareStore _store;

  @override
  Future<void> initialize() async {
    // Probe the platform channel once so any plugin failure surfaces here,
    // before Supabase asks for the session.
    await _store.read(persistSessionKey);
  }

  @override
  Future<bool> hasAccessToken() async => await _store.read(persistSessionKey) != null;

  @override
  Future<String?> accessToken() => _store.read(persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(persistSessionKey, persistSessionString);

  @override
  Future<void> removePersistedSession() => _store.delete(persistSessionKey);
}

/// PKCE code-verifier storage backed by `flutter_secure_storage`
///
/// GoTrue stores its PKCE code verifier through this interface whenever a
/// `signInWithOtp`/`signUp`/magic-link flow runs (`GotrueAsyncStorage`,
/// key `sb-<project-ref>-auth-token-code-verifier` — see gotrue 2.20.0
/// `gotrue_client.dart`). Keys are namespaced under `samay.auth.` so every
/// auth-related secret lives in one keychain prefix.
///
/// Same graceful degradation as [SecureSessionStorage]: a throwing plugin
/// downgrades to in-memory storage for the app session, never crashes.
class SecurePkceStorage extends GotrueAsyncStorage {
  /// Creates a storage backed by [secureStorage]; tests inject a fake.
  SecurePkceStorage({FlutterSecureStorage? secureStorage})
      : _store = _FallbackAwareStore(secureStorage ?? samaySecureStorage());

  static const _keyPrefix = 'samay.auth.';

  final _FallbackAwareStore _store;

  String _prefixed(String key) => '$_keyPrefix$key';

  @override
  Future<String?> getItem({required String key}) => _store.read(_prefixed(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
      _store.write(_prefixed(key), value);

  @override
  Future<void> removeItem({required String key}) => _store.delete(_prefixed(key));
}

/// One-way-degrading facade over [FlutterSecureStorage]: every operation
/// tries the plugin first; on the first failure all subsequent operations
/// serve from an in-memory map (see the class docs of the two public
/// storages for the trade-off).
class _FallbackAwareStore {
  _FallbackAwareStore(this._storage);

  final FlutterSecureStorage _storage;
  final Map<String, String> _memory = {};
  bool _usingFallback = false;

  Future<String?> read(String key) async {
    if (_usingFallback) return _memory[key];
    try {
      return await _storage.read(key: key);
    } catch (e, st) {
      _enterFallback(e, st);
      return _memory[key];
    }
  }

  Future<void> write(String key, String value) async {
    if (_usingFallback) {
      _memory[key] = value;
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (e, st) {
      _enterFallback(e, st);
      _memory[key] = value;
    }
  }

  Future<void> delete(String key) async {
    if (_usingFallback) {
      _memory.remove(key);
      return;
    }
    try {
      await _storage.delete(key: key);
    } catch (e, st) {
      _enterFallback(e, st);
      _memory.remove(key);
    }
  }

  void _enterFallback(Object error, StackTrace stackTrace) {
    if (_usingFallback) return;
    _usingFallback = true;
    AppLogger.instance.warn(
      'flutter_secure_storage unavailable ($error); falling back to '
      'in-memory session storage. Sessions will not survive app restart.',
      stackTrace.toString(),
    );
  }
}
