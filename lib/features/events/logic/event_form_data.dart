import 'package:samay/core/utils/input_sanitizer.dart';

/// Event creation types (ECRT spec step 1; DB enum `event_type` —
/// `supabase/migrations/20260510000001_full_schema.sql` §1).
enum EventType {
  casual('casual'),
  juerga('juerga'),
  tono('tono');

  const EventType(this.wire);

  /// The PostgREST wire value stored in `events.type`.
  final String wire;
}

/// Where the event lives: public (feed, join_mode set) or group-scoped
/// (invitation-only, `join_mode = NULL` per ECRT step 3).
enum EventVisibility { public, group }

/// Public-events join policy (DB enum `join_mode`: open / approval).
enum EventJoinMode {
  open('open'),
  approval('approval');

  const EventJoinMode(this.wire);

  final String wire;
}

/// What happens to the preshard remainder at distribution time (DB enum
/// `preshard_remainder_action` — ECRT step 5, EEDG `shard-distribution`).
enum EventRemainderAction {
  returnToContributors('return'),
  redistribute('redistribute');

  const EventRemainderAction(this.wire);

  final String wire;
}

/// Validation failures the form can produce. Each maps to a localized message
/// in `create_event_screen.dart` (error strings cannot live here: they need a
/// BuildContext and the l10n extraction guard scans `lib/features/**`).
enum EventFormError {
  nameRequired,
  invalidTimeRange,
  casualPoolMustBeZero,
  juergaLocationUnconfirmed,
  groupRequired,
  joinModeRequired,
}

/// Sentinel so [EventFormData.copyWith] can distinguish "not passed" from
/// "explicitly nulled" (required to clear optional fields).
const Object _unset = Object();

/// Typed, immutable form state for the ECRT creation flow.
///
/// Pure data + pure validation: no BuildContext, no services — the screen
/// binds widgets to a `copyWith` loop and hands the validated result to
/// `EventService.createEvent` (which owns the 3-table insert shape).
class EventFormData {
  const EventFormData({
    this.name = '',
    this.description = '',
    this.type = EventType.casual,
    required this.startsAt,
    required this.endsAt,
    this.locationName = '',
    this.visibility = EventVisibility.public,
    this.groupId,
    this.joinMode = EventJoinMode.open,
    this.preshardsPool = 0,
    this.preshardsCapPerUser,
    this.remainderAction,
    this.juergaLocationConfirmed = false,
  });

  static const int nameMaxLength = 50;
  static const int descriptionMaxLength = 250;
  static const int locationMaxLength = 120;

  final String name;
  final String description;
  final EventType type;
  final DateTime startsAt;
  final DateTime endsAt;
  final String locationName;
  final EventVisibility visibility;
  final String? groupId;
  final EventJoinMode? joinMode;
  final int preshardsPool;
  final int? preshardsCapPerUser;
  final EventRemainderAction? remainderAction;

  /// ECRT step 4: the Juerga location warning must be explicitly confirmed.
  final bool juergaLocationConfirmed;

  /// The preshards section is only rendered (and only valid) for Juerga/Tono;
  /// Casual is forced to a zero pool by the DB CHECK constraint
  /// `check_casual_no_preshards` (§3.10) and by [toPayload] below.
  bool get preshardsEnabled => type != EventType.casual;

  EventFormData copyWith({
    String? name,
    String? description,
    EventType? type,
    DateTime? startsAt,
    DateTime? endsAt,
    String? locationName,
    EventVisibility? visibility,
    Object? groupId = _unset,
    Object? joinMode = _unset,
    int? preshardsPool,
    Object? preshardsCapPerUser = _unset,
    Object? remainderAction = _unset,
    bool? juergaLocationConfirmed,
  }) {
    return EventFormData(
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      locationName: locationName ?? this.locationName,
      visibility: visibility ?? this.visibility,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
      joinMode:
          identical(joinMode, _unset) ? this.joinMode : joinMode as EventJoinMode?,
      preshardsPool: preshardsPool ?? this.preshardsPool,
      preshardsCapPerUser: identical(preshardsCapPerUser, _unset)
          ? this.preshardsCapPerUser
          : preshardsCapPerUser as int?,
      remainderAction: identical(remainderAction, _unset)
          ? this.remainderAction
          : remainderAction as EventRemainderAction?,
      juergaLocationConfirmed:
          juergaLocationConfirmed ?? this.juergaLocationConfirmed,
    );
  }

  /// Applies the client-side caps (H-24/InputSanitizer) to free text before
  /// it reaches the payload.
  EventFormData sanitized() {
    return copyWith(
      name: InputSanitizer.sanitize(name, maxLength: nameMaxLength),
      description: InputSanitizer.sanitize(description,
          maxLength: descriptionMaxLength),
      locationName:
          InputSanitizer.sanitize(locationName, maxLength: locationMaxLength),
    );
  }

  /// Validation rules (ECRT steps 1–5):
  ///
  /// * name required
  /// * `ends_at` must be after `starts_at`
  /// * Casual → pool must be 0 (mirrors `check_casual_no_preshards`)
  /// * Juerga → the location warning must have been confirmed
  /// * group visibility requires a group; public requires a join mode
  List<EventFormError> validate() {
    final errors = <EventFormError>[];
    if (name.trim().isEmpty) {
      errors.add(EventFormError.nameRequired);
    }
    if (!endsAt.isAfter(startsAt)) {
      errors.add(EventFormError.invalidTimeRange);
    }
    if (type == EventType.casual && preshardsPool != 0) {
      errors.add(EventFormError.casualPoolMustBeZero);
    }
    if (type == EventType.juerga && !juergaLocationConfirmed) {
      errors.add(EventFormError.juergaLocationUnconfirmed);
    }
    if (visibility == EventVisibility.group && groupId == null) {
      errors.add(EventFormError.groupRequired);
    }
    if (visibility == EventVisibility.public && joinMode == null) {
      errors.add(EventFormError.joinModeRequired);
    }
    return errors;
  }

  /// The payload handed to `EventService.createEvent` — matches the service's
  /// insert shape (events + event_promotores + chats) and the schema columns
  /// of `events` (§3.10). `cover_url` is appended by the screen after the
  /// optional cover upload, mirroring `CreateGroupScreen`.
  Map<String, dynamic> toPayload() {
    final groupScoped = visibility == EventVisibility.group;
    return {
      'name': name.trim(),
      'description':
          description.trim().isEmpty ? null : description.trim(),
      'type': type.wire,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'location_name': locationName.trim().isEmpty ? null : locationName.trim(),
      'group_id': groupScoped ? groupId : null,
      // Group-scoped events are always invitation-only (ECRT step 3).
      'join_mode': groupScoped ? null : joinMode?.wire,
      // Casual is forced to a zero pool client-side too (defense-in-depth
      // for the DB CHECK constraint).
      'preshards_pool': type == EventType.casual ? 0 : preshardsPool,
      'preshards_cap_per_user': preshardsCapPerUser,
      'preshards_remainder_action': remainderAction?.wire,
    };
  }
}
