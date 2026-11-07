// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_theme.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GroupTheme _$GroupThemeFromJson(Map<String, dynamic> json) => _GroupTheme(
  groupId: json['group_id'] as String,
  controlMode: json['control_mode'] as String,
  backgroundColor: json['background_color'] as String,
  accentColor: json['accent_color'] as String,
  foregroundColor: json['foreground_color'] as String,
  accentForegroundColor: json['accent_foreground_color'] as String,
  isHost: json['is_host'] as bool? ?? false,
  paletteTier: json['palette_tier'] as String? ?? 'free',
  palette:
      (json['palette'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  canChangeColor: json['can_change_color'] as bool? ?? false,
  canChangeControl: json['can_change_control'] as bool? ?? false,
);

Map<String, dynamic> _$GroupThemeToJson(_GroupTheme instance) =>
    <String, dynamic>{
      'group_id': instance.groupId,
      'control_mode': instance.controlMode,
      'background_color': instance.backgroundColor,
      'accent_color': instance.accentColor,
      'foreground_color': instance.foregroundColor,
      'accent_foreground_color': instance.accentForegroundColor,
      'is_host': instance.isHost,
      'palette_tier': instance.paletteTier,
      'palette': instance.palette,
      'can_change_color': instance.canChangeColor,
      'can_change_control': instance.canChangeControl,
    };
