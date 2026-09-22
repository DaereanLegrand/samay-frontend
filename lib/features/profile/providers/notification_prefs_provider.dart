import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/storage_service.dart';

/// A single user-toggleable notification preference.
class NotificationPref {
  final String key;
  final bool defaultEnabled;

  const NotificationPref(this.key, {this.defaultEnabled = true});
}

/// Notification-preference store: the in-app notification prefs the
/// settings screen exposes. Persisted in the encrypted `config_cache` Hive
/// box; failures degrade to the
/// defaults and are logged — a preference must never block the screen.
final notificationPrefsProvider =
    AsyncNotifierProvider<NotificationPrefsNotifier, Map<String, bool>>(
      NotificationPrefsNotifier.new,
    );

class NotificationPrefsNotifier extends AsyncNotifier<Map<String, bool>> {
  /// The toggleable preferences, in display order. The push/remote side of
  /// each channel is a later step; these keys are the local user-facing
  /// contract.
  static const prefs = [
    NotificationPref('notifications.event_reminders'),
    NotificationPref('notifications.friend_requests'),
    NotificationPref('notifications.chat_messages'),
    NotificationPref('notifications.shards_rank'),
  ];

  HiveService get _hive => ref.read(hiveServiceProvider);

  @override
  Future<Map<String, bool>> build() async {
    try {
      final cached = _hive.getCachedConfig() ?? const {};
      return {
        for (final pref in prefs)
          pref.key: cached[pref.key] != 'false' && pref.defaultEnabled,
      };
    } catch (e, st) {
      // Uninitialized/re-created Hive: treat the
      // cache as a miss — every preference falls back to its default.
      AppLogger.instance.warn(
        'Notification prefs cache unreadable ($e); using defaults.',
        '$st',
      );
      return {for (final pref in prefs) pref.key: pref.defaultEnabled};
    }
  }

  /// Persists [value] for [key]. The UI updates optimistically; a
  /// persistence failure is logged, never surfaced.
  Future<void> set(String key, bool value) async {
    state = AsyncData({...state.valueOrNull ?? await build(), key: value});
    try {
      await _hive.cacheConfig({key: value.toString()});
    } catch (e, st) {
      AppLogger.instance.warn(
        'Notification pref "$key" persistence failed: $e',
        '$st',
      );
    }
  }
}
