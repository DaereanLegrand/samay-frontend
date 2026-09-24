// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Event {

 String get id; String get name; String get type; String get status; DateTime get startsAt; DateTime get endsAt; String? get description; String? get groupId; String? get locationName;@JsonKey(fromJson: _asDouble) double? get locationLat;@JsonKey(fromJson: _asDouble) double? get locationLng; String? get coverUrl; String? get createdByUserId; String? get joinMode; bool get featured; bool get preshardsDistributed; int get preshardsPool; int get capacity; int? get preshardsCapPerUser; String? get preshardsRemainderAction;
/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventCopyWith<Event> get copyWith => _$EventCopyWithImpl<Event>(this as Event, _$identity);

  /// Serializes this Event to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Event&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.description, description) || other.description == description)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.locationLat, locationLat) || other.locationLat == locationLat)&&(identical(other.locationLng, locationLng) || other.locationLng == locationLng)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.createdByUserId, createdByUserId) || other.createdByUserId == createdByUserId)&&(identical(other.joinMode, joinMode) || other.joinMode == joinMode)&&(identical(other.featured, featured) || other.featured == featured)&&(identical(other.preshardsDistributed, preshardsDistributed) || other.preshardsDistributed == preshardsDistributed)&&(identical(other.preshardsPool, preshardsPool) || other.preshardsPool == preshardsPool)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.preshardsCapPerUser, preshardsCapPerUser) || other.preshardsCapPerUser == preshardsCapPerUser)&&(identical(other.preshardsRemainderAction, preshardsRemainderAction) || other.preshardsRemainderAction == preshardsRemainderAction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,type,status,startsAt,endsAt,description,groupId,locationName,locationLat,locationLng,coverUrl,createdByUserId,joinMode,featured,preshardsDistributed,preshardsPool,capacity,preshardsCapPerUser,preshardsRemainderAction]);

@override
String toString() {
  return 'Event(id: $id, name: $name, type: $type, status: $status, startsAt: $startsAt, endsAt: $endsAt, description: $description, groupId: $groupId, locationName: $locationName, locationLat: $locationLat, locationLng: $locationLng, coverUrl: $coverUrl, createdByUserId: $createdByUserId, joinMode: $joinMode, featured: $featured, preshardsDistributed: $preshardsDistributed, preshardsPool: $preshardsPool, capacity: $capacity, preshardsCapPerUser: $preshardsCapPerUser, preshardsRemainderAction: $preshardsRemainderAction)';
}


}

/// @nodoc
abstract mixin class $EventCopyWith<$Res>  {
  factory $EventCopyWith(Event value, $Res Function(Event) _then) = _$EventCopyWithImpl;
@useResult
$Res call({
 String id, String name, String type, String status, DateTime startsAt, DateTime endsAt, String? description, String? groupId, String? locationName,@JsonKey(fromJson: _asDouble) double? locationLat,@JsonKey(fromJson: _asDouble) double? locationLng, String? coverUrl, String? createdByUserId, String? joinMode, bool featured, bool preshardsDistributed, int preshardsPool, int capacity, int? preshardsCapPerUser, String? preshardsRemainderAction
});




}
/// @nodoc
class _$EventCopyWithImpl<$Res>
    implements $EventCopyWith<$Res> {
  _$EventCopyWithImpl(this._self, this._then);

  final Event _self;
  final $Res Function(Event) _then;

/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? status = null,Object? startsAt = null,Object? endsAt = null,Object? description = freezed,Object? groupId = freezed,Object? locationName = freezed,Object? locationLat = freezed,Object? locationLng = freezed,Object? coverUrl = freezed,Object? createdByUserId = freezed,Object? joinMode = freezed,Object? featured = null,Object? preshardsDistributed = null,Object? preshardsPool = null,Object? capacity = null,Object? preshardsCapPerUser = freezed,Object? preshardsRemainderAction = freezed,}) {
  return _then(Event(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,locationName: freezed == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String?,locationLat: freezed == locationLat ? _self.locationLat : locationLat // ignore: cast_nullable_to_non_nullable
as double?,locationLng: freezed == locationLng ? _self.locationLng : locationLng // ignore: cast_nullable_to_non_nullable
as double?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,createdByUserId: freezed == createdByUserId ? _self.createdByUserId : createdByUserId // ignore: cast_nullable_to_non_nullable
as String?,joinMode: freezed == joinMode ? _self.joinMode : joinMode // ignore: cast_nullable_to_non_nullable
as String?,featured: null == featured ? _self.featured : featured // ignore: cast_nullable_to_non_nullable
as bool,preshardsDistributed: null == preshardsDistributed ? _self.preshardsDistributed : preshardsDistributed // ignore: cast_nullable_to_non_nullable
as bool,preshardsPool: null == preshardsPool ? _self.preshardsPool : preshardsPool // ignore: cast_nullable_to_non_nullable
as int,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,preshardsCapPerUser: freezed == preshardsCapPerUser ? _self.preshardsCapPerUser : preshardsCapPerUser // ignore: cast_nullable_to_non_nullable
as int?,preshardsRemainderAction: freezed == preshardsRemainderAction ? _self.preshardsRemainderAction : preshardsRemainderAction // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Event].
extension EventPatterns on Event {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Event value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Event() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Event value)  $default,){
final _that = this;
switch (_that) {
case _Event():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Event value)?  $default,){
final _that = this;
switch (_that) {
case _Event() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String status,  DateTime startsAt,  DateTime endsAt,  String? description,  String? groupId,  String? locationName, @JsonKey(fromJson: _asDouble)  double? locationLat, @JsonKey(fromJson: _asDouble)  double? locationLng,  String? coverUrl,  String? createdByUserId,  String? joinMode,  bool featured,  bool preshardsDistributed,  int preshardsPool,  int capacity,  int? preshardsCapPerUser,  String? preshardsRemainderAction)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.status,_that.startsAt,_that.endsAt,_that.description,_that.groupId,_that.locationName,_that.locationLat,_that.locationLng,_that.coverUrl,_that.createdByUserId,_that.joinMode,_that.featured,_that.preshardsDistributed,_that.preshardsPool,_that.capacity,_that.preshardsCapPerUser,_that.preshardsRemainderAction);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String status,  DateTime startsAt,  DateTime endsAt,  String? description,  String? groupId,  String? locationName, @JsonKey(fromJson: _asDouble)  double? locationLat, @JsonKey(fromJson: _asDouble)  double? locationLng,  String? coverUrl,  String? createdByUserId,  String? joinMode,  bool featured,  bool preshardsDistributed,  int preshardsPool,  int capacity,  int? preshardsCapPerUser,  String? preshardsRemainderAction)  $default,) {final _that = this;
switch (_that) {
case _Event():
return $default(_that.id,_that.name,_that.type,_that.status,_that.startsAt,_that.endsAt,_that.description,_that.groupId,_that.locationName,_that.locationLat,_that.locationLng,_that.coverUrl,_that.createdByUserId,_that.joinMode,_that.featured,_that.preshardsDistributed,_that.preshardsPool,_that.capacity,_that.preshardsCapPerUser,_that.preshardsRemainderAction);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String type,  String status,  DateTime startsAt,  DateTime endsAt,  String? description,  String? groupId,  String? locationName, @JsonKey(fromJson: _asDouble)  double? locationLat, @JsonKey(fromJson: _asDouble)  double? locationLng,  String? coverUrl,  String? createdByUserId,  String? joinMode,  bool featured,  bool preshardsDistributed,  int preshardsPool,  int capacity,  int? preshardsCapPerUser,  String? preshardsRemainderAction)?  $default,) {final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.status,_that.startsAt,_that.endsAt,_that.description,_that.groupId,_that.locationName,_that.locationLat,_that.locationLng,_that.coverUrl,_that.createdByUserId,_that.joinMode,_that.featured,_that.preshardsDistributed,_that.preshardsPool,_that.capacity,_that.preshardsCapPerUser,_that.preshardsRemainderAction);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _Event implements Event {
  const _Event({required this.id, required this.name, required this.type, required this.status, required this.startsAt, required this.endsAt, this.description, this.groupId, this.locationName, @JsonKey(fromJson: _asDouble) this.locationLat, @JsonKey(fromJson: _asDouble) this.locationLng, this.coverUrl, this.createdByUserId, this.joinMode, this.featured = false, this.preshardsDistributed = false, this.preshardsPool = 0, this.capacity = 0, this.preshardsCapPerUser, this.preshardsRemainderAction});
  factory _Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

@override final  String id;
@override final  String name;
@override final  String type;
@override final  String status;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
@override final  String? description;
@override final  String? groupId;
@override final  String? locationName;
@override@JsonKey(fromJson: _asDouble) final  double? locationLat;
@override@JsonKey(fromJson: _asDouble) final  double? locationLng;
@override final  String? coverUrl;
@override final  String? createdByUserId;
@override final  String? joinMode;
@override@JsonKey() final  bool featured;
@override@JsonKey() final  bool preshardsDistributed;
@override@JsonKey() final  int preshardsPool;
@override@JsonKey() final  int capacity;
@override final  int? preshardsCapPerUser;
@override final  String? preshardsRemainderAction;

/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventCopyWith<_Event> get copyWith => __$EventCopyWithImpl<_Event>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Event&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.description, description) || other.description == description)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.locationLat, locationLat) || other.locationLat == locationLat)&&(identical(other.locationLng, locationLng) || other.locationLng == locationLng)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.createdByUserId, createdByUserId) || other.createdByUserId == createdByUserId)&&(identical(other.joinMode, joinMode) || other.joinMode == joinMode)&&(identical(other.featured, featured) || other.featured == featured)&&(identical(other.preshardsDistributed, preshardsDistributed) || other.preshardsDistributed == preshardsDistributed)&&(identical(other.preshardsPool, preshardsPool) || other.preshardsPool == preshardsPool)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.preshardsCapPerUser, preshardsCapPerUser) || other.preshardsCapPerUser == preshardsCapPerUser)&&(identical(other.preshardsRemainderAction, preshardsRemainderAction) || other.preshardsRemainderAction == preshardsRemainderAction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,type,status,startsAt,endsAt,description,groupId,locationName,locationLat,locationLng,coverUrl,createdByUserId,joinMode,featured,preshardsDistributed,preshardsPool,capacity,preshardsCapPerUser,preshardsRemainderAction]);

@override
String toString() {
  return 'Event(id: $id, name: $name, type: $type, status: $status, startsAt: $startsAt, endsAt: $endsAt, description: $description, groupId: $groupId, locationName: $locationName, locationLat: $locationLat, locationLng: $locationLng, coverUrl: $coverUrl, createdByUserId: $createdByUserId, joinMode: $joinMode, featured: $featured, preshardsDistributed: $preshardsDistributed, preshardsPool: $preshardsPool, capacity: $capacity, preshardsCapPerUser: $preshardsCapPerUser, preshardsRemainderAction: $preshardsRemainderAction)';
}


}

/// @nodoc
abstract mixin class _$EventCopyWith<$Res> implements $EventCopyWith<$Res> {
  factory _$EventCopyWith(_Event value, $Res Function(_Event) _then) = __$EventCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String type, String status, DateTime startsAt, DateTime endsAt, String? description, String? groupId, String? locationName,@JsonKey(fromJson: _asDouble) double? locationLat,@JsonKey(fromJson: _asDouble) double? locationLng, String? coverUrl, String? createdByUserId, String? joinMode, bool featured, bool preshardsDistributed, int preshardsPool, int capacity, int? preshardsCapPerUser, String? preshardsRemainderAction
});




}
/// @nodoc
class __$EventCopyWithImpl<$Res>
    implements _$EventCopyWith<$Res> {
  __$EventCopyWithImpl(this._self, this._then);

  final _Event _self;
  final $Res Function(_Event) _then;

/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? status = null,Object? startsAt = null,Object? endsAt = null,Object? description = freezed,Object? groupId = freezed,Object? locationName = freezed,Object? locationLat = freezed,Object? locationLng = freezed,Object? coverUrl = freezed,Object? createdByUserId = freezed,Object? joinMode = freezed,Object? featured = null,Object? preshardsDistributed = null,Object? preshardsPool = null,Object? capacity = null,Object? preshardsCapPerUser = freezed,Object? preshardsRemainderAction = freezed,}) {
  return _then(_Event(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,locationName: freezed == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String?,locationLat: freezed == locationLat ? _self.locationLat : locationLat // ignore: cast_nullable_to_non_nullable
as double?,locationLng: freezed == locationLng ? _self.locationLng : locationLng // ignore: cast_nullable_to_non_nullable
as double?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,createdByUserId: freezed == createdByUserId ? _self.createdByUserId : createdByUserId // ignore: cast_nullable_to_non_nullable
as String?,joinMode: freezed == joinMode ? _self.joinMode : joinMode // ignore: cast_nullable_to_non_nullable
as String?,featured: null == featured ? _self.featured : featured // ignore: cast_nullable_to_non_nullable
as bool,preshardsDistributed: null == preshardsDistributed ? _self.preshardsDistributed : preshardsDistributed // ignore: cast_nullable_to_non_nullable
as bool,preshardsPool: null == preshardsPool ? _self.preshardsPool : preshardsPool // ignore: cast_nullable_to_non_nullable
as int,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,preshardsCapPerUser: freezed == preshardsCapPerUser ? _self.preshardsCapPerUser : preshardsCapPerUser // ignore: cast_nullable_to_non_nullable
as int?,preshardsRemainderAction: freezed == preshardsRemainderAction ? _self.preshardsRemainderAction : preshardsRemainderAction // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
