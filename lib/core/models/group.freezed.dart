// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Group {

 String get id; String get name; String? get description; String? get coverUrl; int get groupShards;/// Active member count, attached by `GroupService.getMyGroups` (the
/// `groups` table carries no count column).
 int get memberCount; String? get sizeTier; String? get rankBracket; DateTime? get frozenAt; String? get myRole;/// the caller's own membership status (`active`/`invited`),
/// attached by `GroupService.getMyGroups` alongside `my_role`.
 String? get myStatus;
/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupCopyWith<Group> get copyWith => _$GroupCopyWithImpl<Group>(this as Group, _$identity);

  /// Serializes this Group to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Group&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.groupShards, groupShards) || other.groupShards == groupShards)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.sizeTier, sizeTier) || other.sizeTier == sizeTier)&&(identical(other.rankBracket, rankBracket) || other.rankBracket == rankBracket)&&(identical(other.frozenAt, frozenAt) || other.frozenAt == frozenAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.myStatus, myStatus) || other.myStatus == myStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,coverUrl,groupShards,memberCount,sizeTier,rankBracket,frozenAt,myRole,myStatus);

@override
String toString() {
  return 'Group(id: $id, name: $name, description: $description, coverUrl: $coverUrl, groupShards: $groupShards, memberCount: $memberCount, sizeTier: $sizeTier, rankBracket: $rankBracket, frozenAt: $frozenAt, myRole: $myRole, myStatus: $myStatus)';
}


}

/// @nodoc
abstract mixin class $GroupCopyWith<$Res>  {
  factory $GroupCopyWith(Group value, $Res Function(Group) _then) = _$GroupCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, String? coverUrl, int groupShards, int memberCount, String? sizeTier, String? rankBracket, DateTime? frozenAt, String? myRole, String? myStatus
});




}
/// @nodoc
class _$GroupCopyWithImpl<$Res>
    implements $GroupCopyWith<$Res> {
  _$GroupCopyWithImpl(this._self, this._then);

  final Group _self;
  final $Res Function(Group) _then;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? coverUrl = freezed,Object? groupShards = null,Object? memberCount = null,Object? sizeTier = freezed,Object? rankBracket = freezed,Object? frozenAt = freezed,Object? myRole = freezed,Object? myStatus = freezed,}) {
  return _then(Group(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,groupShards: null == groupShards ? _self.groupShards : groupShards // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,sizeTier: freezed == sizeTier ? _self.sizeTier : sizeTier // ignore: cast_nullable_to_non_nullable
as String?,rankBracket: freezed == rankBracket ? _self.rankBracket : rankBracket // ignore: cast_nullable_to_non_nullable
as String?,frozenAt: freezed == frozenAt ? _self.frozenAt : frozenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,myRole: freezed == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as String?,myStatus: freezed == myStatus ? _self.myStatus : myStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Group].
extension GroupPatterns on Group {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Group value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Group() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Group value)  $default,){
final _that = this;
switch (_that) {
case _Group():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Group value)?  $default,){
final _that = this;
switch (_that) {
case _Group() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  String? coverUrl,  int groupShards,  int memberCount,  String? sizeTier,  String? rankBracket,  DateTime? frozenAt,  String? myRole,  String? myStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Group() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.coverUrl,_that.groupShards,_that.memberCount,_that.sizeTier,_that.rankBracket,_that.frozenAt,_that.myRole,_that.myStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  String? coverUrl,  int groupShards,  int memberCount,  String? sizeTier,  String? rankBracket,  DateTime? frozenAt,  String? myRole,  String? myStatus)  $default,) {final _that = this;
switch (_that) {
case _Group():
return $default(_that.id,_that.name,_that.description,_that.coverUrl,_that.groupShards,_that.memberCount,_that.sizeTier,_that.rankBracket,_that.frozenAt,_that.myRole,_that.myStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  String? coverUrl,  int groupShards,  int memberCount,  String? sizeTier,  String? rankBracket,  DateTime? frozenAt,  String? myRole,  String? myStatus)?  $default,) {final _that = this;
switch (_that) {
case _Group() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.coverUrl,_that.groupShards,_that.memberCount,_that.sizeTier,_that.rankBracket,_that.frozenAt,_that.myRole,_that.myStatus);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _Group implements Group {
  const _Group({required this.id, required this.name, this.description, this.coverUrl, this.groupShards = 0, this.memberCount = 0, this.sizeTier, this.rankBracket, this.frozenAt, this.myRole, this.myStatus});
  factory _Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  String? coverUrl;
@override@JsonKey() final  int groupShards;
/// Active member count, attached by `GroupService.getMyGroups` (the
/// `groups` table carries no count column).
@override@JsonKey() final  int memberCount;
@override final  String? sizeTier;
@override final  String? rankBracket;
@override final  DateTime? frozenAt;
@override final  String? myRole;
/// the caller's own membership status (`active`/`invited`),
/// attached by `GroupService.getMyGroups` alongside `my_role`.
@override final  String? myStatus;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupCopyWith<_Group> get copyWith => __$GroupCopyWithImpl<_Group>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Group&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.groupShards, groupShards) || other.groupShards == groupShards)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.sizeTier, sizeTier) || other.sizeTier == sizeTier)&&(identical(other.rankBracket, rankBracket) || other.rankBracket == rankBracket)&&(identical(other.frozenAt, frozenAt) || other.frozenAt == frozenAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.myStatus, myStatus) || other.myStatus == myStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,coverUrl,groupShards,memberCount,sizeTier,rankBracket,frozenAt,myRole,myStatus);

@override
String toString() {
  return 'Group(id: $id, name: $name, description: $description, coverUrl: $coverUrl, groupShards: $groupShards, memberCount: $memberCount, sizeTier: $sizeTier, rankBracket: $rankBracket, frozenAt: $frozenAt, myRole: $myRole, myStatus: $myStatus)';
}


}

/// @nodoc
abstract mixin class _$GroupCopyWith<$Res> implements $GroupCopyWith<$Res> {
  factory _$GroupCopyWith(_Group value, $Res Function(_Group) _then) = __$GroupCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, String? coverUrl, int groupShards, int memberCount, String? sizeTier, String? rankBracket, DateTime? frozenAt, String? myRole, String? myStatus
});




}
/// @nodoc
class __$GroupCopyWithImpl<$Res>
    implements _$GroupCopyWith<$Res> {
  __$GroupCopyWithImpl(this._self, this._then);

  final _Group _self;
  final $Res Function(_Group) _then;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? coverUrl = freezed,Object? groupShards = null,Object? memberCount = null,Object? sizeTier = freezed,Object? rankBracket = freezed,Object? frozenAt = freezed,Object? myRole = freezed,Object? myStatus = freezed,}) {
  return _then(_Group(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,groupShards: null == groupShards ? _self.groupShards : groupShards // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,sizeTier: freezed == sizeTier ? _self.sizeTier : sizeTier // ignore: cast_nullable_to_non_nullable
as String?,rankBracket: freezed == rankBracket ? _self.rankBracket : rankBracket // ignore: cast_nullable_to_non_nullable
as String?,frozenAt: freezed == frozenAt ? _self.frozenAt : frozenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,myRole: freezed == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as String?,myStatus: freezed == myStatus ? _self.myStatus : myStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
