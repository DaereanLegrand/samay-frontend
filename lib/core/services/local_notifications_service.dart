import 'dart:ui' show PlatformDispatcher, Locale;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';

/// Signal/WhatsApp-style local notifications (audit SEC-035 option C).
///
/// The server push payload is a wake-up signal with no content: the client
/// renders a generic local notification from the background isolate and the
/// in-app notification center loads the real title/body after auth. Nothing
/// in this file accepts server-provided copy, so a lock screen can never leak
/// a message, sender, location, wager or answer.
///
/// Singleton seam so the foreground listener and the FCM background handler
/// share one plugin instance/initialization.
class LocalNotificationsService {
  LocalNotificationsService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The one instance used by the app and the background isolate.
  static final LocalNotificationsService instance = LocalNotificationsService();

  /// Payload attached to every generic notification: the in-app notification
  /// center. No per-entity ids travel through the notification.
  static const String notificationCenterPayload = RoutePaths.mainNotifications;

  static const String _channelId = 'samay_activity';
  static const String _channelName = 'Actividad de Samay';
  static const String _channelDescription =
      'Avisos genéricos de actividad. El contenido se carga dentro de la app.';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  DidReceiveNotificationResponseCallback? _onResponse;

  bool get isInitialized => _initialized;

  /// Initializes the plugin and attaches the tap callback.
  ///
  /// Re-invoking is safe (and required: the foreground listener attaches the
  /// callback after the background isolate may already have initialized the
  /// plugin). Intentional no-op on failure (a device without notification
  /// support must still boot).
  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    if (onDidReceiveNotificationResponse != null) {
      _onResponse = onDidReceiveNotificationResponse;
    }
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested by Firebase Messaging; asking again here
        // would double-prompt. The app presents local notifications with the
        // OS defaults once FCM has been granted.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        // Preserve the foreground tap handler when a background show
        // re-initializes the plugin in the main isolate (iOS).
        onDidReceiveNotificationResponse: _onResponse,
      );
      _initialized = true;
    } catch (e, st) {
      AppLogger.instance.warn(
        'LocalNotificationsService init failed: $e',
        '$st',
      );
    }
  }

  /// Creates the Android channel (idempotent) and posts the one generic
  /// notification used for every background event.
  Future<void> showGeneric({String? body}) async {
    await initialize();
    if (!_initialized) return;
    final l10n = _localizations();
    final resolvedBody = body ?? l10n.pushGenericBody;
    try {
      final details = const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // Generic copy only: the payload is the notification-center route.
          autoCancel: true,
          onlyAlertOnce: false,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(
        id: 0,
        title: l10n.pushGenericTitle,
        body: resolvedBody,
        notificationDetails: details,
        payload: notificationCenterPayload,
      );
    } catch (e, st) {
      AppLogger.instance.warn(
        'LocalNotificationsService show failed: $e',
        '$st',
      );
    }
  }

  /// Payload of the notification that cold-started the app, if any. Consumed
  /// once by `PushNotificationListener` after auth/router are ready.
  Future<String?> takeLaunchPayload() async {
    await initialize();
    if (!_initialized) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (e, st) {
      AppLogger.instance.warn(
        'LocalNotificationsService launch payload failed: $e',
        '$st',
      );
      return null;
    }
  }

  /// Removes every posted generic notification (logout/local-data purge).
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e, st) {
      AppLogger.instance.warn(
        'LocalNotificationsService cancelAll failed: $e',
        '$st',
      );
    }
  }

  /// Resolves the generic copy without a BuildContext (the background
  /// isolate has none). Falls back to Spanish, the app's primary locale.
  AppLocalizations _localizations() {
    final locale = PlatformDispatcher.instance.locale;
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == locale.languageCode) {
        return lookupAppLocalizations(supported);
      }
    }
    return lookupAppLocalizations(const Locale('es'));
  }
}
