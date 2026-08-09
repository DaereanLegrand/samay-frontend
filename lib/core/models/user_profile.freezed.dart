// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserProfile {

 String get id; String get username; String? get avatarUrl; String? get bio; int get personalShards; int get preshards; String get subscriptionTier; DateTime? get deletedAt; DateTime? get dateOfBirth;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);

  /// Serializes this UserProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.personalShards, personalShards) || other.personalShards == personalShards)&&(identical(other.preshards, preshards) || other.preshards == preshards)&&(identical(other.subscriptionTier, subscriptionTier) || other.subscriptionTier == subscriptionTier)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,avatarUrl,bio,personalShards,preshards,subscriptionTier,deletedAt,dateOfBirth);

@override
String toString() {
  return 'UserProfile(id: $id, username: $username, avatarUrl: $avatarUrl, bio: $bio, personalShards: $personalShards, preshards: $preshards, subscriptionTier: $subscriptionTier, deletedAt: $deletedAt, dateOfBirth: $dateOfBirth)';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 String id, String username, String? avatarUrl, String? bio, int personalShards, int preshards, String subscriptionTier, DateTime? deletedAt, DateTime? dateOfBirth
});




}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? personalShards = null,Object? preshards = null,Object? subscriptionTier = null,Object? deletedAt = freezed,Object? dateOfBirth = freezed,}) {
  return _then(UserProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,personalShards: null == personalShards ? _self.personalShards : personalShards // ignore: cast_nullable_to_non_nullable
as int,preshards: null == preshards ? _self.preshards : preshards // ignore: cast_nullable_to_non_nullable
as int,subscriptionTier: null == subscriptionTier ? _self.subscriptionTier : subscriptionTier // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String? avatarUrl,  String? bio,  int personalShards,  int preshards,  String subscriptionTier,  DateTime? deletedAt,  DateTime? dateOfBirth)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.username,_that.avatarUrl,_that.bio,_that.personalShards,_that.preshards,_that.subscriptionTier,_that.deletedAt,_that.dateOfBirth);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String? avatarUrl,  String? bio,  int personalShards,  int preshards,  String subscriptionTier,  DateTime? deletedAt,  DateTime? dateOfBirth)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.id,_that.username,_that.avatarUrl,_that.bio,_that.personalShards,_that.preshards,_that.subscriptionTier,_that.deletedAt,_that.dateOfBirth);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String? avatarUrl,  String? bio,  int personalShards,  int preshards,  String subscriptionTier,  DateTime? deletedAt,  DateTime? dateOfBirth)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.username,_that.avatarUrl,_that.bio,_that.personalShards,_that.preshards,_that.subscriptionTier,_that.deletedAt,_that.dateOfBirth);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _UserProfile implements UserProfile {
  const _UserProfile({required this.id, required this.username, this.avatarUrl, this.bio, this.personalShards = 0, this.preshards = 0, this.subscriptionTier = 'free', this.deletedAt, this.dateOfBirth});
  factory _UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

@override final  String id;
@override final  String username;
@override final  String? avatarUrl;
@override final  String? bio;
@override@JsonKey() final  int personalShards;
@override@JsonKey() final  int preshards;
@override@JsonKey() final  String subscriptionTier;
@override final  DateTime? deletedAt;
@override final  DateTime? dateOfBirth;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.personalShards, personalShards) || other.personalShards == personalShards)&&(identical(other.preshards, preshards) || other.preshards == preshards)&&(identical(other.subscriptionTier, subscriptionTier) || other.subscriptionTier == subscriptionTier)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,avatarUrl,bio,personalShards,preshards,subscriptionTier,deletedAt,dateOfBirth);

@override
String toString() {
  return 'UserProfile(id: $id, username: $username, avatarUrl: $avatarUrl, bio: $bio, personalShards: $personalShards, preshards: $preshards, subscriptionTier: $subscriptionTier, deletedAt: $deletedAt, dateOfBirth: $dateOfBirth)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String? avatarUrl, String? bio, int personalShards, int preshards, String subscriptionTier, DateTime? deletedAt, DateTime? dateOfBirth
});




}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? personalShards = null,Object? preshards = null,Object? subscriptionTier = null,Object? deletedAt = freezed,Object? dateOfBirth = freezed,}) {
  return _then(_UserProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,personalShards: null == personalShards ? _self.personalShards : personalShards // ignore: cast_nullable_to_non_nullable
as int,preshards: null == preshards ? _self.preshards : preshards // ignore: cast_nullable_to_non_nullable
as int,subscriptionTier: null == subscriptionTier ? _self.subscriptionTier : subscriptionTier // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
