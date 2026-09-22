import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/events/widgets/event_radius_filter.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// The events tab: the session's events earliest-first,
/// with a create CTA that opens the standalone `/events/create` flow (an
/// event can be public or group-scoped; group entry points stay reachable).
///
/// Monochrome: flat black/white hero + CTA; the list cards stay neutral
/// white-only glass.
class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  Future<void> _refresh() async {
    await ref.read(myEventsProvider.notifier).refresh();
  }

  /// Creation from the Events tab: opens the standalone
  /// `/events/create` flow (events can still be created from a group via
  /// the group detail route).
  void _openCreateEvent() {
    context.push(RoutePaths.eventCreate);
  }

  void _openEvent(Event event) {
    context.push(RoutePaths.eventDetail(event.id));
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(myEventsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // LUXE directive #1: black background always — even outside the theme.
      backgroundColor: AppColors.discoBlack,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // iOS-style collapsing hero ('mis eventos'), pinned as a neutral
            // glass bar once scrolled (shared header mechanism).
            VHeaderSliver(title: l10n.eventsTabTitle),
            ...eventsAsync.when(
              // First load shows the shared spinner; pull-to-refresh keeps the
              // list visible.
              skipLoadingOnRefresh: true,
              loading: () => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: VLoadingView(),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message: e.toAppError().message,
                    onRetry: _refresh,
                  ),
                ),
              ],
              data: (events) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      left: AppSpacing.screenHorizontal,
                      right: AppSpacing.screenHorizontal,
                    ),
                    child: EventRadiusHeader(l10n: l10n),
                  ),
                ),
                // The create CTA sits right under the hero and scrolls away
                // with the content.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VButton.dark(
                          label: l10n.eventsCreateCta,
                          onPressed: _openCreateEvent,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.eventsCreateCtaBody,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.mutedStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (events.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: VEmptyView(
                      icon: Icons.event_outlined,
                      title: l10n.eventsEmpty,
                      description: l10n.eventsEmptyBody,
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) => _MyEventCard(
                      event: events[index],
                      onTap: () => _openEvent(events[index]),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Regular event row: sharp hairline glass, cover, name, type + status
/// badges, date range and location. Tap → event detail.
class _MyEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _MyEventCard({required this.event, required this.onTap});

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
        key: ValueKey('my-event-card-${event.id}'),
        onTap: onTap,
        child: VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.coverUrl != null && event.coverUrl!.isNotEmpty) ...[
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
                  VBadge(label: _statusLabel(l10n, event.status)),
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
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedStrong,
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
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedStrong,
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

  String _statusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'draft' => l10n.eventStatusDraft,
      'live' => l10n.eventStatusLive,
      'ended' => l10n.eventStatusEnded,
      'cancelled' => l10n.eventStatusCancelled,
      _ => l10n.eventStatusUpcoming,
    };
  }
}
