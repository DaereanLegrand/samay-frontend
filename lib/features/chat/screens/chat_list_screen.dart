import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:samay/core/theme/app_palette_context.dart';

/// Chat inbox: every chat the user participates in, most-recent-first, with
/// the peer identity, a best-effort last-message preview (E2EE envelopes
/// decrypt client-side; own messages via the outbox) and the unread count.
/// Tap → thread; opening a thread marks it read. The feed button's unread
/// badge derives from [chatUnreadCountProvider], kept fresh by
/// [InboxRealtimeListener].
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
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

  /// Inbound messages refresh the list live (the shell listener already
  /// keeps the badge; the screen additionally refreshes its own list —
  /// actually [chatInboxProvider] is shared, so an invalidation covers both).
  Future<void> _subscribeRealtime() async {
    try {
      final channel = await ref.read(realtimeServiceProvider).subscribeToInbox((
        _,
      ) {
        if (!mounted) return;
        ref.invalidate(chatInboxProvider);
      });
      if (!mounted) return;
      _channel = channel;
    } catch (e, st) {
      // Realtime is best-effort by design; pull-to-refresh remains.
      AppLogger.instance.error(
        'chat inbox realtime subscribe failed: $e',
        '$st',
      );
    }
  }

  Future<void> _openChat(String chatId) async {
    await context.push(RoutePaths.chat(chatId));
    if (!mounted) return;
    // Coming back from a thread: the watermark moved server-side, so the
    // badge must re-derive.
    ref.invalidate(chatInboxProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inbox = ref.watch(chatInboxProvider);
    final me = ref.watch(authStateProvider).valueOrNull?.user?['id'];

    return Scaffold(
      body: VHeaderBar(
        title: l10n.chatInboxTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.socialSearchTooltip,
            onPressed: () => context.push(RoutePaths.userSearch),
          ),
        ],
        child: inbox.when(
          skipLoadingOnRefresh: true,
          loading: () => const VLoadingView(),
          error: (_, _) => ErrorView(
            message: l10n.chatInboxLoadError,
            onRetry: () => ref.read(chatInboxProvider.notifier).refresh(),
          ),
          data: (items) {
            if (items.isEmpty) {
              return VEmptyView(
                icon: Icons.chat_bubble_outline,
                title: l10n.chatInboxEmpty,
                description: l10n.chatInboxEmptyBody,
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(chatInboxProvider.notifier).refresh(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: context.palette.hairline),
                itemBuilder: (context, index) =>
                    _ChatListTile(item: items[index], me: me, onTap: _openChat),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One inbox row: the peer identity + preview + time on the left, the unread
/// [VCountBadge] on the right. Rows are hairline-separated and open the thread.
class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.item,
    required this.me,
    required this.onTap,
  });

  final ChatInboxItem item;
  final String? me;
  final void Function(String chatId) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mine =
        item.lastMessageSenderId != null && item.lastMessageSenderId == me;
    // A minigame group notice is the chat's latest activity — preview
    // it instead of the (empty) message preview and use its timestamp.
    final isNotice =
        item.lastActivityKind == 'minigame_notice' &&
        item.lastNoticeGameType != null;
    final String preview;
    if (isNotice) {
      preview = l10n.minigamesGroupMessage(
        minigameGameName(l10n, item.lastNoticeGameType),
      );
    } else if (item.lastMessageContent == null) {
      preview = '';
    } else if (item.decryptFailed) {
      preview = mine
          ? '${l10n.chatInboxPreviewOwn}…'
          : chatUndecryptablePlaceholder;
    } else {
      preview =
          '${mine ? l10n.chatInboxPreviewOwn : ''}${item.lastMessageContent}';
    }
    final timeLabel = _relativeTime(
      item.lastActivityAt ?? item.lastMessageAt,
      l10n,
    );
    final avatarUrl = item.peerAvatarUrl;
    final name = item.peerUsername ?? l10n.commonUser;
    final unread = item.unreadCount > 0;

    return InkWell(
      onTap: () => onTap(item.chatId),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.listRowVertical,
        ),
        child: Row(
          children: [
            ProfileAvatar(
              size: AppSpacing.avatarMedium,
              imageUrl: avatarUrl != null && avatarUrl.isNotEmpty
                  ? avatarUrl
                  : null,
              initials: name.isEmpty ? '?' : name[0].toUpperCase(),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    preview.isEmpty ? l10n.chatInboxEmpty : preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: unread ? context.palette.foreground : context.palette.mutedForeground,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.palette.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                VCountBadge(count: item.unreadCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact relative time ("ahora", "hace 5 m", "hace 3 h", else the date).
  static String _relativeTime(DateTime? at, AppLocalizations l10n) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return l10n.commonNow;
    if (diff.inHours < 1) return '${diff.inMinutes} m';
    if (diff.inDays < 1) return '${diff.inHours} h';
    return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}';
  }
}
