import 'package:freezed_annotation/freezed_annotation.dart';

part 'event.freezed.dart';
part 'event.g.dart';

/// Numeric-safe decode for PostgREST `numeric` columns that may arrive as a
/// JSON number or a string (`location_lat` / `location_lng`).
double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Event lifecycle model. [featured] pins promoted events to the top
/// of the feed (FEED/FEET, admin `samay events feature`); [coverUrl] is the
/// event cover used by the feed cards and detail header. [locationLat] /
/// [locationLng] drive the client-side distance rendering of the Events tab's
/// km filter (the filtering itself is server-side via `search_events`).
@freezed
abstract class Event with _$Event {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Event({
    required String id,
    required String name,
    required String type,
    required String status,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
    String? groupId,
    String? locationName,
    @JsonKey(fromJson: _asDouble) double? locationLat,
    @JsonKey(fromJson: _asDouble) double? locationLng,
    String? coverUrl,
    String? createdByUserId,
    String? joinMode,
    @Default(false) bool featured,
    @Default(false) bool preshardsDistributed,
    @Default(0) int preshardsPool,
    @Default(0) int capacity,
    int? preshardsCapPerUser,
    String? preshardsRemainderAction,
  }) = _Event;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
}
