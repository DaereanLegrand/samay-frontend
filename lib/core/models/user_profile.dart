import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
abstract class UserProfile with _$UserProfile {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory UserProfile({
    required String id,
    required String username,
    String? avatarUrl,
    String? bio,
    @Default(0) int personalShards,
    @Default(0) int preshards,
    @Default('free') String subscriptionTier,
    @Default('free') String entitlementTier,
    DateTime? deletedAt,
    DateTime? dateOfBirth,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
