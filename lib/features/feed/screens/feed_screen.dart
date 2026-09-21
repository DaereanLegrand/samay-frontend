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
import 'package:samay/features/feed/widgets/avatar_physics_cluster.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/minigame_pool.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
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
              // First load shows the shared spinner; pull-to-refresh keeps the
              // list visible.
              skipLoadingOnRefresh: true,
              loading: () => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: VLoadingView(),
                ),
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

/// Height of a feed match card's content row. The avatar physics box is given
/// the same height so the bubbles fill the whole card (2026-09-20 directive).
const double _kMatchCardHeight = 128;

/// A specific minigame match in the feed.
///
/// Deliberately NOT a muted outlined container: a bare block on black with a
/// hairline rhythm. The match copy stacks on the left — game name, title,
/// invite/active badge, then the bare shard pool total — while the participants
/// fill the right side as a full-card-height live avatar cluster whose bubbles
/// collide, pile against the right wall and jolt with feed scrolling. Usernames
/// are never listed. Tap → session detail (accept an invite / continue playing).
class _MinigameMatchCard extends ConsumerWidget {
  final FeedMinigameItem item;

  const _MinigameMatchCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = item.session;
    final sessionId = session['id'] as String;
    final wager = (session['shard_wager'] as num?)?.toInt() ?? 0;
    final positions =
        (session['prize_positions'] as num?)?.toInt() ?? kDefaultPrizePositions;
    final roster = ref.watch(minigameParticipantsProvider(sessionId));
    final participants = roster.valueOrNull ?? const <MinigameParticipant>[];
    final players =
        participants.isEmpty ? item.participantCount : participants.length;
    final showsBadge = item.fromParticipant || item.status == 'active';
    return InkWell(
      onTap: () => context.push(RoutePaths.minigameSession(sessionId)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        child: SizedBox(
          height: _kMatchCardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          minigameGameNameLower(l10n, item.gameType),
                          style: AppTypography.sectionLabel,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.fromParticipant)
                          VBadge.emphasized(label: l10n.feedMinigameInvite)
                        else if (item.status == 'active')
                          VBadge(label: l10n.minigamesStatusActive),
                        if (showsBadge) const SizedBox(height: AppSpacing.sm),
                        MinigamePoolAmount(
                          wager: wager,
                          players: players,
                          positions: positions,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 3,
                child: AvatarPhysicsCluster(
                  participants: participants,
                  height: _kMatchCardHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


