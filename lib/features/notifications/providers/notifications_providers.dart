import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/notification_item.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/notification_service.dart';

/// Coarse relative-time bucket for a notification timestamp (NOTI spec
/// "timestamp" row). Pure logic so the label mapping is unit-testable; the
/// UI layer resolves each bucket to an l10n key.
enum NotificationAge { now, minutes, hours, days }

/// A bucket + rounded value for [notificationTimeSpan].
class NotificationTimeSpan {
  final NotificationAge age;
  final int value;

  const NotificationTimeSpan(this.age, this.value);
}

/// Coarse "hace X min/h/d" span for a creation time vs the current clock.
/// Future timestamps (device-clock skew) clamp to `now`.
NotificationTimeSpan notificationTimeSpan(DateTime createdAt, DateTime now) {
  final diff = now.difference(createdAt);
  if (diff.inMinutes < 1) {
    return const NotificationTimeSpan(NotificationAge.now, 0);
  }
  if (diff.inMinutes < 60) {
    return NotificationTimeSpan(NotificationAge.minutes, diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return NotificationTimeSpan(NotificationAge.hours, diff.inHours);
  }
  return NotificationTimeSpan(NotificationAge.days, diff.inDays);
}

/// Resolves the navigation target for a notification (NOTI spec "Notification
/// Types & Deep Links"): an explicit `deepLink` in `data` (the I-66 payload
/// convention) wins; otherwise the target is derived from the type + id
/// fields. Returns null when the row carries no navigable target.
String? notificationDeepLink(String type, Map<String, dynamic>? data) {
  if (data == null) return null;
  final explicit = data['deepLink'];
  if (explicit is String && explicit.isNotEmpty) return explicit;

  final eventId = _firstId(data, const ['event_id', 'eventId']);
  final groupId = _firstId(data, const ['group_id', 'groupId']);
  final chatId = _firstId(data, const ['chat_id', 'chatId']);
  final userId = _firstId(data, const ['user_id', 'userId']);
  final sessionId = _firstId(data, const ['session_id', 'sessionId']);

  switch (type) {
    case 'qr_active':
      return eventId == null ? null : RoutePaths.qr(eventId);
    case 'friend_request':
      // Spec deep link is `/user/{userId}/friend` — a route that does not
      // exist yet, so it resolves to the registered public profile instead.
      return userId == null ? null : RoutePaths.userProfile(userId);
    case 'minigame_invite':
      // 140_minigame_invites: the invite notification carries the session,
      // so it lands on the session detail (accept/decline) — not the group.
      if (sessionId != null) return RoutePaths.minigameSession(sessionId);
      return groupId == null ? null : RoutePaths.groupDetail(groupId);
    case 'rank_update':
    case 'poke_received':
      return groupId == null ? null : RoutePaths.groupDetail(groupId);
    case 'chat_message':
      return chatId == null ? null : RoutePaths.chat(chatId);
    default:
      if (eventId != null) return RoutePaths.eventDetail(eventId);
      if (groupId != null) return RoutePaths.groupDetail(groupId);
      if (chatId != null) return RoutePaths.chat(chatId);
      if (userId != null) return RoutePaths.userProfile(userId);
      return null;
  }
}

/// True when [path] resolves to a registered GoRouter route (the deep-link
/// guard: a notification may only navigate where a route exists — otherwise
/// the tap just marks the notification read, NOTI spec). Segment-exact: a
/// path with trailing segments beyond a known route shape (e.g. the spec's
/// `/user/{userId}/friend`, which has no route yet) is rejected.
bool isRegisteredRoutePath(String path) {
  final normalized = path.split('?').first;
  const exact = {
    RoutePaths.mainFeed,
    RoutePaths.mainGroups,
    RoutePaths.mainGames,
    RoutePaths.mainEvents,
    RoutePaths.mainNotifications,
    RoutePaths.mainProfile,
    RoutePaths.groupCreate,
    RoutePaths.rankings,
    RoutePaths.userSearch,
    RoutePaths.friendsRequests,
    RoutePaths.friendsList,
    RoutePaths.blockedUsers,
    RoutePaths.subscriptions,
    RoutePaths.settings,
    RoutePaths.deleteAccount,
    RoutePaths.profileEdit,
  };
  if (exact.contains(normalized)) return true;

  final segments = normalized.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.length == 2 && segments[0] == 'event') return true;
  if (segments.length == 3 && segments[0] == 'event') {
    return const {'edit', 'invite', 'photos', 'collage'}.contains(segments[2]);
  }
  if (segments.length == 2 && segments[0] == 'group') return true;
  if (segments.length == 3 && segments[0] == 'group') {
    return const {
      'members',
      'donate',
      'create-event',
      'invite',
    }.contains(segments[2]);
  }
  if (segments.length == 3 &&
      segments[0] == 'minigames' &&
      segments[1] == 'session') {
    return true;
  }
  if (segments.length == 4 &&
      segments[0] == 'minigames' &&
      segments[1] == 'play' &&
      segments[2] == 'truth-dare') {
    return true;
  }
  if (segments.length == 2 && segments[0] == 'chat') return true;
  if (segments.length == 2 && segments[0] == 'user') return true;
  if (segments.length == 2 && segments[0] == 'qr') return true;
  if (segments.length == 2 && segments[0] == 'scanner') return true;
  return false;
}

String? _firstId(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

class NotificationsNotifier extends AsyncNotifier<List<NotificationItem>> {
  NotificationService get _service => ref.read(notificationServiceProvider);

  @override
  Future<List<NotificationItem>> build() async {
    final rows = await _service.getNotifications();
    return rows.map(NotificationItem.fromJson).toList();
  }

  /// Re-runs [build] (pull-to-refresh, finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Marks one notification read on the server, then locally (the unread dot
  /// disappears without a full reload).
  Future<void> markRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.any((n) => n.id == id && !n.read)) return;
    await _service.markNotificationRead(id);
    state = AsyncData([
      for (final n in current) n.id == id ? n.copyWith(read: true) : n,
    ]);
  }

  /// Marks every unread notification read (NOTI spec "mark all read").
  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final unread = current.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    for (final n in unread) {
      await _service.markNotificationRead(n.id);
    }
    state = AsyncData([for (final n in current) n.copyWith(read: true)]);
  }

  /// Appends a realtime-delivered row (deduplicated by id, prepended so the
  /// newest-first ordering holds). Dispose-safe subscription wiring lives in
  /// the notification center screen (chat pattern).
  void addNotification(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String) return;
    final current = state.valueOrNull;
    final item = NotificationItem.fromJson(row);
    if (current == null) {
      state = AsyncData([item]);
      return;
    }
    if (current.any((n) => n.id == id)) return;
    state = AsyncData([item, ...current]);
  }
}

/// Notifications for the current user, newest first.
final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier,
    List<NotificationItem>>(NotificationsNotifier.new);

/// Number of unread notifications — derived so widgets watching only the
/// count rebuild on read-state changes (finding SM-13/L-05 select pattern).
final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull;
  if (notifications == null) return 0;
  return notifications.where((n) => !n.read).length;
});
