import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_theme.freezed.dart';
part 'group_theme.g.dart';

/// E4 group theme — the host-owned palette returned by `get_group_theme`.
///
/// `controlMode` is `everyone` | `host_only` | `locked`; the colours are
/// `#RRGGBB` strings. `foregroundColor` / `accentForegroundColor` are derived
/// server-side to meet WCAG AA against their backgrounds.
///
/// The host's tier gates the palette: `free` groups are fixed black (and
/// default `locked`), Pro/VIP may pick RGB. `palette` carries the colours the
/// caller is currently allowed to pick.
@freezed
abstract class GroupTheme with _$GroupTheme {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory GroupTheme({
    required String groupId,
    required String controlMode,
    required String backgroundColor,
    required String accentColor,
    required String foregroundColor,
    required String accentForegroundColor,
    @Default(false) bool isHost,
    @Default('free') String paletteTier,
    @Default(<String>[]) List<String> palette,
    @Default(false) bool canChangeColor,
    @Default(false) bool canChangeControl,
  }) = _GroupTheme;

  factory GroupTheme.fromJson(Map<String, dynamic> json) =>
      _$GroupThemeFromJson(json);
}
