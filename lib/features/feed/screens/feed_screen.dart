import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/models/feed_item.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/features/feed/providers/feed_providers.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_disco_divider.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// The agnostic social feed — the app's landing tab.
///
/// No longer event-only: the timeline interleaves public events with the
/// user's minigame matches, ordered by the most recent interaction. The
/// games quick-access row and the Party Finder entry were removed
/// (2026-09-20 revamp); the radius filter moved to the events tab.
///
/// Monochrome: always-black screen; the 'samay' hero is a [VDisplayText]
/// (verbatim copy, flat white Playfair glyphs); cards are sharp hairline
/// [VCard]s.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(feedProvider);

    return Scaffold(
      // LUXE directive #1: black background always — even outside the theme.
      backgroundColor: AppColors.discoBlack,
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // iOS-style collapsing brand hero ('samay'), pinned as a neutral
            // glass bar once scrolled (shared header mechanism).
            VHeaderSliver(
              title: l10n.feedBrand,
              actions: const [_ChatInboxButton()],
            ),
            ...feed.when(
              // U-22 (§5.8): the first load shows the skeleton instead of the
              // bare spinner; pull-to-refresh keeps the list visible
              // (skipLoadingOnRefresh — the skeleton only stands in when there
              // is nothing on screen).
              skipLoadingOnRefresh: true,
              loading: () => const [
                SliverToBoxAdapter(child: VSkeletonDetail()),
              ],
              error: (_, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message: l10n.feedLoadError,
                    onRetry: () => ref.read(feedProvider.notifier).refresh(),
                  ),
                ),
              ],
              data: (items) {
                if (items.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: VEmptyView(
                        icon: Icons.check_circle_outline,
                        title: l10n.feedAllCaughtUp,
                        description: l10n.feedComeBackLater,
                      ),
                    ),
                  ];
                }
                return [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: VDiscoDivider(),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _FeedItemCard(item: items[index]),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Routes a feed item to its card: events get the classic event card, matches
/// get the compact match card.
class _FeedItemCard extends StatelessWidget {
  final FeedItem item;

  const _FeedItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      FeedEventItem(:final event) => _EventCard(event: event),
      FeedMinigameItem() => _MinigameMatchCard(item: item as FeedMinigameItem),
    };
  }
}

/// The home-screen chat inbox shortcut — a chat bubble icon (tooltip is its
/// accessibility name) carrying the total-unread [VCountBadge] (hidden at 0).
/// Opens [RoutePaths.chatList].
class _ChatInboxButton extends ConsumerWidget {
  const _ChatInboxButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unread = ref.watch(chatUnreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: l10n.chatInboxTitle,
          onPressed: () => context.push(RoutePaths.chatList),
        ),
        Positioned(right: -2, top: -2, child: VCountBadge(count: unread)),
      ],
    );
  }
}

/// Regular event card: sharp hairline card, cover, name, type badge, date
/// range, location. Tap → event detail.
class _EventCard extends StatelessWidget {
  final Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      child: InkWell(
        onTap: () => context.push(RoutePaths.eventDetail(event.id)),
        child: VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.coverUrl != null) ...[
                VNetworkImage(
                  imageUrl: event.coverUrl!,
                  height: 140,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                event.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  VBadge(label: _typeLabel(l10n, event.type)),
                  if (event.featured) VBadge.emphasized(label: l10n.feedFeaturedBadge),
                  if (event.groupId != null)
                    VBadge(label: l10n.eventGroupScoped),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: AppIconSizes.sm,
                    color: AppColors.mutedStrong,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      formatEventDateRange(
                        event.startsAt,
                        event.endsAt,
                        Localizations.localeOf(context).languageCode,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedStrong,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: AppIconSizes.sm,
                    color: AppColors.mutedStrong,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      event.locationName ?? l10n.eventNoLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedStrong,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, String type) {
    return switch (type) {
      'casual' => l10n.eventsTypeCasual,
      'tono' => l10n.eventsTypeTono,
      _ => l10n.eventsTypeJuerga,
    };
  }
}

/// A specific minigame match in the feed.
///
/// Deliberately NOT a muted outlined container: a bare row on black with a
/// hairline separator. The people in the partida matter more than the count,
/// so the participants render as right-aligned Apple-Watch-style overlapping
/// avatar bubbles with their usernames below (never a comma-separated list).
/// Tap → session detail (accept an invite / continue playing).
class _MinigameMatchCard extends StatelessWidget {
  final FeedMinigameItem item;

  const _MinigameMatchCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionId = item.session['id'] as String;
    return InkWell(
      onTap: () => context.push(RoutePaths.minigameSession(sessionId)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        minigameGameNameLower(l10n, item.gameType),
                        style: AppTypography.sectionLabel,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (item.fromParticipant)
                  VBadge.emphasized(label: l10n.feedMinigameInvite)
                else if (item.status == 'active')
                  VBadge(label: l10n.minigamesStatusActive),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _ParticipantsRow(sessionId: sessionId),
          ],
        ),
      ),
    );
  }
}

/// Right-aligned overlapping avatar bubbles (Apple Watch style) plus the
/// participants' usernames. Usernames are individual labels — never joined by
/// commas.
class _ParticipantsRow extends ConsumerWidget {
  final String sessionId;

  const _ParticipantsRow({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(minigameParticipantsProvider(sessionId));
    final participants = roster.valueOrNull ?? const <MinigameParticipant>[];
    if (participants.isEmpty) {
      // Roster still loading / unavailable: keep the row height stable so the
      // card does not jump when the names land.
      return const SizedBox(height: 34);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _AvatarBubbles(participants: participants),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final p in participants)
              Text(
                '@${p.username}',
                style: const TextStyle(
                  color: AppColors.mutedStrong,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Overlapping circular avatar bubbles, right-aligned. Up to [_maxShown] are
/// drawn; the rest collapse into a `+N` bubble.
class _AvatarBubbles extends StatelessWidget {
  static const double _size = 34;
  static const double _overlap = 12;
  static const int _maxShown = 5;

  final List<MinigameParticipant> participants;

  const _AvatarBubbles({required this.participants});

  @override
  Widget build(BuildContext context) {
    final shown = participants.take(_maxShown).toList();
    final overflow = participants.length - shown.length;
    final count = shown.length + (overflow > 0 ? 1 : 0);
    final width = count == 0 ? 0.0 : _size + (count - 1) * (_size - _overlap);

    return SizedBox(
      height: _size,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (_size - _overlap),
              child: _AvatarBubble(
                size: _size,
                imageUrl: shown[i].avatarUrl,
                initials: _initials(shown[i].username),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: shown.length * (_size - _overlap),
              child: _OverflowBubble(size: _size, count: overflow),
            ),
        ],
      ),
    );
  }

  static String _initials(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'[\s_.-]+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0]).join();
    return (letters.isEmpty ? trimmed[0] : letters).toUpperCase();
  }
}

class _AvatarBubble extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final String initials;

  const _AvatarBubble({
    required this.size,
    required this.imageUrl,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    // A black ring separates overlapping bubbles (Apple Watch treatment).
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.discoBlack,
      ),
      padding: const EdgeInsets.all(2),
      child: ProfileAvatar(size: size - 4, imageUrl: imageUrl, initials: initials),
    );
  }
}

class _OverflowBubble extends StatelessWidget {
  final double size;
  final int count;

  const _OverflowBubble({required this.size, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceAlt,
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          color: AppColors.white,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

