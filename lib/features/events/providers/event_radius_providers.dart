import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Distance-filter slider bounds (km). **0 is the deactivated position** (no
/// distance filter); the server hard-caps the radius at 100 km
/// (`131_events_search/01_events_search.sql`).
const double kEventRadiusMinKm = 0;
const double kEventRadiusMaxKm = 100;

/// Slider step (km). `(max - min) / step` must divide evenly — the Slider's
/// `divisions` is an integer count.
const double kEventRadiusStepKm = 5;

class EventRadiusFilterNotifier extends Notifier<double> {
  /// Starts deactivated (0 km → no distance filter). The user drags the slider
  /// up to activate it; the filter only applies while a reference point exists.
  @override
  double build() => kEventRadiusMinKm;

  void select(double radius) => state = radius;
}

/// The active radius selection in km (0 = deactivated, 5..100 = active filter).
/// The Events-tab slider reads and writes this.
final eventRadiusFilterProvider =
    NotifierProvider<EventRadiusFilterNotifier, double>(
      EventRadiusFilterNotifier.new,
    );
