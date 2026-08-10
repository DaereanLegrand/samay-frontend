import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/event_service.dart';

/// Sentinel radius (km) for "anywhere": `feed.nearby_radius_km_options`
/// seeds `999` as the everywhere value (FEED spec §geographical-filter).
const double kFeedRadiusAnywhereKm = 999;

/// Parses `feed.nearby_radius_km_options` (comma-separated km values, `999` =
/// anywhere) into a list of options. Falls back to the seeded `5,20,50,999`
/// list when the key is missing, empty or unparseable — the radius UI must
/// stay functional without `app_config`.
List<double> parseFeedRadiusOptions(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [5, 20, 50, kFeedRadiusAnywhereKm];
  }
  final values = raw
      .split(',')
      .map((part) => double.tryParse(part.trim()))
      .whereType<double>()
      .toList();
  if (values.isEmpty) return const [5, 20, 50, kFeedRadiusAnywhereKm];
  return values;
}

/// Parses `feed.nearby_radius_km_default` (km). Falls back to 50 km (the
/// seeded default) when the key is missing or unparseable.
double parseFeedRadiusDefault(String? raw) =>
    double.tryParse(raw ?? '') ?? 50;

class FeedNotifier extends AsyncNotifier<List<Event>> {
  EventService get _service => ref.read(eventServiceProvider);

  /// FEED order: upcoming **public** events (group_id null) only, featured
  /// events pinned first, then `starts_at` ASC within each group. The service
  /// already sorts by `starts_at`, but the client re-sorts so featured
  /// pinning holds regardless of server ordering.
  @override
  Future<List<Event>> build() async {
    final rows = await _service.listEvents('upcoming');
    final public = rows.map(Event.fromJson).where((e) => e.groupId == null);
    final events = public.toList()
      ..sort((a, b) {
        if (a.featured != b.featured) return a.featured ? -1 : 1;
        return a.startsAt.compareTo(b.startsAt);
      });
    return events;
  }

  /// Re-runs [build] (pull-to-refresh, finding SM-09 pattern).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Upcoming public events for the feed, featured-first then `starts_at` ASC.
final feedProvider =
    AsyncNotifierProvider<FeedNotifier, List<Event>>(FeedNotifier.new);

/// Radius filter options from `app_config` (`feed.nearby_radius_km_options`),
/// seeded fallback `[5, 20, 50, 999]`.
final feedRadiusOptionsProvider = Provider<List<double>>((ref) {
  final config = ref.watch(appConfigProvider).valueOrNull;
  return parseFeedRadiusOptions(config?['feed.nearby_radius_km_options']);
});

/// The configured default radius (`feed.nearby_radius_km_default`, seeded
/// 50 km). Used once the geolocation service lands; the active filter
/// currently defaults to anywhere (see [radiusFilterProvider]).
final feedRadiusDefaultProvider = Provider<double>((ref) {
  final config = ref.watch(appConfigProvider).valueOrNull;
  return parseFeedRadiusDefault(config?['feed.nearby_radius_km_default']);
});

class RadiusFilterNotifier extends Notifier<double> {
  /// Defaults to anywhere ([kFeedRadiusAnywhereKm]) — device location does
  /// not exist yet (geolocation service is future work, I-58 log), so the
  /// FOUNDATION feed must never drop events. The config default
  /// ([feedRadiusDefaultProvider]) takes over once a location is available.
  @override
  double build() => kFeedRadiusAnywhereKm;

  void select(double radius) => state = radius;
}

/// The active radius selection in km (`999` = anywhere). Chips read and write
/// this; the distance filter itself applies only when a device location is
/// available (future `LocationService`).
final radiusFilterProvider =
    NotifierProvider<RadiusFilterNotifier, double>(RadiusFilterNotifier.new);
