import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';

/// Q4a — server-persisted notification categories.
///
/// The category contract lives on `users.notification_preferences` and is
/// read/written through `get_notification_preferences` /
/// `set_notification_preferences`. chat/events/friends/minigames default ON,
/// marketing defaults OFF, and security/moderation/legal are always delivered
/// (the server ignores attempts to disable them).
final notificationPrefsProvider =
    AsyncNotifierProvider<NotificationPrefsNotifier, Map<String, bool>>(
      NotificationPrefsNotifier.new,
    );

class NotificationPrefsNotifier extends AsyncNotifier<Map<String, bool>> {
  /// User-toggleable categories, in display order.
  static const toggleable = <String>[
    'chat',
    'events',
    'friends',
    'minigames',
    'marketing',
  ];

  /// Always-delivered categories (rendered as locked rows).
  static const locked = <String>['security', 'moderation', 'legal'];

  @override
  Future<Map<String, bool>> build() async {
    try {
      return await ref.read(notificationServiceProvider).getPreferences();
    } catch (e, st) {
      // A failed read must not blank the screen: fall back to the documented
      // defaults and log; the next refresh re-syncs.
      AppLogger.instance.warn(
        'Notification preferences could not be read ($e); using defaults.',
        '$st',
      );
      return {
        for (final key in toggleable) key: key != 'marketing',
        for (final key in locked) key: true,
      };
    }
  }

  /// Persists [value] for [key] server-side. The UI updates optimistically and
  /// is reconciled with the server response (locked categories stay true).
  Future<void> set(String key, bool value) async {
    final previous = state.valueOrNull ?? await build();
    state = AsyncData({...previous, key: value});
    try {
      final saved = await ref.read(notificationServiceProvider).setPreferences({
        ...previous,
        key: value,
      });
      state = AsyncData(saved);
    } catch (e, st) {
      AppLogger.instance.warn(
        'Notification preference "$key" could not be saved: $e',
        '$st',
      );
      state = AsyncData(previous);
      rethrow;
    }
  }
}
