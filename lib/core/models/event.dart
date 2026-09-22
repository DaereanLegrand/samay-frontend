import 'package:freezed_annotation/freezed_annotation.dart';

part 'event.freezed.dart';
part 'event.g.dart';

/// Event lifecycle model. [featured] pins promoted events to the top
/// of the feed (FEED/FEET, admin `samay events feature`); [coverUrl] is the
/// event cover used by the feed cards and detail header.
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
