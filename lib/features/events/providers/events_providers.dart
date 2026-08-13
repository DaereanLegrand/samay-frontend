import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/event_service.dart';

class EventDetailNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>, String> {
  EventService get _service => ref.read(eventServiceProvider);

  @override
  Future<Map<String, dynamic>> build(String eventId) async {
    return _service.getEvent(eventId);
  }

  /// Re-runs [build] after any mutation (edit, cancel, status change).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Patches the event row and reloads the detail.
  Future<void> patch(Map<String, dynamic> patch) async {
    await _service.updateEvent(arg, patch);
    await refresh();
  }
}

/// A single event row by id.
final eventDetailProvider =
    AsyncNotifierProvider.family<
      EventDetailNotifier,
      Map<String, dynamic>,
      String
    >(EventDetailNotifier.new);

class EventByInviteTokenNotifier extends FamilyAsyncNotifier<Event?, String> {
  EventService get _service => ref.read(eventServiceProvider);

  @override
  Future<Event?> build(String token) async {
    return _service.getEventByInviteToken(token);
  }
}

/// Resolves an invite token to its event (null when the token matches no
/// event) — the EINV deep-link lookup (`invite_token` is UNIQUE + indexed).
final eventByInviteTokenProvider =
    AsyncNotifierProvider.family<EventByInviteTokenNotifier, Event?, String>(
      EventByInviteTokenNotifier.new,
    );

class EventPromotoresNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  EventService get _service => ref.read(eventServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build(String eventId) async {
    return _service.getEventPromotores(eventId);
  }

  /// Re-runs [build] after promotor-list changes.
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Promotores of an event (rows enriched with `users.username`).
final eventPromotoresProvider =
    AsyncNotifierProvider.family<
      EventPromotoresNotifier,
      List<Map<String, dynamic>>,
      String
    >(EventPromotoresNotifier.new);

class MyEventInviteNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>?, String> {
  EventService get _service => ref.read(eventServiceProvider);

  @override
  Future<Map<String, dynamic>?> build(String eventId) async {
    return _service.getMyEventInvite(eventId);
  }

  /// Re-runs [build] after accepting/declining an invite.
  Future<void> refresh() async => ref.invalidateSelf();
}

/// The current user's invite row for an event (null when not invited).
final myEventInviteProvider =
    AsyncNotifierProvider.family<
      MyEventInviteNotifier,
      Map<String, dynamic>?,
      String
    >(MyEventInviteNotifier.new);

class MyEventsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  EventService get _service => ref.read(eventServiceProvider);

  /// The events tab list (R1 events sweep): every event visible to the
  /// session, ordered by `starts_at` ASC (the service's ordering).
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _service.listEvents();
  }

  /// Re-runs [build] (pull-to-refresh).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// The events tab list — every event the current session can see, earliest
/// first.
final myEventsProvider =
    AsyncNotifierProvider<MyEventsNotifier, List<Map<String, dynamic>>>(
      MyEventsNotifier.new,
    );
