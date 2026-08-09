// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friendship.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FriendshipSummary {

 String get friendshipId; String get userId; String? get status;
/// Create a copy of FriendshipSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendshipSummaryCopyWith<FriendshipSummary> get copyWith => _$FriendshipSummaryCopyWithImpl<FriendshipSummary>(this as FriendshipSummary, _$identity);

  /// Serializes this FriendshipSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendshipSummary&&(identical(other.friendshipId, friendshipId) || other.friendshipId == friendshipId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,friendshipId,userId,status);

@override
String toString() {
  return 'FriendshipSummary(friendshipId: $friendshipId, userId: $userId, status: $status)';
}


}

/// @nodoc
abstract mixin class $FriendshipSummaryCopyWith<$Res>  {
  factory $FriendshipSummaryCopyWith(FriendshipSummary value, $Res Function(FriendshipSummary) _then) = _$FriendshipSummaryCopyWithImpl;
@useResult
$Res call({
 String friendshipId, String userId, String? status
});




}
/// @nodoc
class _$FriendshipSummaryCopyWithImpl<$Res>
    implements $FriendshipSummaryCopyWith<$Res> {
  _$FriendshipSummaryCopyWithImpl(this._self, this._then);

  final FriendshipSummary _self;
  final $Res Function(FriendshipSummary) _then;

/// Create a copy of FriendshipSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? friendshipId = null,Object? userId = null,Object? status = freezed,}) {
  return _then(FriendshipSummary(
friendshipId: null == friendshipId ? _self.friendshipId : friendshipId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FriendshipSummary].
extension FriendshipSummaryPatterns on FriendshipSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FriendshipSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FriendshipSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FriendshipSummary value)  $default,){
final _that = this;
switch (_that) {
case _FriendshipSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FriendshipSummary value)?  $default,){
final _that = this;
switch (_that) {
case _FriendshipSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String friendshipId,  String userId,  String? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FriendshipSummary() when $default != null:
return $default(_that.friendshipId,_that.userId,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String friendshipId,  String userId,  String? status)  $default,) {final _that = this;
switch (_that) {
case _FriendshipSummary():
return $default(_that.friendshipId,_that.userId,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String friendshipId,  String userId,  String? status)?  $default,) {final _that = this;
switch (_that) {
case _FriendshipSummary() when $default != null:
return $default(_that.friendshipId,_that.userId,_that.status);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _FriendshipSummary implements FriendshipSummary {
  const _FriendshipSummary({required this.friendshipId, required this.userId, this.status});
  factory _FriendshipSummary.fromJson(Map<String, dynamic> json) => _$FriendshipSummaryFromJson(json);

@override final  String friendshipId;
@override final  String userId;
@override final  String? status;

/// Create a copy of FriendshipSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FriendshipSummaryCopyWith<_FriendshipSummary> get copyWith => __$FriendshipSummaryCopyWithImpl<_FriendshipSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FriendshipSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FriendshipSummary&&(identical(other.friendshipId, friendshipId) || other.friendshipId == friendshipId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,friendshipId,userId,status);

@override
String toString() {
  return 'FriendshipSummary(friendshipId: $friendshipId, userId: $userId, status: $status)';
}


}

/// @nodoc
abstract mixin class _$FriendshipSummaryCopyWith<$Res> implements $FriendshipSummaryCopyWith<$Res> {
  factory _$FriendshipSummaryCopyWith(_FriendshipSummary value, $Res Function(_FriendshipSummary) _then) = __$FriendshipSummaryCopyWithImpl;
@override @useResult
$Res call({
 String friendshipId, String userId, String? status
});




}
/// @nodoc
class __$FriendshipSummaryCopyWithImpl<$Res>
    implements _$FriendshipSummaryCopyWith<$Res> {
  __$FriendshipSummaryCopyWithImpl(this._self, this._then);

  final _FriendshipSummary _self;
  final $Res Function(_FriendshipSummary) _then;

/// Create a copy of FriendshipSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? friendshipId = null,Object? userId = null,Object? status = freezed,}) {
  return _then(_FriendshipSummary(
friendshipId: null == friendshipId ? _self.friendshipId : friendshipId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
