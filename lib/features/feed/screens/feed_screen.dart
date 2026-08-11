import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/features/feed/providers/feed_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_breathing_glow.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_disco_divider.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// The social feed — the app's landing tab (FEED spec §feed-screen).
///
/// FOUNDATION scope (I-58): header, radius chips (options from `app_config`,
/// 'anywhere' selected while no device location exists), featured events
/// pinned as a carousel, upcoming **public** events sorted by `starts_at`
/// ASC, pull-to-refresh, empty + error states, tap → event detail. Group
/// activity posts and the geolocation distance filter are future work (the
/// `LocationService` doesn't exist yet — see the I-58 daily log).
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(feedProvider);

    return Scaffold(
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
                    ),
                  ),
                  // U-08: the hairline+glowPink section separator (U-06)
                  // between the header and the content — and again between
                  // the featured carousel and the upcoming list.
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Brand wordmark (Playfair Display italic + glow, DISCO-DESIGN-SYSTEM §3.2
/// "feed hero header") above the radius filter. U-08: the header renders the
/// glow-strong `displaySmall` fancy moment; U-18: it breathes through
/// [VBreathingGlow] — the §6.2 disco-glow animation (α0.75→α1.0 on a 3s
/// alternate, reduced-motion-gated), one breathing element per screen.
class _FeedHeader extends StatelessWidget {
  final String title;
  final bool showRadiusFilter;

  const _FeedHeader({required this.title, required this.showRadiusFilter});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final radius = RadiusFilterBar(l10n: l10n);
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
          VBreathingGlow(text: title, style: AppTypography.displaySmall),
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

/// Radius chips (5/20/50/anywhere) from `app_config`
/// (`feed.nearby_radius_km_options`); the selection drives
/// [radiusFilterProvider]. Functional today as a preference — the distance
/// filter applies once a device location exists.
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

/// Featured events carousel (FEET spec): pinned at the top, glow-pink border
/// (DISCO-DESIGN-SYSTEM §5.3 featured card — the event of the night),
/// 'DESTACADO' badge in the §5.5 glowPink accent variant.
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
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.glowPink),
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
                    // §5.5 accent badge: glowPink border + label, black fill.
                    VBadge.accent(label: badgeLabel, color: AppColors.glowPink),
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

/// Regular upcoming-event card: cover, name, type badge, date range,
/// location. Tap → event detail.
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
