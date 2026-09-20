import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/config_provider.dart';

/// Sentinel radius (km) for "anywhere": `feed.nearby_radius_km_options`
/// seeds `999` as the everywhere value (FEED spec §geographical-filter).
const double kEventRadiusAnywhereKm = 999;

/// Parses `feed.nearby_radius_km_options` (comma-separated km values, `999` =
/// anywhere) into a list of options. Falls back to the seeded `5,20,50,999`
/// list when the key is missing, empty or unparseable — the radius UI must
/// stay functional without `app_config`.
List<double> parseEventRadiusOptions(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [5, 20, 50, kEventRadiusAnywhereKm];
  }
  final values = raw
      .split(',')
      .map((part) => double.tryParse(part.trim()))
      .whereType<double>()
      .toList();
  if (values.isEmpty) return const [5, 20, 50, kEventRadiusAnywhereKm];
  return values;
}

/// Parses `feed.nearby_radius_km_default` (km). Falls back to 50 km (the
/// seeded default) when the key is missing or unparseable.
double parseEventRadiusDefault(String? raw) =>
    double.tryParse(raw ?? '') ?? 50;

/// Radius filter options from `app_config` (`feed.nearby_radius_km_options`),
/// seeded fallback `[5, 20, 50, 999]`.
final eventRadiusOptionsProvider = Provider<List<double>>((ref) {
  final config = ref.watch(appConfigProvider).valueOrNull;
  return parseEventRadiusOptions(config?['feed.nearby_radius_km_options']);
});

/// The configured default radius (`feed.nearby_radius_km_default`, seeded
/// 50 km). Used once the geolocation service lands; the active filter
/// currently defaults to anywhere (see [eventRadiusFilterProvider]).
final eventRadiusDefaultProvider = Provider<double>((ref) {
  final config = ref.watch(appConfigProvider).valueOrNull;
  return parseEventRadiusDefault(config?['feed.nearby_radius_km_default']);
});

class EventRadiusFilterNotifier extends Notifier<double> {
  /// Defaults to anywhere ([kEventRadiusAnywhereKm]) — device location does
  /// not exist yet (geolocation service is future work), so the events tab
  /// must never drop events. The config default
  /// ([eventRadiusDefaultProvider]) takes over once a location is available.
  @override
  double build() => kEventRadiusAnywhereKm;

  void select(double radius) => state = radius;
}

/// The active radius selection in km (`999` = anywhere). Chips read and write
/// this; the distance filter itself applies only when a device location is
/// available (future `LocationService`).
final eventRadiusFilterProvider =
    NotifierProvider<EventRadiusFilterNotifier, double>(
      EventRadiusFilterNotifier.new,
    );
