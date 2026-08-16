import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';
part 'group.g.dart';

@freezed
abstract class Group with _$Group {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Group({
    required String id,
    required String name,
    String? description,
    String? coverUrl,
    @Default(0) int groupShards,
    String? sizeTier,
    String? rankBracket,
    DateTime? frozenAt,
    String? myRole,
    /// ISSUE 2: the caller's own membership status (`active`/`invited`),
    /// attached by `GroupService.getMyGroups` alongside `my_role`.
    String? myStatus,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}
