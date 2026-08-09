import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_item.freezed.dart';
part 'notification_item.g.dart';

@freezed
abstract class NotificationItem with _$NotificationItem {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NotificationItem({
    required String id,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    @Default(false) bool read,
    required DateTime createdAt,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}
