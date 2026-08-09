import 'package:freezed_annotation/freezed_annotation.dart';

part 'friendship.freezed.dart';
part 'friendship.g.dart';

@freezed
abstract class FriendshipSummary with _$FriendshipSummary {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory FriendshipSummary({
    required String friendshipId,
    required String userId,
    String? status,
  }) = _FriendshipSummary;

  factory FriendshipSummary.fromJson(Map<String, dynamic> json) =>
      _$FriendshipSummaryFromJson(json);
}
