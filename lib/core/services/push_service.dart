import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';

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

/// Push-notification seam (Track 2 `PUSH`, dark-first behind
/// `AppFeatureFlag.push`).
///
/// Best-effort init: a build without Firebase platform config
/// (`android/app/google-services.json` / iOS `GoogleService-Info.plist`) — or
/// without the google-services Gradle plugin — MUST still boot, so every
/// failure degrades to a logged no-op with [isEnabled] false. This mirrors the
/// Hive and crash-reporter fallbacks in `main.dart`.
///
/// The token is exposed for the (future) device-token registration; no network
/// call is made here.
class PushService {
  PushService({FirebaseMessaging? messaging}) : _messaging = messaging;

  final FirebaseMessaging? _messaging;

  bool _enabled = false;
  String? _token;

  /// True once Firebase initialised and FCM is usable.
  bool get isEnabled => _enabled;

  /// The current FCM registration token, if one was acquired.
  String? get token => _token;

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
      _token = await messaging.getToken();
      _enabled = true;
      AppLogger.instance.info(
        'PushService enabled (token ${_token != null ? 'acquired' : 'pending'})',
      );
    } catch (e, st) {
      _enabled = false;
      AppLogger.instance.warn(
        'PushService disabled (Firebase config missing or invalid): $e',
        '$st',
      );
    }
  }
}

/// The app-wide push service.
final pushServiceProvider = Provider<PushService>((ref) => PushService());
