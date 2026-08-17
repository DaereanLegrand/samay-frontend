// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserSearchResult {

 String get id; String get username; String? get avatarUrl; String? get friendshipStatus; String? get friendshipId; String? get friendshipDirection;
/// Create a copy of UserSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSearchResultCopyWith<UserSearchResult> get copyWith => _$UserSearchResultCopyWithImpl<UserSearchResult>(this as UserSearchResult, _$identity);

  /// Serializes this UserSearchResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSearchResult&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.friendshipStatus, friendshipStatus) || other.friendshipStatus == friendshipStatus)&&(identical(other.friendshipId, friendshipId) || other.friendshipId == friendshipId)&&(identical(other.friendshipDirection, friendshipDirection) || other.friendshipDirection == friendshipDirection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,avatarUrl,friendshipStatus,friendshipId,friendshipDirection);

@override
String toString() {
  return 'UserSearchResult(id: $id, username: $username, avatarUrl: $avatarUrl, friendshipStatus: $friendshipStatus, friendshipId: $friendshipId, friendshipDirection: $friendshipDirection)';
}


}

/// @nodoc
abstract mixin class $UserSearchResultCopyWith<$Res>  {
  factory $UserSearchResultCopyWith(UserSearchResult value, $Res Function(UserSearchResult) _then) = _$UserSearchResultCopyWithImpl;
@useResult
$Res call({
 String id, String username, String? avatarUrl, String? friendshipStatus, String? friendshipId, String? friendshipDirection
});




}
/// @nodoc
class _$UserSearchResultCopyWithImpl<$Res>
    implements $UserSearchResultCopyWith<$Res> {
  _$UserSearchResultCopyWithImpl(this._self, this._then);

  final UserSearchResult _self;
  final $Res Function(UserSearchResult) _then;

/// Create a copy of UserSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? avatarUrl = freezed,Object? friendshipStatus = freezed,Object? friendshipId = freezed,Object? friendshipDirection = freezed,}) {
  return _then(UserSearchResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,friendshipStatus: freezed == friendshipStatus ? _self.friendshipStatus : friendshipStatus // ignore: cast_nullable_to_non_nullable
as String?,friendshipId: freezed == friendshipId ? _self.friendshipId : friendshipId // ignore: cast_nullable_to_non_nullable
as String?,friendshipDirection: freezed == friendshipDirection ? _self.friendshipDirection : friendshipDirection // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserSearchResult].
extension UserSearchResultPatterns on UserSearchResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserSearchResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserSearchResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserSearchResult value)  $default,){
final _that = this;
switch (_that) {
case _UserSearchResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserSearchResult value)?  $default,){
final _that = this;
switch (_that) {
case _UserSearchResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String? avatarUrl,  String? friendshipStatus,  String? friendshipId,  String? friendshipDirection)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSearchResult() when $default != null:
return $default(_that.id,_that.username,_that.avatarUrl,_that.friendshipStatus,_that.friendshipId,_that.friendshipDirection);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String? avatarUrl,  String? friendshipStatus,  String? friendshipId,  String? friendshipDirection)  $default,) {final _that = this;
switch (_that) {
case _UserSearchResult():
return $default(_that.id,_that.username,_that.avatarUrl,_that.friendshipStatus,_that.friendshipId,_that.friendshipDirection);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String? avatarUrl,  String? friendshipStatus,  String? friendshipId,  String? friendshipDirection)?  $default,) {final _that = this;
switch (_that) {
case _UserSearchResult() when $default != null:
return $default(_that.id,_that.username,_that.avatarUrl,_that.friendshipStatus,_that.friendshipId,_that.friendshipDirection);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _UserSearchResult implements UserSearchResult {
  const _UserSearchResult({required this.id, required this.username, this.avatarUrl, this.friendshipStatus, this.friendshipId, this.friendshipDirection});
  factory _UserSearchResult.fromJson(Map<String, dynamic> json) => _$UserSearchResultFromJson(json);

@override final  String id;
@override final  String username;
@override final  String? avatarUrl;
@override final  String? friendshipStatus;
@override final  String? friendshipId;
@override final  String? friendshipDirection;

/// Create a copy of UserSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserSearchResultCopyWith<_UserSearchResult> get copyWith => __$UserSearchResultCopyWithImpl<_UserSearchResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserSearchResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserSearchResult&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.friendshipStatus, friendshipStatus) || other.friendshipStatus == friendshipStatus)&&(identical(other.friendshipId, friendshipId) || other.friendshipId == friendshipId)&&(identical(other.friendshipDirection, friendshipDirection) || other.friendshipDirection == friendshipDirection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,avatarUrl,friendshipStatus,friendshipId,friendshipDirection);

@override
String toString() {
  return 'UserSearchResult(id: $id, username: $username, avatarUrl: $avatarUrl, friendshipStatus: $friendshipStatus, friendshipId: $friendshipId, friendshipDirection: $friendshipDirection)';
}


}

/// @nodoc
abstract mixin class _$UserSearchResultCopyWith<$Res> implements $UserSearchResultCopyWith<$Res> {
  factory _$UserSearchResultCopyWith(_UserSearchResult value, $Res Function(_UserSearchResult) _then) = __$UserSearchResultCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String? avatarUrl, String? friendshipStatus, String? friendshipId, String? friendshipDirection
});




}
/// @nodoc
class __$UserSearchResultCopyWithImpl<$Res>
    implements _$UserSearchResultCopyWith<$Res> {
  __$UserSearchResultCopyWithImpl(this._self, this._then);

  final _UserSearchResult _self;
  final $Res Function(_UserSearchResult) _then;

/// Create a copy of UserSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? avatarUrl = freezed,Object? friendshipStatus = freezed,Object? friendshipId = freezed,Object? friendshipDirection = freezed,}) {
  return _then(_UserSearchResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,friendshipStatus: freezed == friendshipStatus ? _self.friendshipStatus : friendshipStatus // ignore: cast_nullable_to_non_nullable
as String?,friendshipId: freezed == friendshipId ? _self.friendshipId : friendshipId // ignore: cast_nullable_to_non_nullable
as String?,friendshipDirection: freezed == friendshipDirection ? _self.friendshipDirection : friendshipDirection // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
