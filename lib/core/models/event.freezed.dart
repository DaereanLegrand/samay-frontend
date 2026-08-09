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

 String get id; String get name; String get type; String get status; DateTime get startsAt; DateTime get endsAt; String? get groupId; String? get locationName; int get preshardsPool;
/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventCopyWith<Event> get copyWith => _$EventCopyWithImpl<Event>(this as Event, _$identity);

  /// Serializes this Event to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Event&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.preshardsPool, preshardsPool) || other.preshardsPool == preshardsPool));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,status,startsAt,endsAt,groupId,locationName,preshardsPool);

@override
String toString() {
  return 'Event(id: $id, name: $name, type: $type, status: $status, startsAt: $startsAt, endsAt: $endsAt, groupId: $groupId, locationName: $locationName, preshardsPool: $preshardsPool)';
}


}

/// @nodoc
abstract mixin class $EventCopyWith<$Res>  {
  factory $EventCopyWith(Event value, $Res Function(Event) _then) = _$EventCopyWithImpl;
@useResult
$Res call({
 String id, String name, String type, String status, DateTime startsAt, DateTime endsAt, String? groupId, String? locationName, int preshardsPool
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? status = null,Object? startsAt = null,Object? endsAt = null,Object? groupId = freezed,Object? locationName = freezed,Object? preshardsPool = null,}) {
  return _then(Event(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,locationName: freezed == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String?,preshardsPool: null == preshardsPool ? _self.preshardsPool : preshardsPool // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String status,  DateTime startsAt,  DateTime endsAt,  String? groupId,  String? locationName,  int preshardsPool)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.status,_that.startsAt,_that.endsAt,_that.groupId,_that.locationName,_that.preshardsPool);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String status,  DateTime startsAt,  DateTime endsAt,  String? groupId,  String? locationName,  int preshardsPool)  $default,) {final _that = this;
switch (_that) {
case _Event():
return $default(_that.id,_that.name,_that.type,_that.status,_that.startsAt,_that.endsAt,_that.groupId,_that.locationName,_that.preshardsPool);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String type,  String status,  DateTime startsAt,  DateTime endsAt,  String? groupId,  String? locationName,  int preshardsPool)?  $default,) {final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.status,_that.startsAt,_that.endsAt,_that.groupId,_that.locationName,_that.preshardsPool);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _Event implements Event {
  const _Event({required this.id, required this.name, required this.type, required this.status, required this.startsAt, required this.endsAt, this.groupId, this.locationName, this.preshardsPool = 0});
  factory _Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

@override final  String id;
@override final  String name;
@override final  String type;
@override final  String status;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
@override final  String? groupId;
@override final  String? locationName;
@override@JsonKey() final  int preshardsPool;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Event&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.preshardsPool, preshardsPool) || other.preshardsPool == preshardsPool));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,status,startsAt,endsAt,groupId,locationName,preshardsPool);

@override
String toString() {
  return 'Event(id: $id, name: $name, type: $type, status: $status, startsAt: $startsAt, endsAt: $endsAt, groupId: $groupId, locationName: $locationName, preshardsPool: $preshardsPool)';
}


}

/// @nodoc
abstract mixin class _$EventCopyWith<$Res> implements $EventCopyWith<$Res> {
  factory _$EventCopyWith(_Event value, $Res Function(_Event) _then) = __$EventCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String type, String status, DateTime startsAt, DateTime endsAt, String? groupId, String? locationName, int preshardsPool
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? status = null,Object? startsAt = null,Object? endsAt = null,Object? groupId = freezed,Object? locationName = freezed,Object? preshardsPool = null,}) {
  return _then(_Event(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,locationName: freezed == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String?,preshardsPool: null == preshardsPool ? _self.preshardsPool : preshardsPool // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
