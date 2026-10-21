import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/local_notifications_service.dart';
import 'package:samay/core/services/secure_session_storage.dart';
import 'package:samay/core/services/secure_storage_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The only notification copy a background push may render when no safe
/// content path exists (SEC-035, option C: push is a wake-up signal).
///
/// The body is resolved from the app's own ARB (`pushGenericBody`); the
/// server payload never contributes text.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // The Android background isolate does not inherit the main engine's
    // plugin registrations; register them before touching secure storage or
    // the local-notifications channel.
    DartPluginRegistrant.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    // Fail closed: a device without an authenticated session (signed out,
    // session revoked, storage unavailable) must not post anything.
    if (!await pushHasAuthenticatedSession()) {
      AppLogger.instance.info(
        'FCM background message ignored (no authenticated session): '
        '${message.messageId}',
      );
      return;
    }
    // Full content is deliberately NOT fetched here: the background isolate
    // has no router/decrypted store, and a server-supplied title/body must
    // never reach the lock screen. Render the generic local notification; the
    // in-app notification center loads the real row after auth.
    await LocalNotificationsService.instance.showGeneric();
    AppLogger.instance.info(
      'FCM background wake-up rendered generic notification: '
      '${message.messageId}',
    );
  } catch (e, st) {
    // Never crash the background isolate; the in-app realtime/list path is
    // the fallback.
    AppLogger.instance.warn('FCM background handler failed: $e', '$st');
  }
}

/// True when an authenticated Supabase session is persisted on this device.
///
/// Reads the session JSON written by [SecureSessionStorage] through the
/// SEC-033 options (`first_unlock_this_device` / EncryptedSharedPreferences),
/// which are precisely what makes the read legal from a background isolate.
/// Any failure (plugin missing, corrupt payload) fails closed.
@pragma('vm:entry-point')
Future<bool> pushHasAuthenticatedSession() async {
  try {
    final raw = await samaySecureStorage().read(
      key: SecureSessionStorage.persistSessionKey,
    );
    if (raw == null || raw.isEmpty) return false;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return false;
    final refreshToken = decoded['refresh_token'];
    return refreshToken is String && refreshToken.isNotEmpty;
  } catch (e, st) {
    AppLogger.instance.warn(
      'push auth probe failed; treating as signed out: $e',
      '$st',
    );
    return false;
  }
}

/// Backend seam for device-token registration (223_device_tokens).
///
/// Kept abstract so [PushService] is unit-testable without Supabase. The
/// production implementation is auth-aware: [register] returns **false** (and
/// makes no call) when there is no signed-in user, so the caller does NOT mark
/// the token as registered and retries once a session exists.
abstract class PushBackend {
  /// The signed-in user id, or null. Used to detect account switches.
  String? get currentUserId;

  /// Registers [token]; returns true only when the RPC actually ran.
  Future<bool> register({required String token, required String platform});
  Future<void> unregister(String token);
}

/// Supabase-backed [PushBackend] reading the RPCs from 223_device_tokens.
class SupabasePushBackend implements PushBackend {
  SupabasePushBackend(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<bool> register({
    required String token,
    required String platform,
  }) async {
    if (_client.auth.currentUser == null) return false;
    await _client.rpc('register_device_token', params: {
      'p_token': token,
      'p_platform': platform,
    });
    return true;
  }

  @override
  Future<void> unregister(String token) async {
    if (_client.auth.currentUser == null) return;
    await _client.rpc('unregister_device_token', params: {'p_token': token});
  }
}

/// One queued revocation: a token that could not be removed while its
/// session was still live (SEC-031).
class PendingTokenRevocation {
  const PendingTokenRevocation({required this.token, required this.uid});

  final String token;
  final String uid;

  Map<String, dynamic> toJson() => {'t': token, 'u': uid};

  static PendingTokenRevocation? fromJson(Object? value) {
    if (value is! Map) return null;
    final token = value['t'];
    final uid = value['u'];
    if (token is! String || token.isEmpty || uid is! String || uid.isEmpty) {
      return null;
    }
    return PendingTokenRevocation(token: token, uid: uid);
  }
}

/// Persistent, non-throwing storage for push bookkeeping:
///  - the user id the current token was registered for (account-switch
///    detection), and
///  - tokens whose unregister RPC failed while offline (retry queue).
///
/// Secrets never live here (a token is a device identifier, not a message);
/// it still uses the hardened secure storage so it is removed with the
/// session on app uninstall/keychain reset.
abstract class PushTokenStore {
  Future<String?> registeredUserId();
  Future<void> setRegisteredUserId(String uid);
  Future<void> clearRegisteredUserId();
  Future<List<PendingTokenRevocation>> pendingRevocations();
  Future<void> addPendingRevocation(PendingTokenRevocation revocation);
  Future<void> removePendingRevocation(String token);
}

class SecurePushTokenStore implements PushTokenStore {
  SecurePushTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? samaySecureStorage();

  static const registeredUidKey = 'samay.push.registered_uid';
  static const pendingRevocationsKey = 'samay.push.pending_revocations';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> registeredUserId() async {
    try {
      return await _storage.read(key: registeredUidKey);
    } catch (e, st) {
      AppLogger.instance.warn('push registered uid read failed: $e', '$st');
      return null;
    }
  }

  @override
  Future<void> setRegisteredUserId(String uid) async {
    try {
      await _storage.write(key: registeredUidKey, value: uid);
    } catch (e, st) {
      AppLogger.instance.warn('push registered uid write failed: $e', '$st');
    }
  }

  @override
  Future<void> clearRegisteredUserId() async {
    try {
      await _storage.delete(key: registeredUidKey);
    } catch (e, st) {
      AppLogger.instance.warn('push registered uid clear failed: $e', '$st');
    }
  }

  @override
  Future<List<PendingTokenRevocation>> pendingRevocations() async {
    try {
      final raw = await _storage.read(key: pendingRevocationsKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(PendingTokenRevocation.fromJson)
          .whereType<PendingTokenRevocation>()
          .toList();
    } catch (e, st) {
      AppLogger.instance.warn('push revocation queue read failed: $e', '$st');
      return const [];
    }
  }

  @override
  Future<void> addPendingRevocation(PendingTokenRevocation revocation) async {
    try {
      final queue = await pendingRevocations();
      if (queue.any((e) => e.token == revocation.token)) return;
      final updated = [...queue, revocation];
      await _storage.write(
        key: pendingRevocationsKey,
        value: jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    } catch (e, st) {
      AppLogger.instance.warn('push revocation queue write failed: $e', '$st');
    }
  }

  @override
  Future<void> removePendingRevocation(String token) async {
    try {
      final queue = await pendingRevocations();
      final updated = queue.where((e) => e.token != token).toList();
      if (updated.length == queue.length) return;
      if (updated.isEmpty) {
        await _storage.delete(key: pendingRevocationsKey);
        return;
      }
      await _storage.write(
        key: pendingRevocationsKey,
        value: jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    } catch (e, st) {
      AppLogger.instance.warn('push revocation queue clear failed: $e', '$st');
    }
  }
}

/// Push-notification seam (Track 2 `PUSH`, dark-first behind
/// `AppFeatureFlag.push`).
///
/// Best-effort init: a build without Firebase platform config
/// (`android/app/google-services.json` / iOS `GoogleService-Info.plist`) — or
/// without the google-services Gradle plugin — MUST still boot, so every
/// failure degrades to a logged no-op with [isEnabled] false. This mirrors the
/// Hive and crash-reporter fallbacks in `main.dart`.
///
/// Privacy model (audit SEC-035, option C): the server sends a data-only
/// wake-up, no content. The background isolate renders a generic local
/// notification only when an authenticated session exists; the in-app center
/// loads the real row after auth.
///
/// Token lifecycle (SEC-031): a failed unregister is queued and retried on the
/// next authenticated sync; logout always clears local token state and calls
/// `deleteToken`; an account switch rotates the FCM token so the previous
/// account's server row can never deliver to the new session.
class PushService {
  PushService({
    FirebaseMessaging? messaging,
    PushBackend? backend,
    PushTokenStore? tokenStore,
  }) : _messaging = messaging,
       _backend = backend,
       _tokenStore = tokenStore ?? SecurePushTokenStore();

  final FirebaseMessaging? _messaging;
  final PushBackend? _backend;
  final PushTokenStore _tokenStore;

  FirebaseMessaging? _messagingInstance;
  bool _enabled = false;
  String? _token;
  String? _registeredToken;

  /// True once Firebase initialised and FCM is usable.
  bool get isEnabled => _enabled;

  /// The current FCM registration token, if one was acquired.
  String? get token => _token;

  String get _platform {
    if (kIsWeb) return 'android';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  /// Initialises Firebase + FCM: registers the background handler, requests
  /// permission and fetches the token. Safe to call once, before `runApp`.
  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      await LocalNotificationsService.instance.initialize();
      final messaging = _messaging ?? FirebaseMessaging.instance;
      _messagingInstance = messaging;
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission();
      // iOS: keep the OS presentation flags for any future alert-bearing
      // message; this build only sends data-only wake-ups.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _token = await messaging.getToken();
      _enabled = true;
      AppLogger.instance.info(
        'PushService enabled (token ${_token != null ? 'acquired' : 'pending'})',
      );
      // Debug-only: surface the FCM token for Firebase console "Send test
      // message" and log rotations.
      if (kDebugMode && _token != null) {
        AppLogger.instance.info('FCM token (debug): $_token');
      }
      // Retry revocations queued while offline before registering this token.
      await _flushRevocations();
      await _registerCurrentToken();
      messaging.onTokenRefresh.listen((refreshed) {
        _token = refreshed;
        _registeredToken = null;
        if (kDebugMode) {
          AppLogger.instance.info('FCM token refreshed (debug): $refreshed');
        }
        unawaited(_registerCurrentToken());
      });
    } catch (e, st) {
      _enabled = false;
      AppLogger.instance.warn(
        'PushService disabled (Firebase config missing or invalid): $e',
        '$st',
      );
    }
  }

  /// Registers the current token if one exists and the user is signed in.
  /// Called on init, on token refresh, and by `PushNotificationListener` when
  /// the auth state settles. Idempotent: the RPC upserts on the token.
  Future<void> syncRegistration() async {
    final uid = _backend?.currentUserId;
    if (uid == null) return;
    try {
      // Logout deletes the FCM token; the next sign-in must acquire a fresh
      // one before registering (same process or a new account).
      _token ??= await _getToken();
      await _rotateForAccountSwitch(uid);
      await _flushRevocations();
      await _registerCurrentToken();
    } catch (e, st) {
      // Best-effort: the next auth/token event retries.
      AppLogger.instance.warn('PushService sync failed: $e', '$st');
    }
  }

  /// SEC-031: the token registered server-side is bound to one user. When a
  /// different account signs in on the same install, the old token must not
  /// stay live: drop it server-side (best effort), rotate the local FCM token
  /// and let the caller register the new one.
  Future<void> _rotateForAccountSwitch(String uid) async {
    final registeredUid = await _tokenStore.registeredUserId();
    if (registeredUid == null || registeredUid == uid) return;
    AppLogger.instance.warn(
      'push token account switch $registeredUid → $uid — rotating token',
    );
    final previousToken = _token;
    final backend = _backend;
    if (previousToken != null && backend != null) {
      try {
        await backend.unregister(previousToken);
      } catch (e, st) {
        // Cannot revoke another account's row through this RPC; the local
        // token is deleted below so it can no longer receive anything.
        AppLogger.instance.warn(
          'push rotation unregister failed (best effort): $e',
          '$st',
        );
      }
    }
    await _deleteToken();
    _token = await _getToken();
    _registeredToken = null;
    await _tokenStore.clearRegisteredUserId();
  }

  Future<void> _registerCurrentToken() async {
    final token = _token;
    final backend = _backend;
    if (token == null || backend == null) return;
    final uid = backend.currentUserId;
    // No session yet -> the backend would make no call; do NOT mark the token
    // as registered, so the next sync (auth change / shell mount / refresh)
    // retries.
    if (uid == null) return;
    if (token == _registeredToken &&
        (await _tokenStore.registeredUserId()) == uid) {
      return;
    }
    try {
      final registered = await backend.register(token: token, platform: _platform);
      if (!registered) return;
      _registeredToken = token;
      await _tokenStore.setRegisteredUserId(uid);
      AppLogger.instance.info('PushService device token registered');
    } catch (e, st) {
      // Best-effort: the next refresh/auth event retries. Logged, never silent.
      AppLogger.instance.warn('PushService token registration failed: $e', '$st');
    }
  }

  /// Retries queued revocations for the CURRENT user. Entries belonging to a
  /// previous account are left queued (the RPC can only delete the caller's
  /// rows); they are harmless because the token was rotated/deleted locally.
  Future<void> _flushRevocations() async {
    final backend = _backend;
    final uid = backend?.currentUserId;
    if (backend == null || uid == null) return;
    final queue = await _tokenStore.pendingRevocations();
    for (final entry in queue) {
      if (entry.uid != uid) continue;
      try {
        await backend.unregister(entry.token);
        await _tokenStore.removePendingRevocation(entry.token);
      } catch (e, st) {
        AppLogger.instance.warn(
          'queued push token revocation failed (kept for retry): $e',
          '$st',
        );
      }
    }
  }

  /// Unregisters the current device and invalidates the FCM token on sign-out.
  ///
  /// SEC-031: never throws; ALWAYS clears local token state and calls
  /// `deleteToken`, even when the RPC fails. A failed RPC is queued for a
  /// later authenticated retry.
  Future<void> unregister() async {
    try {
      final token = _token;
      final backend = _backend;
      final uid = backend?.currentUserId;
      _token = null;
      _registeredToken = null;
      if (token != null && backend != null) {
        try {
          await backend.unregister(token);
        } catch (e, st) {
          AppLogger.instance.warn(
            'PushService token unregister failed; queued for retry: $e',
            '$st',
          );
          if (uid != null) {
            await _tokenStore.addPendingRevocation(
              PendingTokenRevocation(token: token, uid: uid),
            );
          }
        }
      }
      await _tokenStore.clearRegisteredUserId();
    } catch (e, st) {
      AppLogger.instance.warn('PushService unregister failed: $e', '$st');
    } finally {
      await _deleteToken();
    }
  }

  Future<void> _deleteToken() async {
    try {
      await (_messagingInstance ?? _messaging)?.deleteToken();
    } catch (e, st) {
      AppLogger.instance.warn('FCM deleteToken failed: $e', '$st');
    }
  }

  Future<String?> _getToken() async {
    try {
      return await (_messagingInstance ?? _messaging)?.getToken();
    } catch (e, st) {
      AppLogger.instance.warn('FCM getToken after rotation failed: $e', '$st');
      return null;
    }
  }
}

/// The app-wide push service.
final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(
    backend: SupabasePushBackend(ref.watch(supabaseClientProvider)),
  );
});
