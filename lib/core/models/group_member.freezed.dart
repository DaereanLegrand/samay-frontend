// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GroupMember {

 String get id; String get groupId; String get userId; String get role; String get status; DateTime get joinedAt;@JsonKey(name: 'users') Map<String, dynamic>? get users;
/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupMemberCopyWith<GroupMember> get copyWith => _$GroupMemberCopyWithImpl<GroupMember>(this as GroupMember, _$identity);

  /// Serializes this GroupMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupMember&&(identical(other.id, id) || other.id == id)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&const DeepCollectionEquality().equals(other.users, users));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,groupId,userId,role,status,joinedAt,const DeepCollectionEquality().hash(users));

@override
String toString() {
  return 'GroupMember(id: $id, groupId: $groupId, userId: $userId, role: $role, status: $status, joinedAt: $joinedAt, users: $users)';
}


}

/// @nodoc
abstract mixin class $GroupMemberCopyWith<$Res>  {
  factory $GroupMemberCopyWith(GroupMember value, $Res Function(GroupMember) _then) = _$GroupMemberCopyWithImpl;
@useResult
$Res call({
 String id, String groupId, String userId, String role, String status, DateTime joinedAt,@JsonKey(name: 'users') Map<String, dynamic>? users
});




}
/// @nodoc
class _$GroupMemberCopyWithImpl<$Res>
    implements $GroupMemberCopyWith<$Res> {
  _$GroupMemberCopyWithImpl(this._self, this._then);

  final GroupMember _self;
  final $Res Function(GroupMember) _then;

/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? groupId = null,Object? userId = null,Object? role = null,Object? status = null,Object? joinedAt = null,Object? users = freezed,}) {
  return _then(GroupMember(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,users: freezed == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupMember].
extension GroupMemberPatterns on GroupMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupMember value)  $default,){
final _that = this;
switch (_that) {
case _GroupMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupMember value)?  $default,){
final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String groupId,  String userId,  String role,  String status,  DateTime joinedAt, @JsonKey(name: 'users')  Map<String, dynamic>? users)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
return $default(_that.id,_that.groupId,_that.userId,_that.role,_that.status,_that.joinedAt,_that.users);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String groupId,  String userId,  String role,  String status,  DateTime joinedAt, @JsonKey(name: 'users')  Map<String, dynamic>? users)  $default,) {final _that = this;
switch (_that) {
case _GroupMember():
return $default(_that.id,_that.groupId,_that.userId,_that.role,_that.status,_that.joinedAt,_that.users);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String groupId,  String userId,  String role,  String status,  DateTime joinedAt, @JsonKey(name: 'users')  Map<String, dynamic>? users)?  $default,) {final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
return $default(_that.id,_that.groupId,_that.userId,_that.role,_that.status,_that.joinedAt,_that.users);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _GroupMember extends GroupMember {
  const _GroupMember({required this.id, required this.groupId, required this.userId, this.role = 'member', this.status = 'active', required this.joinedAt, @JsonKey(name: 'users')  Map<String, dynamic>? users}): _users = users,super._();
  factory _GroupMember.fromJson(Map<String, dynamic> json) => _$GroupMemberFromJson(json);

@override final  String id;
@override final  String groupId;
@override final  String userId;
@override@JsonKey() final  String role;
@override@JsonKey() final  String status;
@override final  DateTime joinedAt;
 final  Map<String, dynamic>? _users;
@override@JsonKey(name: 'users') Map<String, dynamic>? get users {
  final value = _users;
  if (value == null) return null;
  if (_users is EqualUnmodifiableMapView) return _users;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupMemberCopyWith<_GroupMember> get copyWith => __$GroupMemberCopyWithImpl<_GroupMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupMemberToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupMember&&(identical(other.id, id) || other.id == id)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&const DeepCollectionEquality().equals(other._users, _users));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,groupId,userId,role,status,joinedAt,const DeepCollectionEquality().hash(_users));

@override
String toString() {
  return 'GroupMember(id: $id, groupId: $groupId, userId: $userId, role: $role, status: $status, joinedAt: $joinedAt, users: $users)';
}


}

/// @nodoc
abstract mixin class _$GroupMemberCopyWith<$Res> implements $GroupMemberCopyWith<$Res> {
  factory _$GroupMemberCopyWith(_GroupMember value, $Res Function(_GroupMember) _then) = __$GroupMemberCopyWithImpl;
@override @useResult
$Res call({
 String id, String groupId, String userId, String role, String status, DateTime joinedAt,@JsonKey(name: 'users') Map<String, dynamic>? users
});




}
/// @nodoc
class __$GroupMemberCopyWithImpl<$Res>
    implements _$GroupMemberCopyWith<$Res> {
  __$GroupMemberCopyWithImpl(this._self, this._then);

  final _GroupMember _self;
  final $Res Function(_GroupMember) _then;

/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? groupId = null,Object? userId = null,Object? role = null,Object? status = null,Object? joinedAt = null,Object? users = freezed,}) {
  return _then(_GroupMember(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,users: freezed == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
