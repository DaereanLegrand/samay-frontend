import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/event_discovery_hit.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/location_service.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/features/events/providers/event_discovery_providers.dart';
import 'package:samay/features/events/widgets/event_radius_filter.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/location_picker_sheet.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// The events tab: server-side discovery (text search + server-side km filter
/// with the 100 km hard cap + accepted-friend activity), with header actions
/// for search, filters, and the create-event `+`.
class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  final _searchController = TextEditingController();
  final _location = const LocationService();
  Timer? _debounce;

  bool _searchOpen = false;
  bool _filterOpen = false;
  bool _resolving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(eventDiscoveryProvider.notifier).refresh();
  }

  void _openCreateEvent() {
    context.push(RoutePaths.eventCreate);
  }

  void _openEvent(EventDiscoveryHit hit) {
    context.push(RoutePaths.eventDetail(hit.event.id));
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen) {
      _debounce?.cancel();
      _searchController.clear();
      ref.read(eventSearchQueryProvider.notifier).clear();
    }
  }

  void _toggleFilter() => setState(() => _filterOpen = !_filterOpen);

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(eventSearchQueryProvider.notifier).setQuery(value);
    });
  }

  /// Resolves the device location into the filter's reference point. Returns
  /// false when unavailable so callers can prompt the manual picker.
  Future<bool> _useMyLocation() async {
    setState(() => _resolving = true);
    try {
      final point = await _location.current();
      if (!mounted) return false;
      if (point == null) return false;
      ref.read(eventReferencePointProvider.notifier).set(
            EventReferencePoint(
              latitude: point.latitude,
              longitude: point.longitude,
            ),
          );
      return true;
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _pickLocation() async {
    final current = ref.read(eventReferencePointProvider);
    final picked = await showLocationPicker(
      context,
      initial: current == null
          ? null
          : LatLng(current.latitude, current.longitude),
    );
    if (picked == null) return;
    ref.read(eventReferencePointProvider.notifier).set(
          EventReferencePoint(
            latitude: picked.latitude,
            longitude: picked.longitude,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final discoveryAsync = ref.watch(eventDiscoveryProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            VHeaderSliver(
              title: l10n.eventsTabTitle,
              actions: [
                IconButton(
                  icon: Icon(
                    _searchOpen ? Icons.search_off : Icons.search,
                    color: context.palette.foreground,
                  ),
                  tooltip: l10n.eventsSearchTooltip,
                  onPressed: _toggleSearch,
                ),
                IconButton(
                  icon: Icon(
                    _filterOpen
                        ? Icons.location_on
                        : Icons.location_on_outlined,
                    color: context.palette.foreground,
                  ),
                  tooltip: l10n.eventsFilterTooltip,
                  onPressed: _toggleFilter,
                ),
                IconButton(
                  icon: Icon(Icons.add, color: context.palette.foreground),
                  tooltip: l10n.eventsCreateCta,
                  onPressed: _openCreateEvent,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _searchOpen || _filterOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.md,
                          AppSpacing.screenHorizontal,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_searchOpen)
                              VInput(
                                label: l10n.eventsSearchHint,
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                              ),
                            if (_filterOpen) ...[
                              RadiusSlider(l10n: l10n),
                              const SizedBox(height: AppSpacing.sm),
                              _LocationControls(
                                resolving: _resolving,
                                onUseMyLocation: _useMyLocation,
                                onPickLocation: _pickLocation,
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            ...discoveryAsync.when(
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
              data: (hits) {
                if (hits.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: VEmptyView(
                        icon: Icons.event_outlined,
                        title: l10n.eventsEmpty,
                        description: l10n.eventsEmptyBody,
                      ),
                    ),
                  ];
                }
                return [
                  SliverList.builder(
                    itemCount: hits.length,
                    itemBuilder: (context, index) => _MyEventCard(
                      hit: hits[index],
                      onTap: () => _openEvent(hits[index]),
                    ),
                  ),
                ];
              },
            ),
            // Clear the floating shell nav bar so the last card can scroll
            // above it (nav-bar height + 16).
            SliverToBoxAdapter(
              child: SizedBox(height: MainShell.navBarInset(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reference-point controls: resolve the device location ("Usar mi
/// ubicación") or pick one on the map ("Elegir ubicación"). Once a point
/// exists the pick button's label becomes the chosen location (its coordinates
/// — there is no geocoder), and tapping it re-opens the map picker. The radius
/// slider above is disabled until a point exists (server hard-caps at 100 km).
class _LocationControls extends ConsumerWidget {
  final bool resolving;
  final Future<bool> Function() onUseMyLocation;
  final Future<void> Function() onPickLocation;

  const _LocationControls({
    required this.resolving,
    required this.onUseMyLocation,
    required this.onPickLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final point = ref.watch(eventReferencePointProvider);
    final labelStyle = AppTypography.labelMedium.copyWith(
      color: context.palette.foreground,
    );

    return Row(
      children: [
        TextButton(
          onPressed: resolving ? null : () => onUseMyLocation(),
          child: Text(l10n.eventsUseMyLocation, style: labelStyle),
        ),
        Flexible(
          child: TextButton(
            onPressed: onPickLocation,
            child: Text(
              point == null
                  ? l10n.eventsPickLocation
                  : l10n.locationPickerCoordinates(
                      '${point.latitude.toStringAsFixed(5)}, '
                      '${point.longitude.toStringAsFixed(5)}',
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ),
      ],
    );
  }
}

/// Regular event row: sharp hairline glass, cover, name, type + status
/// badges, distance, friend activity, date range and location. Tap → detail.
class _MyEventCard extends StatelessWidget {
  final EventDiscoveryHit hit;
  final VoidCallback onTap;

  const _MyEventCard({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final event = hit.event;

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
                  if (hit.friendsGoing > 0)
                    VBadge(label: l10n.eventsFriendsGoing(hit.friendsGoing)),
                  if (hit.distanceKm != null)
                    VBadge(
                      label: l10n.eventsDistanceKm(
                        hit.distanceKm!.toStringAsFixed(1),
                      ),
                    ),
                  if (event.groupId != null)
                    VBadge(label: l10n.eventGroupScoped),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: AppIconSizes.sm,
                    color: context.palette.mutedForeground,
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
                        color: context.palette.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: AppIconSizes.sm,
                    color: context.palette.mutedForeground,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      event.locationCity ?? event.locationName ?? l10n.eventNoLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.palette.mutedForeground,
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
