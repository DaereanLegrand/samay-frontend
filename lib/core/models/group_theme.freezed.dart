// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_theme.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GroupTheme {

 String get groupId; String get controlMode; String get backgroundColor; String get accentColor; String get foregroundColor; String get accentForegroundColor; bool get isHost; String get paletteTier; List<String> get palette; bool get canChangeColor; bool get canChangeControl;
/// Create a copy of GroupTheme
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupThemeCopyWith<GroupTheme> get copyWith => _$GroupThemeCopyWithImpl<GroupTheme>(this as GroupTheme, _$identity);

  /// Serializes this GroupTheme to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupTheme&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.controlMode, controlMode) || other.controlMode == controlMode)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.accentColor, accentColor) || other.accentColor == accentColor)&&(identical(other.foregroundColor, foregroundColor) || other.foregroundColor == foregroundColor)&&(identical(other.accentForegroundColor, accentForegroundColor) || other.accentForegroundColor == accentForegroundColor)&&(identical(other.isHost, isHost) || other.isHost == isHost)&&(identical(other.paletteTier, paletteTier) || other.paletteTier == paletteTier)&&const DeepCollectionEquality().equals(other.palette, palette)&&(identical(other.canChangeColor, canChangeColor) || other.canChangeColor == canChangeColor)&&(identical(other.canChangeControl, canChangeControl) || other.canChangeControl == canChangeControl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,groupId,controlMode,backgroundColor,accentColor,foregroundColor,accentForegroundColor,isHost,paletteTier,const DeepCollectionEquality().hash(palette),canChangeColor,canChangeControl);

@override
String toString() {
  return 'GroupTheme(groupId: $groupId, controlMode: $controlMode, backgroundColor: $backgroundColor, accentColor: $accentColor, foregroundColor: $foregroundColor, accentForegroundColor: $accentForegroundColor, isHost: $isHost, paletteTier: $paletteTier, palette: $palette, canChangeColor: $canChangeColor, canChangeControl: $canChangeControl)';
}


}

/// @nodoc
abstract mixin class $GroupThemeCopyWith<$Res>  {
  factory $GroupThemeCopyWith(GroupTheme value, $Res Function(GroupTheme) _then) = _$GroupThemeCopyWithImpl;
@useResult
$Res call({
 String groupId, String controlMode, String backgroundColor, String accentColor, String foregroundColor, String accentForegroundColor, bool isHost, String paletteTier, List<String> palette, bool canChangeColor, bool canChangeControl
});




}
/// @nodoc
class _$GroupThemeCopyWithImpl<$Res>
    implements $GroupThemeCopyWith<$Res> {
  _$GroupThemeCopyWithImpl(this._self, this._then);

  final GroupTheme _self;
  final $Res Function(GroupTheme) _then;

/// Create a copy of GroupTheme
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupId = null,Object? controlMode = null,Object? backgroundColor = null,Object? accentColor = null,Object? foregroundColor = null,Object? accentForegroundColor = null,Object? isHost = null,Object? paletteTier = null,Object? palette = null,Object? canChangeColor = null,Object? canChangeControl = null,}) {
  return _then(GroupTheme(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,controlMode: null == controlMode ? _self.controlMode : controlMode // ignore: cast_nullable_to_non_nullable
as String,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as String,accentColor: null == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as String,foregroundColor: null == foregroundColor ? _self.foregroundColor : foregroundColor // ignore: cast_nullable_to_non_nullable
as String,accentForegroundColor: null == accentForegroundColor ? _self.accentForegroundColor : accentForegroundColor // ignore: cast_nullable_to_non_nullable
as String,isHost: null == isHost ? _self.isHost : isHost // ignore: cast_nullable_to_non_nullable
as bool,paletteTier: null == paletteTier ? _self.paletteTier : paletteTier // ignore: cast_nullable_to_non_nullable
as String,palette: null == palette ? _self.palette : palette // ignore: cast_nullable_to_non_nullable
as List<String>,canChangeColor: null == canChangeColor ? _self.canChangeColor : canChangeColor // ignore: cast_nullable_to_non_nullable
as bool,canChangeControl: null == canChangeControl ? _self.canChangeControl : canChangeControl // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupTheme].
extension GroupThemePatterns on GroupTheme {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupTheme value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupTheme() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupTheme value)  $default,){
final _that = this;
switch (_that) {
case _GroupTheme():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupTheme value)?  $default,){
final _that = this;
switch (_that) {
case _GroupTheme() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String groupId,  String controlMode,  String backgroundColor,  String accentColor,  String foregroundColor,  String accentForegroundColor,  bool isHost,  String paletteTier,  List<String> palette,  bool canChangeColor,  bool canChangeControl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupTheme() when $default != null:
return $default(_that.groupId,_that.controlMode,_that.backgroundColor,_that.accentColor,_that.foregroundColor,_that.accentForegroundColor,_that.isHost,_that.paletteTier,_that.palette,_that.canChangeColor,_that.canChangeControl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String groupId,  String controlMode,  String backgroundColor,  String accentColor,  String foregroundColor,  String accentForegroundColor,  bool isHost,  String paletteTier,  List<String> palette,  bool canChangeColor,  bool canChangeControl)  $default,) {final _that = this;
switch (_that) {
case _GroupTheme():
return $default(_that.groupId,_that.controlMode,_that.backgroundColor,_that.accentColor,_that.foregroundColor,_that.accentForegroundColor,_that.isHost,_that.paletteTier,_that.palette,_that.canChangeColor,_that.canChangeControl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String groupId,  String controlMode,  String backgroundColor,  String accentColor,  String foregroundColor,  String accentForegroundColor,  bool isHost,  String paletteTier,  List<String> palette,  bool canChangeColor,  bool canChangeControl)?  $default,) {final _that = this;
switch (_that) {
case _GroupTheme() when $default != null:
return $default(_that.groupId,_that.controlMode,_that.backgroundColor,_that.accentColor,_that.foregroundColor,_that.accentForegroundColor,_that.isHost,_that.paletteTier,_that.palette,_that.canChangeColor,_that.canChangeControl);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _GroupTheme implements GroupTheme {
  const _GroupTheme({required this.groupId, required this.controlMode, required this.backgroundColor, required this.accentColor, required this.foregroundColor, required this.accentForegroundColor, this.isHost = false, this.paletteTier = 'free',  List<String> palette = const <String>[], this.canChangeColor = false, this.canChangeControl = false}): _palette = palette;
  factory _GroupTheme.fromJson(Map<String, dynamic> json) => _$GroupThemeFromJson(json);

@override final  String groupId;
@override final  String controlMode;
@override final  String backgroundColor;
@override final  String accentColor;
@override final  String foregroundColor;
@override final  String accentForegroundColor;
@override@JsonKey() final  bool isHost;
@override@JsonKey() final  String paletteTier;
 final  List<String> _palette;
@override@JsonKey() List<String> get palette {
  if (_palette is EqualUnmodifiableListView) return _palette;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_palette);
}

@override@JsonKey() final  bool canChangeColor;
@override@JsonKey() final  bool canChangeControl;

/// Create a copy of GroupTheme
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupThemeCopyWith<_GroupTheme> get copyWith => __$GroupThemeCopyWithImpl<_GroupTheme>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupThemeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupTheme&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.controlMode, controlMode) || other.controlMode == controlMode)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.accentColor, accentColor) || other.accentColor == accentColor)&&(identical(other.foregroundColor, foregroundColor) || other.foregroundColor == foregroundColor)&&(identical(other.accentForegroundColor, accentForegroundColor) || other.accentForegroundColor == accentForegroundColor)&&(identical(other.isHost, isHost) || other.isHost == isHost)&&(identical(other.paletteTier, paletteTier) || other.paletteTier == paletteTier)&&const DeepCollectionEquality().equals(other._palette, _palette)&&(identical(other.canChangeColor, canChangeColor) || other.canChangeColor == canChangeColor)&&(identical(other.canChangeControl, canChangeControl) || other.canChangeControl == canChangeControl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,groupId,controlMode,backgroundColor,accentColor,foregroundColor,accentForegroundColor,isHost,paletteTier,const DeepCollectionEquality().hash(_palette),canChangeColor,canChangeControl);

@override
String toString() {
  return 'GroupTheme(groupId: $groupId, controlMode: $controlMode, backgroundColor: $backgroundColor, accentColor: $accentColor, foregroundColor: $foregroundColor, accentForegroundColor: $accentForegroundColor, isHost: $isHost, paletteTier: $paletteTier, palette: $palette, canChangeColor: $canChangeColor, canChangeControl: $canChangeControl)';
}


}

/// @nodoc
abstract mixin class _$GroupThemeCopyWith<$Res> implements $GroupThemeCopyWith<$Res> {
  factory _$GroupThemeCopyWith(_GroupTheme value, $Res Function(_GroupTheme) _then) = __$GroupThemeCopyWithImpl;
@override @useResult
$Res call({
 String groupId, String controlMode, String backgroundColor, String accentColor, String foregroundColor, String accentForegroundColor, bool isHost, String paletteTier, List<String> palette, bool canChangeColor, bool canChangeControl
});




}
/// @nodoc
class __$GroupThemeCopyWithImpl<$Res>
    implements _$GroupThemeCopyWith<$Res> {
  __$GroupThemeCopyWithImpl(this._self, this._then);

  final _GroupTheme _self;
  final $Res Function(_GroupTheme) _then;

/// Create a copy of GroupTheme
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groupId = null,Object? controlMode = null,Object? backgroundColor = null,Object? accentColor = null,Object? foregroundColor = null,Object? accentForegroundColor = null,Object? isHost = null,Object? paletteTier = null,Object? palette = null,Object? canChangeColor = null,Object? canChangeControl = null,}) {
  return _then(_GroupTheme(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,controlMode: null == controlMode ? _self.controlMode : controlMode // ignore: cast_nullable_to_non_nullable
as String,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as String,accentColor: null == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as String,foregroundColor: null == foregroundColor ? _self.foregroundColor : foregroundColor // ignore: cast_nullable_to_non_nullable
as String,accentForegroundColor: null == accentForegroundColor ? _self.accentForegroundColor : accentForegroundColor // ignore: cast_nullable_to_non_nullable
as String,isHost: null == isHost ? _self.isHost : isHost // ignore: cast_nullable_to_non_nullable
as bool,paletteTier: null == paletteTier ? _self.paletteTier : paletteTier // ignore: cast_nullable_to_non_nullable
as String,palette: null == palette ? _self._palette : palette // ignore: cast_nullable_to_non_nullable
as List<String>,canChangeColor: null == canChangeColor ? _self.canChangeColor : canChangeColor // ignore: cast_nullable_to_non_nullable
as bool,canChangeControl: null == canChangeControl ? _self.canChangeControl : canChangeControl // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
