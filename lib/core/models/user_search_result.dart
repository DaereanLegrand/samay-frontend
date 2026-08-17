import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_search_result.freezed.dart';
part 'user_search_result.g.dart';

@freezed
abstract class UserSearchResult with _$UserSearchResult {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory UserSearchResult({
    required String id,
    required String username,
    String? avatarUrl,
    String? friendshipStatus,
    String? friendshipId,
    String? friendshipDirection,
  }) = _UserSearchResult;

  factory UserSearchResult.fromJson(Map<String, dynamic> json) =>
      _$UserSearchResultFromJson(json);
}
