import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/features/feed/providers/feed_providers.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_disco_divider.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// The social feed — the app's landing tab (FEED spec §feed-screen).
///
/// Monochrome (2026-08-26 user directive: all color stripped down): the
/// screen is always-black; the 'samay' hero is a [VDisplayText] (verbatim
/// copy, flat white Playfair glyphs);
/// featured cards are sharp hairline [VGlassCard]s; the featured badge is
/// the white `VBadge.emphasized`; radius chips are plain `VChip`s; the
/// [VDiscoDivider] accent is the neutral white tick.
///
/// FOUNDATION scope preserved byte-identical (I-58): radius chips (options
/// from `app_config`, 'anywhere' selected while no device location exists),
/// featured events pinned as a carousel, upcoming **public** events sorted
/// by `starts_at` ASC, pull-to-refresh, empty + error states, tap → event
/// detail. Group activity posts and the geolocation distance filter are
/// future work (the `LocationService` doesn't exist yet — see the I-58
/// daily log).

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
              // U-22 (§5.8): the first load shows the event-card skeleton
              // instead of the bare spinner; pull-to-refresh keeps the list
              // visible (skipLoadingOnRefresh — the skeleton only ever stands
              // in when there is nothing on screen).
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
              data: (events) {
                final featured = events.where((e) => e.featured).toList();
                final upcoming = events.where((e) => !e.featured).toList();
                return [
                  if (events.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          left: AppSpacing.screenHorizontal,
                          right: AppSpacing.screenHorizontal,
                        ),
                        child: _RadiusHeader(l10n: l10n),
                      ),
                    ),
                  // Plugged home (2026-08-13): the games quick-access
                  // section sits ON TOP of the feed content, right under
                  // the brand hero — five minigame cards + the Party
                  // Finder entry, flag-gated.
                  const SliverToBoxAdapter(child: _GamesSection()),
                  // The hairline + white-accent section separator between
                  // the header and the content — and again between the
                  // featured carousel and the upcoming list.
                  if (events.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: AppSpacing.xl,
                          bottom: AppSpacing.xl,
                          left: AppSpacing.screenHorizontal,
                          right: AppSpacing.screenHorizontal,
                        ),
                        child: VDiscoDivider(),
                      ),
                    ),
                  if (featured.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _FeaturedSection(
                        events: featured,
                        sectionLabel: l10n.feedFeatured,
                        badgeLabel: l10n.feedFeaturedBadge,
                      ),
                    ),
                    if (upcoming.isNotEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: VDiscoDivider(),
                        ),
                      ),
                  ],
                  if (upcoming.isNotEmpty)
                    SliverList.builder(
                      itemCount: upcoming.length,
                      itemBuilder: (context, index) =>
                          _EventCard(event: upcoming[index]),
                    )
                  else
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: VEmptyView(
                        icon: Icons.explore_outlined,
                        title: l10n.feedNoEvents,
                        description: l10n.feedNoEventsBody,
                      ),
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

/// The radius filter block under the brand hero: chips + honest no-location
/// notice. Scrolls away beneath the pinned [VHeaderSliver] glass.
class _RadiusHeader extends ConsumerWidget {
  final AppLocalizations l10n;

  const _RadiusHeader({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = RadiusFilterBar(l10n: l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        radius,
        const SizedBox(height: AppSpacing.xs),
        _NoLocationNotice(l10n: l10n),
      ],
    );
  }
}

/// The home-screen chat inbox shortcut — a chat bubble icon (tooltip is its
/// accessibility name, mirroring the profile gear U-26 contract) carrying the
/// total-unread [VCountBadge] (hidden at 0). Opens [RoutePaths.chatList].
class _ChatInboxButton extends ConsumerWidget {
  const _ChatInboxButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // The chat inbox shortcut (2026-08-15, user request): same placement as
    // the profile's settings gear (top-right of the hero) but on the home
    // screen. The badge shows the TOTAL unread messages across chats — kept
    // fresh by InboxRealtimeListener.
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

/// Radius chips (5/20/50/anywhere) from `app_config`
/// (`feed.nearby_radius_km_options`); the selection drives
/// [radiusFilterProvider]. Functional today as a preference — the distance
/// filter applies once a device location exists.
///
/// Monochrome: plain `VChip` — white border + label, white fill + black
/// label when selected.
class RadiusFilterBar extends ConsumerWidget {
  final AppLocalizations l10n;

  const RadiusFilterBar({super.key, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(feedRadiusOptionsProvider);
    final selected = ref.watch(radiusFilterProvider);
    return SizedBox(
      // U-19 (§7.3): the chip row must grow with the text scale — a hard
      // 36px height clips the chips at ≥1.5× (the `AppSpacing.scale` helper,
      // finding UI-09 / §4.1).
      height: AppSpacing.scale(context, 36),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final radius = options[index];
          final anywhere = radius >= kFeedRadiusAnywhereKm;
          return VChip(
            label: anywhere
                ? l10n.feedRadiusAnywhere
                : l10n.feedRadiusKm(radius.round()),
            selected: selected == radius,
            onSelected: () =>
                ref.read(radiusFilterProvider.notifier).select(radius),
          );
        },
      ),
    );
  }
}

/// Honest FOUNDATION notice: no device location is available yet, so no
/// distance filtering happens (FEED spec "Sin filtro de ubicación" state).
class _NoLocationNotice extends StatelessWidget {
  final AppLocalizations l10n;

  const _NoLocationNotice({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Text(
      l10n.feedNoLocationNotice,
      style: const TextStyle(color: AppColors.mutedStrong, fontSize: 12),
    );
  }
}

/// Featured events carousel (FEED spec): pinned at the top, sharp hairline
/// cards, 'DESTACADO' badge in the white `VBadge.emphasized` variant.
class _FeaturedSection extends StatelessWidget {
  final List<Event> events;
  final String sectionLabel;
  final String badgeLabel;

  const _FeaturedSection({
    required this.events,
    required this.sectionLabel,
    required this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Text(
              sectionLabel,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // U-19 (§7.3): the carousel height grows with the text scale —
          // the fixed 264px box overflowed the featured card's text block
          // at 1.5× (the `AppSpacing.scale` helper, finding UI-09 / §4.1).
          SizedBox(
            height: AppSpacing.scale(context, 264),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _FeaturedCard(event: events[index], badgeLabel: badgeLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Event event;
  final String badgeLabel;

  const _FeaturedCard({required this.event, required this.badgeLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: () => context.push(RoutePaths.eventDetail(event.id)),
        child: Container(
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.coverUrl != null)
                VNetworkImage(
                  imageUrl: event.coverUrl!,
                  height: 120,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  height: 120,
                  color: AppColors.surfaceAlt,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.event,
                    size: AppIconSizes.xl,
                    color: AppColors.muted,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Monochrome featured badge: white fill + black label.
                    VBadge.emphasized(label: badgeLabel),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
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
                    if (event.locationName != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        event.locationName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedStrong,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Regular upcoming-event card: sharp hairline card, cover, name, type
/// badge, date range, location. Tap → event detail.
class _EventCard extends StatelessWidget {
  final Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
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
                  // §5.5 default badge: border #333333 fill + white
                  // uppercase labelSmall (§3.3) — the type + scope markers.
                  VBadge(label: _typeLabel(l10n, event.type)),
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

/// Plugged home — games quick-access (2026-08-13).
///
/// Sits at the top of the feed, under the brand hero: the five minigame
/// cards open the group minigames hub. Tapping a game with zero groups shows
/// the join-a-group hint; with exactly one group it navigates straight
/// there; otherwise a bottom sheet picks the group. Party Finder is the
/// discovery entry below. Both entries are flag-gated
/// ([AppFeatureFlag.minigames] / [AppFeatureFlag.partyFinder]).
class _GamesSection extends ConsumerWidget {
  const _GamesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final minigamesOn = ref.isEnabled(AppFeatureFlag.minigames);
    final partyFinderOn = ref.isEnabled(AppFeatureFlag.partyFinder);
    if (!minigamesOn && !partyFinderOn) return const SizedBox.shrink();
    // Per-game pending-invite counts (170_minigame_invite_badges): the unread
    // minigame_invite notifications grouped by gameType drive the red badge
    // on each tile — a friend who invited you to a partida makes that game's
    // tile show how many invited matches await.
    final pendingByType = ref.watch(pendingMinigameInvitesByTypeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xl,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeGamesTitle.toUpperCase(),
            style: AppTypography.sectionLabel,
          ),
          const SizedBox(height: AppSpacing.md),
          // The tile is a SQUARE: its width equals the row height (both scale
          // with the text scaler), so every game card is identical in size at
          // any font setting (2026-08-30 fix — a fixed 120px width drifted
          // from the scaled row height and made some cards wider than others).
          if (minigamesOn) ...[
            SizedBox(
              height: _homeTileSize(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: MinigameType.values.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) => _HomeGameCard(
                  type: MinigameType.values[index],
                  tileSize: _homeTileSize(context),
                  pendingCount:
                      pendingByType[MinigameType.values[index].value] ?? 0,
                  onTap: () => context.push(
                    RoutePaths.minigame(MinigameType.values[index].value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (partyFinderOn)
            _PartyFinderCard(onTap: () => context.push(RoutePaths.partyFinder)),
        ],
      ),
    );
  }
}

/// Square tile dimension for the home games row: the 132px design height
/// scaled by the text scaler. Width == height, so every game card is a
/// perfect square at any font setting (2026-08-30 fix).
double _homeTileSize(BuildContext context) => AppSpacing.scale(context, 132);

/// Home tile for one minigame: icon + localized name, opening the game's
/// dedicated page (2026-08-28: the feed card now routes to
/// [RoutePaths.minigame] — title, explanation, audience, "Nueva partida"
/// and the ongoing list). Black button (user directive 2026-08-14: home-page
/// buttons are black, white-only glass, no cyan; icons are shared via
/// [minigameIcon]).
///
/// The red [VCountBadge] (top-right, 170_minigame_invite_badges) shows how
/// many invited partidas of this game await the user — same badge voice as
/// the shell's Grupos-tab badge.
class _HomeGameCard extends StatelessWidget {
  final MinigameType type;
  final int pendingCount;
  final VoidCallback onTap;

  /// The square tile dimension (width == height, both scaled with the text
  /// scaler) so every game card is identical in size.
  final double tileSize;

  const _HomeGameCard({
    required this.type,
    required this.tileSize,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: tileSize,
        height: tileSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Positioned.fill forces the VCard to fill the WHOLE square. A
            // Stack otherwise gives non-positioned children loose constraints,
            // so the card shrink-wraps to its content width — a short name
            // like "Preguntas" made the background narrower than the tile
            // while the InkWell splash still covered the full square
            // (2026-08-30 fix).
            Positioned.fill(
              child: VCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(minigameIcon(type), color: AppColors.white),
                    const Spacer(),
                    Text(
                      minigameGameName(l10n, type.value),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (pendingCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: VCountBadge(count: pendingCount),
              ),
          ],
        ),
      ),
    );
  }
}

/// Home entry card for the Party Finder: discovery of people by interest
/// tags (PFND — I-60). Black button (user directive 2026-08-14), one row.
class _PartyFinderCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PartyFinderCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: VCard(
        child: Row(
          children: [
            const Icon(Icons.travel_explore, color: AppColors.white),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.partyFinderTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.homePartyFinderBody,
                    style: const TextStyle(
                      color: AppColors.mutedStrong,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mutedStrong),
          ],
        ),
      ),
    );
  }
}
