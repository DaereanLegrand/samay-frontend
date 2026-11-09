import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/models/notification_item.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/features/notifications/providers/notifications_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:samay/core/theme/app_palette_context.dart';

/// Icon per notification type (NOTI spec table, 16 rows). The title/body
/// text ships in the row itself (inserted by the push pipeline with the spec
/// copy); unknown types fall back to the bell.
IconData notificationIconForType(String type) {
  return switch (type) {
    'event_invite' => Icons.event,
    'friend_request' => Icons.person_add,
    // Server emits `event_live`; the spec/seeds used `event_starting`.
    'event_starting' || 'event_live' => Icons.notifications_active,
    'qr_active' => Icons.qr_code,
    'attendance_confirmed' => Icons.check_circle,
    'shard_received' => Icons.diamond,
    // Server emits `rank_bracket`; the spec used `rank_update`.
    'rank_update' || 'rank_bracket' => Icons.leaderboard,
    // Server emits `new_message`; the spec/seeds used `chat_message`.
    'chat_message' || 'new_message' => Icons.chat_bubble,
    'minigame_invite' => Icons.sports_esports,
    // Generic "it's your turn" across every minigame (truth_dare,
    // drunk_bottle, two_lies_one_truth, charades).
    'minigame_turn' => Icons.sports_esports,
    'poke_received' => Icons.bolt,
    'invite_approval' => Icons.event_available,
    // Server emits a single `feature_request` carrying data.status; the spec
    // split it into approved/rejected.
    'feature_request' || 'feature_approved' => Icons.star,
    'feature_rejected' => Icons.star_border,
    'report_warned' => Icons.warning_amber,
    'content_removed' => Icons.delete,
    'event_cancelled' => Icons.event_busy,
    _ => Icons.notifications,
  };
}

/// In-app notification center: newest-first list from the `notifications`
/// table, grouped by day with hairline rows, live inserts via Realtime,
/// tap → deep link + mark read, unread dot, pull-to-refresh, mark-all-read,
/// empty state.
///
/// Monochrome: unread rows emphasize with white (icon + dot + bold title) —
/// unread state is never color-only.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  /// Live inserts append to the list (dispose-safe: the channel is
  /// unsubscribed on dispose). Subscription failures are best-effort — the
  /// history list still loads and pull-to-refresh still works — but they are
  /// always logged, never silent.
  Future<void> _subscribeRealtime() async {
    try {
      final channel = await ref
          .read(notificationServiceProvider)
          .subscribeToNotifications((row) {
            if (!mounted) return;
            ref.read(notificationsProvider.notifier).addNotification(row);
          });
      if (!mounted) return;
      _channel = channel;
    } catch (e, st) {
      // Realtime is best-effort by design; the pull-to-refresh path remains.
      AppLogger.instance.error(
        'notifications realtime subscribe failed: $e',
        '$st',
      );
    }
  }

  /// NOTI spec tap contract: mark the notification read, and navigate to the
  /// deep link when the route exists. The push is fire-and-forget — awaiting
  /// it would only continue after the pushed route pops.
  Future<void> _onTap(NotificationItem item) async {
    await ref.read(notificationsProvider.notifier).markRead(item.id);
    if (!mounted) return;
    final link = notificationDeepLink(item.type, item.data);
    if (link != null && isRegisteredRoutePath(link)) {
      unawaited(context.push(link));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      // Always-transparent pinned header (shared mechanism); notifications
      // scroll beneath it.
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            VHeaderSliver(
              title: l10n.notificationsTitle,
              actions: [
                if (unread > 0)
                  TextButton(
                    onPressed: () =>
                        ref.read(notificationsProvider.notifier).markAllRead(),
                    child: Text(l10n.notificationsMarkAllRead),
                  ),
              ],
            ),
            ..._contentSlivers(context, ref, l10n, notifications),
            // Clear the floating shell nav bar so the last row can scroll
            // above it (nav-bar height + 16).
            SliverToBoxAdapter(
              child: SizedBox(height: MainShell.navBarInset(context)),
            ),
          ],
        ),
      ),
    );
  }

  /// The scroll body under the transparent pinned header, as slivers.
  List<Widget> _contentSlivers(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<NotificationItem>> notifications,
  ) {
    final refreshing = notifications.isLoading && notifications.hasValue;
    if (notifications.isLoading && !refreshing) {
      // First load shows the shared spinner; pull-to-refresh keeps the list
      // visible.
      return const [
        SliverFillRemaining(hasScrollBody: false, child: VLoadingView()),
      ];
    }
    final error = notifications.hasError ? notifications.error : null;
    if (error != null) {
      return [
        SliverToBoxAdapter(
          child: ErrorView(
            message: l10n.notificationsLoadError,
            onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
          ),
        ),
      ];
    }
    final items = notifications.valueOrNull ?? const <NotificationItem>[];
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: VEmptyView(
            icon: Icons.notifications_none,
            title: l10n.notificationsEmpty,
            description: l10n.notificationsEmptyBody,
          ),
        ),
      ];
    }
    // Day-grouped entries: a section label before the first item of each day,
    // hairline-separated rows within it.
    final entries = <Object>[];
    DateTime? lastDay;
    for (final item in items) {
      final created = item.createdAt.toLocal();
      final day = DateTime(created.year, created.month, created.day);
      if (day != lastDay) {
        entries.add(_DayLabel(day));
        lastDay = day;
      }
      entries.add(item);
    }
    return [
      SliverList.separated(
        itemCount: entries.length,
        separatorBuilder: (_, index) {
          final a = entries[index];
          final b = entries[index + 1];
          if (a is _DayLabel || b is _DayLabel) {
            return const SizedBox(height: AppSpacing.xs);
          }
          return Divider(height: 1, color: context.palette.hairline);
        },
        itemBuilder: (context, index) {
          final entry = entries[index];
          if (entry is _DayLabel) {
            return _SectionLabel(day: entry.day);
          }
          final item = entry as NotificationItem;
          return _NotificationTile(item: item, onTap: () => _onTap(item));
        },
      ),
    ];
  }
}

/// One day's grouping key for the notification list.
class _DayLabel {
  const _DayLabel(this.day);

  final DateTime day;
}

/// The day grouping label above its rows (TODAY / YESTERDAY / dd/MM/yyyy).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? l10n.commonToday
        : day == today.subtract(const Duration(days: 1))
        ? l10n.commonYesterday
        : '${day.day.toString().padLeft(2, '0')}/'
              '${day.month.toString().padLeft(2, '0')}/${day.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
      ),
      child: Text(label.toUpperCase(), style: AppTypography.sectionLabel),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = !item.read;
    final span = notificationTimeSpan(item.createdAt, DateTime.now());
    final time = switch (span.age) {
      NotificationAge.now => l10n.notificationsTimeNow,
      NotificationAge.minutes => l10n.notificationsTimeMinutes(span.value),
      NotificationAge.hours => l10n.notificationsTimeHours(span.value),
      NotificationAge.days => l10n.notificationsTimeDays(span.value),
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.listRowVertical,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              notificationIconForType(item.type),
              size: AppIconSizes.md,
              color: unread ? context.palette.foreground : context.palette.mutedForeground,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        time,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.palette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                key: ValueKey('unread-dot-${item.id}'),
                width: 8,
                height: 8,
                // Monochrome: flat white dot (the bold title + dot pair
                // carries the unread state, never color alone).
                decoration: BoxDecoration(
                  color: context.palette.foreground,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
