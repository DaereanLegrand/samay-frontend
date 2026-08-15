import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/models/notification_item.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/features/notifications/providers/notifications_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/glass/v_glass.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_aurora.dart';
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

/// LUXE v2 family for this screen — **gold** (ORCHESTRATION-LUXE map:
/// notifications → gold).
final AppGradient _family = AppGradients.familyOf('notifications');

/// In-app notification center (NOTI spec): newest-first list from the
/// `notifications` table, live inserts via Realtime, tap → deep link + mark
/// read, unread dot, pull-to-refresh, mark-all-read, empty state.
///
/// LUXE v2: unread rows are gold liquid-glass cards with the gold unread dot
/// (never pink — 2026-08-12 directive); unread state stays never color-only
/// (bold title + dot, §2.5 rule 5). XL-18 (Gemma 11_notifications "visual
/// hierarchy needs refinement"): the read title lifts from w300 to w400 so
/// the muted rows still read as typography, and the unread dot fill is the
/// gold family watered 45% (no saturated fills — ORCHESTRATION directive 3).
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
      AppLogger.instance.error('notifications realtime subscribe failed: $e', '$st');
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
      body: VAurora(
        gradients: const [AppGradients.gold],
        opacity: 0.05,
        child: notifications.when(
          // U-22 (§5.8): the first load shows the avatar+lines skeleton
          // instead of the bare spinner; pull-to-refresh keeps the list
          // visible (skipLoadingOnRefresh — the skeleton only ever stands in
          // when there is nothing on screen).
          skipLoadingOnRefresh: true,
          loading: () => const VSkeletonList(),
          error: (error, _) => ErrorView(
            message: l10n.notificationsLoadError,
            onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
          ),
          data: (items) => items.isEmpty
              ? VEmptyView(
                  icon: Icons.notifications_none,
                  title: l10n.notificationsEmpty,
                  description: l10n.notificationsEmptyBody,
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(notificationsProvider.notifier).refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(
                      height: AppSpacing.xs,
                    ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: VGlassCard(
          gradient: unread ? _family : null,
          glowAlpha: unread ? 0.18 : 0.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notificationIconForType(item.type),
                size: AppIconSizes.md,
                // LUXE: the unread accent is the gold family vivid end —
                // never pink (2026-08-12 directive).
                color: unread
                    ? AppGradients.gold.colors.last
                    : AppColors.mutedStrong,
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
                                  // XL-18 (Gemma 11 "hierarchy"): w300 read
                                  // rows read as dim, not as hierarchy —
                                  // w400 keeps the unread w600 dominant while
                                  // the text stays legible at AA.
                                  : FontWeight.w400,
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
                  // XL-18: no saturated fills — the gold vivid end is
                  // watered 45% toward white, keeping the gold read while
                  // reading as a pastel indicator (directive #3).
                  decoration: BoxDecoration(
                    color: AppGradients.watered(
                      [AppGradients.gold.colors.last],
                      mix: 0.45,
                    ).single,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
