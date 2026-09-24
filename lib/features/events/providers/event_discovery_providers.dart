import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/event_discovery_hit.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/events/providers/event_radius_providers.dart';

/// Minimum event-search query length. Events may have short names, so this is
/// 2 (matches the server-side `search_events` SR002 cap of 2..50).
const int kEventSearchMinLength = 2;

/// The sanitized search box content (empty = no text filter).
final eventSearchQueryProvider =
    NotifierProvider<EventSearchQueryNotifier, String>(
      EventSearchQueryNotifier.new,
    );

class EventSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = InputSanitizer.sanitize(
      value,
      maxLength: InputSanitizer.searchQueryMaxLength,
      normalizeNfkc: true,
    );
  }

  void clear() => state = '';
}

/// A reference point for the km filter (device GPS or a manually picked one).
class EventReferencePoint {
  final double latitude;
  final double longitude;

  const EventReferencePoint({
    required this.latitude,
    required this.longitude,
  });
}

/// The active reference point; null until a location is resolved or picked.
final eventReferencePointProvider =
    NotifierProvider<EventReferencePointNotifier, EventReferencePoint?>(
      EventReferencePointNotifier.new,
    );

class EventReferencePointNotifier extends Notifier<EventReferencePoint?> {
  @override
  EventReferencePoint? build() => null;

  void set(EventReferencePoint point) => state = point;
  void clear() => state = null;
}

/// Whether the "Cerca de mí" distance filter is active.
final eventNearbyEnabledProvider =
    NotifierProvider<EventNearbyEnabledNotifier, bool>(
      EventNearbyEnabledNotifier.new,
    );

class EventNearbyEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// The Eventos tab list. When a text query (≥ [kEventSearchMinLength]) or the
/// nearby filter is active it calls the server-side `search_events` RPC
/// (distance + friend signal + ranking); otherwise it falls back to the plain
/// earliest-first list. Debounce lives in the search field, so this rebuilds
/// only after the user pauses typing.
final eventDiscoveryProvider =
    AsyncNotifierProvider<EventDiscoveryNotifier, List<EventDiscoveryHit>>(
      EventDiscoveryNotifier.new,
    );

class EventDiscoveryNotifier extends AsyncNotifier<List<EventDiscoveryHit>> {
  @override
  Future<List<EventDiscoveryHit>> build() async {
    final service = ref.watch(eventServiceProvider);
    final query = ref.watch(eventSearchQueryProvider).trim();
    final nearby = ref.watch(eventNearbyEnabledProvider);
    final point = ref.watch(eventReferencePointProvider);
    final radius = ref.watch(eventRadiusFilterProvider);
    final hasQuery = query.length >= kEventSearchMinLength;
    final hasNearby = nearby && point != null;

    if (!hasQuery && !hasNearby) {
      final events = await service.listEvents();
      return events
          .map(
            (e) => EventDiscoveryHit(
              event: e,
              distanceKm: null,
              friendsGoing: 0,
              friendsPending: 0,
              score: 0,
            ),
          )
          .toList();
    }

    return service.searchEvents(
      query: hasQuery ? query : null,
      lat: hasNearby ? point.latitude : null,
      lng: hasNearby ? point.longitude : null,
      radiusKm: hasNearby ? radius : null,
    );
  }

  /// Manual/pull-to-refresh — invalidates and awaits the rebuild.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
