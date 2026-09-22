// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_photo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EventPhoto {

 String get id; String get eventId; String get uploadedByUserId; String get storagePath; int get likesCount; bool get reported; DateTime get createdAt;/// Signed URL resolved client-side by the gallery provider.
/// Never present in the `event_photos` row; filled via `copyWith` once the
/// storage client issues it, null until then.
 String? get signedUrl;/// Whether the current user has liked this photo (one like per user per
/// photo). Resolved from `event_photo_likes` by the gallery provider, not
/// stored on the row.
 bool get likedByMe;
/// Create a copy of EventPhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventPhotoCopyWith<EventPhoto> get copyWith => _$EventPhotoCopyWithImpl<EventPhoto>(this as EventPhoto, _$identity);

  /// Serializes this EventPhoto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventPhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.uploadedByUserId, uploadedByUserId) || other.uploadedByUserId == uploadedByUserId)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.likesCount, likesCount) || other.likesCount == likesCount)&&(identical(other.reported, reported) || other.reported == reported)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.signedUrl, signedUrl) || other.signedUrl == signedUrl)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,eventId,uploadedByUserId,storagePath,likesCount,reported,createdAt,signedUrl,likedByMe);

@override
String toString() {
  return 'EventPhoto(id: $id, eventId: $eventId, uploadedByUserId: $uploadedByUserId, storagePath: $storagePath, likesCount: $likesCount, reported: $reported, createdAt: $createdAt, signedUrl: $signedUrl, likedByMe: $likedByMe)';
}


}

/// @nodoc
abstract mixin class $EventPhotoCopyWith<$Res>  {
  factory $EventPhotoCopyWith(EventPhoto value, $Res Function(EventPhoto) _then) = _$EventPhotoCopyWithImpl;
@useResult
$Res call({
 String id, String eventId, String uploadedByUserId, String storagePath, int likesCount, bool reported, DateTime createdAt, String? signedUrl, bool likedByMe
});




}
/// @nodoc
class _$EventPhotoCopyWithImpl<$Res>
    implements $EventPhotoCopyWith<$Res> {
  _$EventPhotoCopyWithImpl(this._self, this._then);

  final EventPhoto _self;
  final $Res Function(EventPhoto) _then;

/// Create a copy of EventPhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? eventId = null,Object? uploadedByUserId = null,Object? storagePath = null,Object? likesCount = null,Object? reported = null,Object? createdAt = null,Object? signedUrl = freezed,Object? likedByMe = null,}) {
  return _then(EventPhoto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,uploadedByUserId: null == uploadedByUserId ? _self.uploadedByUserId : uploadedByUserId // ignore: cast_nullable_to_non_nullable
as String,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,reported: null == reported ? _self.reported : reported // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,signedUrl: freezed == signedUrl ? _self.signedUrl : signedUrl // ignore: cast_nullable_to_non_nullable
as String?,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [EventPhoto].
extension EventPhotoPatterns on EventPhoto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventPhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventPhoto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventPhoto value)  $default,){
final _that = this;
switch (_that) {
case _EventPhoto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventPhoto value)?  $default,){
final _that = this;
switch (_that) {
case _EventPhoto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String eventId,  String uploadedByUserId,  String storagePath,  int likesCount,  bool reported,  DateTime createdAt,  String? signedUrl,  bool likedByMe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EventPhoto() when $default != null:
return $default(_that.id,_that.eventId,_that.uploadedByUserId,_that.storagePath,_that.likesCount,_that.reported,_that.createdAt,_that.signedUrl,_that.likedByMe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String eventId,  String uploadedByUserId,  String storagePath,  int likesCount,  bool reported,  DateTime createdAt,  String? signedUrl,  bool likedByMe)  $default,) {final _that = this;
switch (_that) {
case _EventPhoto():
return $default(_that.id,_that.eventId,_that.uploadedByUserId,_that.storagePath,_that.likesCount,_that.reported,_that.createdAt,_that.signedUrl,_that.likedByMe);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String eventId,  String uploadedByUserId,  String storagePath,  int likesCount,  bool reported,  DateTime createdAt,  String? signedUrl,  bool likedByMe)?  $default,) {final _that = this;
switch (_that) {
case _EventPhoto() when $default != null:
return $default(_that.id,_that.eventId,_that.uploadedByUserId,_that.storagePath,_that.likesCount,_that.reported,_that.createdAt,_that.signedUrl,_that.likedByMe);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _EventPhoto implements EventPhoto {
  const _EventPhoto({required this.id, required this.eventId, required this.uploadedByUserId, required this.storagePath, this.likesCount = 0, this.reported = false, required this.createdAt, this.signedUrl, this.likedByMe = false});
  factory _EventPhoto.fromJson(Map<String, dynamic> json) => _$EventPhotoFromJson(json);

@override final  String id;
@override final  String eventId;
@override final  String uploadedByUserId;
@override final  String storagePath;
@override@JsonKey() final  int likesCount;
@override@JsonKey() final  bool reported;
@override final  DateTime createdAt;
/// Signed URL resolved client-side by the gallery provider.
/// Never present in the `event_photos` row; filled via `copyWith` once the
/// storage client issues it, null until then.
@override final  String? signedUrl;
/// Whether the current user has liked this photo (one like per user per
/// photo). Resolved from `event_photo_likes` by the gallery provider, not
/// stored on the row.
@override@JsonKey() final  bool likedByMe;

/// Create a copy of EventPhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventPhotoCopyWith<_EventPhoto> get copyWith => __$EventPhotoCopyWithImpl<_EventPhoto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventPhotoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventPhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.uploadedByUserId, uploadedByUserId) || other.uploadedByUserId == uploadedByUserId)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.likesCount, likesCount) || other.likesCount == likesCount)&&(identical(other.reported, reported) || other.reported == reported)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.signedUrl, signedUrl) || other.signedUrl == signedUrl)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,eventId,uploadedByUserId,storagePath,likesCount,reported,createdAt,signedUrl,likedByMe);

@override
String toString() {
  return 'EventPhoto(id: $id, eventId: $eventId, uploadedByUserId: $uploadedByUserId, storagePath: $storagePath, likesCount: $likesCount, reported: $reported, createdAt: $createdAt, signedUrl: $signedUrl, likedByMe: $likedByMe)';
}


}

/// @nodoc
abstract mixin class _$EventPhotoCopyWith<$Res> implements $EventPhotoCopyWith<$Res> {
  factory _$EventPhotoCopyWith(_EventPhoto value, $Res Function(_EventPhoto) _then) = __$EventPhotoCopyWithImpl;
@override @useResult
$Res call({
 String id, String eventId, String uploadedByUserId, String storagePath, int likesCount, bool reported, DateTime createdAt, String? signedUrl, bool likedByMe
});




}
/// @nodoc
class __$EventPhotoCopyWithImpl<$Res>
    implements _$EventPhotoCopyWith<$Res> {
  __$EventPhotoCopyWithImpl(this._self, this._then);

  final _EventPhoto _self;
  final $Res Function(_EventPhoto) _then;

/// Create a copy of EventPhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? eventId = null,Object? uploadedByUserId = null,Object? storagePath = null,Object? likesCount = null,Object? reported = null,Object? createdAt = null,Object? signedUrl = freezed,Object? likedByMe = null,}) {
  return _then(_EventPhoto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,uploadedByUserId: null == uploadedByUserId ? _self.uploadedByUserId : uploadedByUserId // ignore: cast_nullable_to_non_nullable
as String,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,reported: null == reported ? _self.reported : reported // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,signedUrl: freezed == signedUrl ? _self.signedUrl : signedUrl // ignore: cast_nullable_to_non_nullable
as String?,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
