import 'package:samay/core/models/event.dart';

/// A single item in the agnostic social feed.
///
/// The feed interleaves public events with the
/// user's minigame matches (`partidas`). Every item exposes a common
/// [activityAt] + [fromParticipant] signal so the notifier can order the
/// timeline by the most recent interaction — either by another participant
/// (`fromParticipant == true`) or by the system (`false`).
///
/// Deliberately a plain sealed hierarchy (no build_runner): the feed payload
/// is small and the variants carry existing model types.
sealed class FeedItem {
  const FeedItem();

  /// Stable identity (`event:<id>` / `minigame:<id>`).
  String get id;

  /// The user-facing title.
  String get title;

  /// When the item last saw meaningful activity.
  DateTime get activityAt;

  /// True when the latest activity came from another participant (a pending
  /// invite, a new match state); false for system-generated items.
  bool get fromParticipant;

  /// JSON round-trip for the on-device cache (user-id-keyed Hive box).
  Map<String, dynamic> toJson();

  static FeedItem? fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'event':
        final event = json['event'];
        if (event is Map) {
          return FeedEventItem(
            event: Event.fromJson(Map<String, dynamic>.from(event)),
            activityAt: _parseDate(json['activity_at']),
            fromParticipant: json['from_participant'] == true,
          );
        }
        return null;
      case 'minigame':
        final session = json['session'];
        if (session is Map) {
          return FeedMinigameItem(
            session: Map<String, dynamic>.from(session),
            activityAt: _parseDate(json['activity_at']),
            fromParticipant: json['from_participant'] == true,
          );
        }
        return null;
      default:
        return null;
    }
  }

  static DateTime _parseDate(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

/// A public event surfaced in the feed.
class FeedEventItem extends FeedItem {
  final Event event;
  @override
  final DateTime activityAt;
  @override
  final bool fromParticipant;

  const FeedEventItem({
    required this.event,
    required this.activityAt,
    this.fromParticipant = false,
  });

  @override
  String get id => 'event:${event.id}';

  @override
  String get title => event.name;

  @override
  Map<String, dynamic> toJson() => {
    'kind': 'event',
    'activity_at': activityAt.toIso8601String(),
    'from_participant': fromParticipant,
    'event': event.toJson(),
  };
}

/// One of the user's minigame matches surfaced in the feed.
class FeedMinigameItem extends FeedItem {
  final Map<String, dynamic> session;
  @override
  final DateTime activityAt;
  @override
  final bool fromParticipant;

  const FeedMinigameItem({
    required this.session,
    required this.activityAt,
    this.fromParticipant = false,
  });

  @override
  String get id => 'minigame:${session['id']}';

  @override
  String get title {
    final name = (session['name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final auto = (session['auto_name'] as String?)?.trim() ?? '';
    if (auto.isNotEmpty) return auto;
    return (session['id'] as String?) ?? '';
  }

  String get gameType => (session['game_type'] as String?) ?? '';

  String get status => (session['status'] as String?) ?? 'active';

  int get participantCount =>
      (session['participants'] as List?)?.length ?? 0;

  @override
  Map<String, dynamic> toJson() => {
    'kind': 'minigame',
    'activity_at': activityAt.toIso8601String(),
    'from_participant': fromParticipant,
    'session': session,
  };
}
