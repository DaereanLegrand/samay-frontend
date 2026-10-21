import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/app_router.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/local_notifications_service.dart';
import 'package:samay/core/services/push_service.dart';
import 'package:samay/features/notifications/providers/notifications_providers.dart';

/// Root-lifetime push wiring for the authenticated shell (Track 2 `PUSH`).
///
/// Owns three things the platform-only `PushService` cannot:
///  - device-token sync: registers the FCM token once a session exists and on
///    every auth change (sign-in/restore); `AuthNotifier.signOut` unregisters.
///  - foreground messages: refreshes the notification list so the in-app
///    center follows a push without a pull-to-refresh.
///  - tap navigation: `onMessageOpenedApp` (background → foreground) and the
///    cold-start `getInitialMessage()` route through the same
///    [notificationDeepLink] contract as an in-app row tap.
///
/// Best-effort throughout: failures are logged, never thrown — the realtime
/// subscription and in-app center remain the fallback.
class PushNotificationListener extends ConsumerStatefulWidget {
  const PushNotificationListener({super.key});

  @override
  ConsumerState<PushNotificationListener> createState() =>
      _PushNotificationListenerState();
}

class _PushNotificationListenerState
    extends ConsumerState<PushNotificationListener> {
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _foreground?.cancel();
    _opened?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    // Register the token for the current session (the shell mounts only after
    // authentication, so a user exists).
    if (!mounted) return;
    await ref.read(pushServiceProvider).syncRegistration();

    // SEC-035 option C: background pushes render a generic LOCAL notification
    // (no server copy). Tapping it lands on the in-app notification center so
    // the authenticated session can load the real row.
    await LocalNotificationsService.instance.initialize(
      onDidReceiveNotificationResponse: (response) =>
          _openLocalPayload(response.payload),
    );

    try {
      final launchPayload = await LocalNotificationsService.instance
          .takeLaunchPayload();
      if (launchPayload != null) _openLocalPayload(launchPayload);
      _foreground =
          FirebaseMessaging.onMessage.listen((message) {
        AppLogger.instance.info('FCM foreground message: ${message.messageId}');
        ref.invalidate(notificationsProvider);
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(_onTap);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _onTap(initial);
    } catch (e, st) {
      AppLogger.instance.error('Push listener wiring failed: $e', '$st');
    }
  }

  /// Opens the in-app notification center for a generic local notification.
  /// The payload is a fixed route constant — never a server-provided path.
  void _openLocalPayload(String? payload) {
    if (!mounted || payload == null || payload.isEmpty) return;
    if (!isRegisteredRoutePath(payload)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(routerProvider).push(
        payload == LocalNotificationsService.notificationCenterPayload
            ? RoutePaths.mainNotifications
            : payload,
      );
    });
  }

  void _onTap(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final type = data['type'];
    if (type is! String || type.isEmpty) return;
    final link = notificationDeepLink(type, data);
    if (link == null || !isRegisteredRoutePath(link)) {
      AppLogger.instance.info('FCM tap with no route (type=$type)');
      return;
    }
    // Defer to the next frame so the router's redirect/auth guard has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(routerProvider).push(link);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Token sync can be needed again if the auth user changes within a shell
    // lifetime (account switch).
    ref.listen(authStateProvider, (_, _) {
      unawaited(ref.read(pushServiceProvider).syncRegistration());
    });
    return const SizedBox.shrink();
  }
}
