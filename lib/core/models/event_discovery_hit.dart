import 'package:samay/core/models/event.dart';

double _asDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

/// A discovery row from the `search_events` RPC: a full [Event] plus the
/// server-computed distance and the caller's accepted-friend activity signal.
///
/// [score] is `friendsGoing + 0.5 * friendsPending` — the RPC's ranking key
/// (higher first). The client renders `distanceKm` and "N amigos van" without
/// re-deriving anything.
class EventDiscoveryHit {
  final Event event;
  final double? distanceKm;
  final int friendsGoing;
  final int friendsPending;
  final double score;

  const EventDiscoveryHit({
    required this.event,
    required this.distanceKm,
    required this.friendsGoing,
    required this.friendsPending,
    required this.score,
  });

  factory EventDiscoveryHit.fromJson(Map<String, dynamic> json) {
    return EventDiscoveryHit(
      event: Event.fromJson(json),
      distanceKm: json['distance_km'] == null
          ? null
          : _asDouble(json['distance_km']),
      friendsGoing: (json['friends_going'] as num?)?.toInt() ?? 0,
      friendsPending: (json['friends_pending'] as num?)?.toInt() ?? 0,
      score: _asDouble(json['score']),
    );
  }
}
