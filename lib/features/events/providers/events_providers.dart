import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/event_service.dart';
import 'package:samay/core/utils/throttled_refresh.dart';

class EventDetailNotifier extends FamilyAsyncNotifier<Event, String>
    with ThrottledRefresh {
  EventService get _service => ref.read(eventServiceProvider);

  @override
  Future<Event> build(String eventId) async {
    final event = await _service.getEvent(eventId);
    markFetched();
    return event;
  }

  /// Re-runs [build] after any mutation (edit, cancel, status change). R20:
  /// skipped while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }

  /// Patches the event row and reloads the detail.
  Future<void> patch(Map<String, dynamic> patch) async {
    await _service.updateEvent(arg, patch);
    await refresh();
  }
}

/// A single event row by id.
final eventDetailProvider =
    AsyncNotifierProvider.family<EventDetailNotifier, Event, String>(
      EventDetailNotifier.new,
    );

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

class EventHostsNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String>
    with ThrottledRefresh {
  EventService get _service => ref.read(eventServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build(String eventId) async {
    final hosts = await _service.getEventHosts(eventId);
    markFetched();
    return hosts;
  }

  /// Re-runs [build] after host-list changes. R20: skipped while the
  /// last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Hosts of an event (rows enriched with `users.username`).
final eventHostsProvider =
    AsyncNotifierProvider.family<
      EventHostsNotifier,
      List<Map<String, dynamic>>,
      String
    >(EventHostsNotifier.new);

class MyEventInviteNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>?, String>
    with ThrottledRefresh {
  EventService get _service => ref.read(eventServiceProvider);

  @override
  Future<Map<String, dynamic>?> build(String eventId) async {
    final invite = await _service.getMyEventInvite(eventId);
    markFetched();
    return invite;
  }

  /// Re-runs [build] after accepting/declining an invite. R20: skipped
  /// while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// The current user's invite row for an event (null when not invited).
final myEventInviteProvider =
    AsyncNotifierProvider.family<
      MyEventInviteNotifier,
      Map<String, dynamic>?,
      String
    >(MyEventInviteNotifier.new);

class MyEventsNotifier extends AsyncNotifier<List<Event>>
    with ThrottledRefresh {
  EventService get _service => ref.read(eventServiceProvider);

  /// The events tab list (R1 events sweep): every event visible to the
  /// session, ordered by `starts_at` ASC (the service's ordering).
  @override
  Future<List<Event>> build() async {
    final events = await _service.listEvents();
    markFetched();
    return events;
  }

  /// Re-runs [build] (pull-to-refresh). R20: skipped while the last fetch
  /// is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// The events tab list — every event the current session can see, earliest
/// first.
final myEventsProvider = AsyncNotifierProvider<MyEventsNotifier, List<Event>>(
  MyEventsNotifier.new,
);
