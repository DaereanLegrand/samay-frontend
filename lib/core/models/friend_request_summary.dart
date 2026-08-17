import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_request_summary.freezed.dart';
part 'friend_request_summary.g.dart';

@freezed
abstract class FriendRequestSummary with _$FriendRequestSummary {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory FriendRequestSummary({
    required String type,
    required String friendshipId,
    required String userId,
    DateTime? createdAt,
  }) = _FriendRequestSummary;

  factory FriendRequestSummary.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestSummaryFromJson(json);
}
