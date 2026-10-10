import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level FCM background handler.
///
/// Must be a top-level function annotated with the `vm:entry-point` pragma so
/// the background isolate can invoke it. The OS renders the notification
/// itself; this stays side-effect free (no UI, no auth-dependent work) and
/// only logs for diagnostics.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.instance.info('FCM background message: ${message.messageId}');
}

/// Backend seam for device-token registration (223_device_tokens).
///
/// Kept abstract so [PushService] is unit-testable without Supabase. The
/// production implementation is auth-aware: [register] returns **false** (and
/// makes no call) when there is no signed-in user, so the caller does NOT mark
/// the token as registered and retries once a session exists.
abstract class PushBackend {
  /// Registers [token]; returns true only when the RPC actually ran.
  Future<bool> register({required String token, required String platform});
  Future<void> unregister(String token);
}

/// Supabase-backed [PushBackend] reading the RPCs from 223_device_tokens.
class SupabasePushBackend implements PushBackend {
  SupabasePushBackend(this._client);

  final SupabaseClient _client;

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

/// Push-notification seam (Track 2 `PUSH`, dark-first behind
/// `AppFeatureFlag.push`).
///
/// Best-effort init: a build without Firebase platform config
/// (`android/app/google-services.json` / iOS `GoogleService-Info.plist`) — or
/// without the google-services Gradle plugin — MUST still boot, so every
/// failure degrades to a logged no-op with [isEnabled] false. This mirrors the
/// Hive and crash-reporter fallbacks in `main.dart`.
///
/// Once a token is acquired it is registered server-side (upsert on the token)
/// so the Go push worker can dispatch. Registration is retried on every token
/// refresh and on demand via [syncRegistration] (wired to auth state by
/// `PushNotificationListener`); [unregister] runs on sign-out.
class PushService {
  PushService({FirebaseMessaging? messaging, PushBackend? backend})
      : _messaging = messaging,
        _backend = backend;

  final FirebaseMessaging? _messaging;
  final PushBackend? _backend;

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
      final messaging = _messaging ?? FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission();
      // iOS: present the banner/badge/sound even while the app is foreground.
      // Android foreground delivery is handled by PushNotificationListener
      // (real-time refresh); background delivery is rendered by the OS.
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
      await _registerCurrentToken();
      messaging.onTokenRefresh.listen((refreshed) {
        _token = refreshed;
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
  Future<void> syncRegistration() => _registerCurrentToken();

  Future<void> _registerCurrentToken() async {
    final token = _token;
    final backend = _backend;
    if (token == null || backend == null || token == _registeredToken) return;
    try {
      final registered = await backend.register(token: token, platform: _platform);
      // No session yet -> the backend made no call; do NOT mark the token as
      // registered, so the next sync (auth change / shell mount / refresh)
      // retries. This is what previously masked the failure as "registered".
      if (!registered) return;
      _registeredToken = token;
      AppLogger.instance.info('PushService device token registered');
    } catch (e, st) {
      // Best-effort: the next refresh/auth event retries. Logged, never silent.
      AppLogger.instance.warn('PushService token registration failed: $e', '$st');
    }
  }

  /// Unregisters the current device and invalidates the FCM token on sign-out.
  /// Best-effort: a failure must never block the auth transition.
  Future<void> unregister() async {
    final token = _token;
    final backend = _backend;
    if (token == null || backend == null) return;
    try {
      await backend.unregister(token);
      _registeredToken = null;
      await _messaging?.deleteToken();
    } catch (e, st) {
      AppLogger.instance.warn('PushService token unregister failed: $e', '$st');
    }
  }
}

/// The app-wide push service.
final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(
    backend: SupabasePushBackend(ref.watch(supabaseClientProvider)),
  );
});
