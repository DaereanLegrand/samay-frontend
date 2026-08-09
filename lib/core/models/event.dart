import 'package:freezed_annotation/freezed_annotation.dart';

part 'event.freezed.dart';
part 'event.g.dart';

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
    String? groupId,
    String? locationName,
    @Default(0) int preshardsPool,
  }) = _Event;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
}
