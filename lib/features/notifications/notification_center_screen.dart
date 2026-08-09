import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/models/notification_item.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/features/notifications/notifications_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Icon per notification type (NOTI spec table, 16 rows). The title/body
/// text ships in the row itself (inserted by the push pipeline with the spec
/// copy); unknown types fall back to the bell.
IconData notificationIconForType(String type) {
  return switch (type) {
    'event_invite' => Icons.event,
    'friend_request' => Icons.person_add,
    'event_starting' => Icons.notifications_active,
    'qr_active' => Icons.qr_code,
    'attendance_confirmed' => Icons.check_circle,
    'shard_received' => Icons.diamond,
    'rank_update' => Icons.leaderboard,
    'chat_message' => Icons.chat_bubble,
    'minigame_invite' => Icons.sports_esports,
    'poke_received' => Icons.bolt,
    'invite_approval' => Icons.event_available,
    'feature_approved' => Icons.star,
    'feature_rejected' => Icons.star_border,
    'report_warned' => Icons.warning_amber,
    'content_removed' => Icons.delete,
    'event_cancelled' => Icons.event_busy,
    _ => Icons.notifications,
  };
}

/// In-app notification center (NOTI spec): newest-first list from the
/// `notifications` table, live inserts via Realtime, tap → deep link + mark
/// read, unread dot, pull-to-refresh, mark-all-read, empty state.
///
/// Black minimalist per DISCO-DESIGN-SYSTEM §1 (P1/P2): white core text,
/// hairline separators, `glowPink` reserved for the unread indicator — and
/// unread state is never color-only (bold title + dot, §2.5 rule 5).
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
  /// history list still loads and pull-to-refresh still works.
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
    } catch (_) {
      // Realtime is best-effort by design; the pull-to-refresh path remains.
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
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(l10n.notificationsMarkAllRead),
            ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: l10n.notificationsLoadError,
          onRetry: () =>
              ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (items) => items.isEmpty
            ? _EmptyState(l10n: l10n)
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(notificationsProvider.notifier).refresh(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, thickness: 1, color: AppColors.hairline),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationTile(
                      item: item,
                      onTap: () => _onTap(item),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none,
              size: AppIconSizes.xxl,
              color: AppColors.border,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.notificationsEmpty,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.notificationsEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedStrong),
            ),
          ],
        ),
      ),
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
      child: Container(
        color: unread ? AppColors.surface : AppColors.discoBlack,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              notificationIconForType(item.type),
              size: AppIconSizes.md,
              color: unread ? AppColors.glowPink : AppColors.mutedStrong,
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
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w300,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        time,
                        style: const TextStyle(
                          color: AppColors.mutedStrong,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedStrong,
                      fontSize: 14,
                      height: 1.4,
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
                decoration: const BoxDecoration(
                  color: AppColors.glowPink,
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
