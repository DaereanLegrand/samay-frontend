// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_request_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FriendRequestSummary {

 String get type; String get friendshipId; String get userId; DateTime? get createdAt;
/// Create a copy of FriendRequestSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendRequestSummaryCopyWith<FriendRequestSummary> get copyWith => _$FriendRequestSummaryCopyWithImpl<FriendRequestSummary>(this as FriendRequestSummary, _$identity);

  /// Serializes this FriendRequestSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendRequestSummary&&(identical(other.type, type) || other.type == type)&&(identical(other.friendshipId, friendshipId) || other.friendshipId == friendshipId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,friendshipId,userId,createdAt);

@override
String toString() {
  return 'FriendRequestSummary(type: $type, friendshipId: $friendshipId, userId: $userId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FriendRequestSummaryCopyWith<$Res>  {
  factory $FriendRequestSummaryCopyWith(FriendRequestSummary value, $Res Function(FriendRequestSummary) _then) = _$FriendRequestSummaryCopyWithImpl;
@useResult
$Res call({
 String type, String friendshipId, String userId, DateTime? createdAt
});




}
/// @nodoc
class _$FriendRequestSummaryCopyWithImpl<$Res>
    implements $FriendRequestSummaryCopyWith<$Res> {
  _$FriendRequestSummaryCopyWithImpl(this._self, this._then);

  final FriendRequestSummary _self;
  final $Res Function(FriendRequestSummary) _then;

/// Create a copy of FriendRequestSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? friendshipId = null,Object? userId = null,Object? createdAt = freezed,}) {
  return _then(FriendRequestSummary(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,friendshipId: null == friendshipId ? _self.friendshipId : friendshipId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FriendRequestSummary].
extension FriendRequestSummaryPatterns on FriendRequestSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FriendRequestSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FriendRequestSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FriendRequestSummary value)  $default,){
final _that = this;
switch (_that) {
case _FriendRequestSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FriendRequestSummary value)?  $default,){
final _that = this;
switch (_that) {
case _FriendRequestSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String friendshipId,  String userId,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FriendRequestSummary() when $default != null:
return $default(_that.type,_that.friendshipId,_that.userId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String friendshipId,  String userId,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _FriendRequestSummary():
return $default(_that.type,_that.friendshipId,_that.userId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String friendshipId,  String userId,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FriendRequestSummary() when $default != null:
return $default(_that.type,_that.friendshipId,_that.userId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _FriendRequestSummary implements FriendRequestSummary {
  const _FriendRequestSummary({required this.type, required this.friendshipId, required this.userId, this.createdAt});
  factory _FriendRequestSummary.fromJson(Map<String, dynamic> json) => _$FriendRequestSummaryFromJson(json);

@override final  String type;
@override final  String friendshipId;
@override final  String userId;
@override final  DateTime? createdAt;

/// Create a copy of FriendRequestSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FriendRequestSummaryCopyWith<_FriendRequestSummary> get copyWith => __$FriendRequestSummaryCopyWithImpl<_FriendRequestSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FriendRequestSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FriendRequestSummary&&(identical(other.type, type) || other.type == type)&&(identical(other.friendshipId, friendshipId) || other.friendshipId == friendshipId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,friendshipId,userId,createdAt);

@override
String toString() {
  return 'FriendRequestSummary(type: $type, friendshipId: $friendshipId, userId: $userId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FriendRequestSummaryCopyWith<$Res> implements $FriendRequestSummaryCopyWith<$Res> {
  factory _$FriendRequestSummaryCopyWith(_FriendRequestSummary value, $Res Function(_FriendRequestSummary) _then) = __$FriendRequestSummaryCopyWithImpl;
@override @useResult
$Res call({
 String type, String friendshipId, String userId, DateTime? createdAt
});




}
/// @nodoc
class __$FriendRequestSummaryCopyWithImpl<$Res>
    implements _$FriendRequestSummaryCopyWith<$Res> {
  __$FriendRequestSummaryCopyWithImpl(this._self, this._then);

  final _FriendRequestSummary _self;
  final $Res Function(_FriendRequestSummary) _then;

/// Create a copy of FriendRequestSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? friendshipId = null,Object? userId = null,Object? createdAt = freezed,}) {
  return _then(_FriendRequestSummary(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,friendshipId: null == friendshipId ? _self.friendshipId : friendshipId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
