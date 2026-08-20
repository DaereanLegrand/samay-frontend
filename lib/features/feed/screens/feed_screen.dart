import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/features/feed/providers/feed_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
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
import 'package:samay/shared/widgets/v_network_image.dart';

/// The social feed — the app's landing tab (FEED spec §feed-screen).
///
/// LUXE v2 (XL-07): the feed owns the **cyan** gradient family
/// (`AppGradients.familyOf('feed')` — ORCHESTRATION-LUXE §"Gradient family →
/// screen map"; NO PINK MAINS). The screen is always-black; the 'SAMAY' hero
/// is a [VDisplayText] (uppercase Playfair, cyan gradient fill, pulsing halo
/// — directive #6/#8, one hero);
/// featured cards are liquid glass ([VGlass], cyan ring + soft glow);
/// upcoming cards are sharp hairline [VGlassCard]s; the featured badge is
/// the cyan `VBadge.accent` family variant; radius chips are `VChip.accent`
/// in cyan; the [VDiscoDivider] accent is the cyan vivid end at α0.5.
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

  /// The cyan divider accent (vivid end at α0.5 — LUXE screen-owned tint;
  /// a 1px segment cannot carry a gradient, so the flat vivid token is
  /// watered for chrome, per the ORCHESTRATION divider guidance).
  static final Color _dividerAccent =
      AppColors.discoCyan.withValues(alpha: 0.5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(feedProvider);
    final family = AppGradients.familyOf('feed');

    return Scaffold(
      // LUXE directive #1: black background always — even outside the theme.
      backgroundColor: AppColors.discoBlack,
      body: SafeArea(
        child: feed.when(
          // U-22 (§5.8): the first load shows the event-card skeleton
          // instead of the bare spinner; pull-to-refresh keeps the list
          // visible (skipLoadingOnRefresh — the skeleton only ever stands
          // in when there is nothing on screen).
          skipLoadingOnRefresh: true,
          loading: () => const VSkeletonDetail(),
          error: (_, _) => ErrorView(
            message: l10n.feedLoadError,
            onRetry: () => ref.read(feedProvider.notifier).refresh(),
          ),
          data: (events) {
            final featured = events.where((e) => e.featured).toList();
            final upcoming = events.where((e) => !e.featured).toList();
            return RefreshIndicator(
              onRefresh: () => ref.read(feedProvider.notifier).refresh(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _FeedHeader(
                      title: l10n.feedBrand,
                      showRadiusFilter: events.isNotEmpty,
                      family: family,
                    ),
                  ),
                  // Plugged home (2026-08-13): the games quick-access
                  // section sits ON TOP of the feed content, right under
                  // the brand hero — five minigame cards + the Party
                  // Finder entry, flag-gated.
                  const SliverToBoxAdapter(child: _GamesSection()),
                  // The hairline + cyan-accent section separator (U-06
                  // divider, LUXE cyan tint) between the header and the
                  // content — and again between the featured carousel and
                  // the upcoming list.
                  if (events.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.xl,
                          bottom: AppSpacing.xl,
                          left: AppSpacing.screenHorizontal,
                          right: AppSpacing.screenHorizontal,
                        ),
                        child: VDiscoDivider(
                          accentColor: FeedScreen._dividerAccent,
                        ),
                      ),
                    ),
                  if (featured.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _FeaturedSection(
                        events: featured,
                        sectionLabel: l10n.feedFeatured,
                        badgeLabel: l10n.feedFeaturedBadge,
                        family: family,
                      ),
                    ),
                    if (upcoming.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: VDiscoDivider(
                            accentColor: FeedScreen._dividerAccent,
                          ),
                        ),
                      ),
                  ],
                  if (upcoming.isNotEmpty)
                    SliverList.builder(
                      itemCount: upcoming.length,
                      itemBuilder: (context, index) => _EventCard(
                        event: upcoming[index],
                        family: family,
                      ),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Brand hero + radius filter. LUXE v2: ONE hero per screen (directive #8) —
/// the 'SAMAY' wordmark in [VDisplayText] (MAYUS enforced, cyan gradient
/// glyph fill, 3-layer glow-strong pulsing halo). The radius filter and the
/// honest no-location notice stay below it — functional, unchanged.
class _FeedHeader extends ConsumerWidget {
  final String title;
  final bool showRadiusFilter;

  /// The screen's cyan family — the hero gradient + the chip accent.
  final AppGradient family;

  const _FeedHeader({
    required this.title,
    required this.showRadiusFilter,
    required this.family,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final radius = RadiusFilterBar(l10n: l10n, family: family);
    // The chat inbox shortcut (2026-08-15, user request): same placement as
    // the profile's settings gear (top-right of the hero) but on the home
    // screen. The badge shows the TOTAL unread messages across chats — kept
    // fresh by InboxRealtimeListener.
    final unread = ref.watch(chatUnreadCountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VDisplayText(
                  text: title,
                  gradient: family,
                ),
              ),
              _ChatInboxButton(unread: unread, family: family),
            ],
          ),
          if (showRadiusFilter) ...[
            const SizedBox(height: AppSpacing.lg),
            radius,
            const SizedBox(height: AppSpacing.xs),
            _NoLocationNotice(l10n: l10n),
          ],
        ],
      ),
    );
  }
}

/// The home-screen chat inbox shortcut — a chat bubble icon (tooltip is its
/// accessibility name, mirroring the profile gear U-26 contract) carrying the
/// total-unread [VCountBadge] (hidden at 0). Opens [RoutePaths.chatList].
class _ChatInboxButton extends StatelessWidget {
  final int unread;
  final AppGradient family;

  const _ChatInboxButton({required this.unread, required this.family});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: l10n.chatInboxTitle,
          onPressed: () => context.push(RoutePaths.chatList),
        ),
        Positioned(
          right: -2,
          top: -2,
          child: VCountBadge(count: unread, gradient: family),
        ),
      ],
    );
  }
}

/// Radius chips (5/20/50/anywhere) from `app_config`
/// (`feed.nearby_radius_km_options`); the selection drives
/// [radiusFilterProvider]. Functional today as a preference — the distance
/// filter applies once a device location exists.
///
/// LUXE v2: `VChip.accent` in the screen's cyan family — vivid cyan border +
/// label, vivid fill when selected (the gradient family's vivid end; a chip
/// border cannot carry a gradient, so the family hue is the accent).
class RadiusFilterBar extends ConsumerWidget {
  final AppLocalizations l10n;

  /// The screen's cyan family — drives the accent chips.
  final AppGradient family;

  const RadiusFilterBar({super.key, required this.l10n, required this.family});

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
          return VChip.accent(
            label: anywhere
                ? l10n.feedRadiusAnywhere
                : l10n.feedRadiusKm(radius.round()),
            selected: selected == radius,
            onSelected: () =>
                ref.read(radiusFilterProvider.notifier).select(radius),
            gradient: family,
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

/// Featured events carousel (FEED spec): pinned at the top, liquid-glass
/// cards with a cyan gradient ring + soft glow (the LUXE "event of the
/// night"), 'DESTACADO' badge in the cyan `VBadge.accent` family variant.
class _FeaturedSection extends StatelessWidget {
  final List<Event> events;
  final String sectionLabel;
  final String badgeLabel;

  /// The screen's cyan family — the carousel glass + badge accent.
  final AppGradient family;

  const _FeaturedSection({
    required this.events,
    required this.sectionLabel,
    required this.badgeLabel,
    required this.family,
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
              itemBuilder: (context, index) => _FeaturedCard(
                event: events[index],
                badgeLabel: badgeLabel,
                family: family,
              ),
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

  /// The screen's cyan family — the glass ring + glow + badge accent.
  final AppGradient family;

  const _FeaturedCard({
    required this.event,
    required this.badgeLabel,
    required this.family,
  });

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
                    // LUXE accent badge: the cyan family — pale watered fill,
                    // mid-stop border, black label (never pink).
                    VBadge.accent(label: badgeLabel, gradient: family),
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

/// Regular upcoming-event card: sharp hairline glass with the cyan ring
/// (glow reserved for the featured carousel), cover, name, type badge, date
/// range, location. Tap → event detail.
class _EventCard extends StatelessWidget {
  final Event event;

  /// The screen's cyan family — the hairline glass ring.
  final AppGradient family;

  const _EventCard({required this.event, required this.family});

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
          if (minigamesOn) ...[
            SizedBox(
              height: AppSpacing.scale(context, 132),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: MinigameType.values.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) => _HomeGameCard(
                  type: MinigameType.values[index],
                  onTap: () => _openMinigames(context, ref),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (partyFinderOn)
            _PartyFinderCard(
              onTap: () => context.push(RoutePaths.partyFinder),
            ),
        ],
      ),
    );
  }

  /// Opens the group minigames hub for the picked group. Single group →
  /// straight navigation; multiple groups → bottom-sheet picker; none → the
  /// join-a-group hint. The groups list is awaited (the provider is only
  /// built on first tap — a synchronous `.valueOrNull` read would always be
  /// null/loading).
  Future<void> _openMinigames(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    late final List<Group> groups;
    try {
      groups = await ref.read(myGroupsProvider.future);
    } catch (e) {
      // No-fallback (2026-08-14): a failed groups fetch must NEVER masquerade
      // as "no groups yet" — surface the real error.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toAppError().message)),
      );
      return;
    }
    if (groups.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.minigamesNoGroups}\n${l10n.minigamesNoGroupsBody}',
          ),
        ),
      );
      return;
    }

    String? groupId;
    if (groups.length == 1) {
      groupId = groups.first.id;
    } else {
      if (!context.mounted) return;
      groupId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.surfaceAlt,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l10n.minigamesChooseGroup,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final group in groups)
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text(group.name),
                  onTap: () => Navigator.of(sheetContext).pop(
                    group.id,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      );
    }

    if (groupId != null && context.mounted) {
      await context.push(RoutePaths.minigames(groupId));
    }
  }
}

/// Home tile for one minigame: icon + localized name, opening the games hub
/// for the user's group (black button — user directive 2026-08-14: home-page
/// buttons are black, white-only glass, no cyan; icons are shared via
/// [minigameIcon]).
class _HomeGameCard extends StatelessWidget {
  final MinigameType type;
  final VoidCallback onTap;

  const _HomeGameCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 120,
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
