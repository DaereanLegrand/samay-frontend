import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/feed_item.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/event_service.dart';
import 'package:samay/core/services/minigame_service.dart';

/// Aggregates the agnostic feed: public upcoming events interleaved with the
/// user's minigame matches, ordered by the most recent interaction — another
/// participant (a pending invite / active match) ahead of system-generated
/// items, then by activity time descending.
///
/// The payload is cached on-device (user-id-keyed Hive box) so the tab renders
/// instantly and survives a cold/offline start; a network refresh replaces it
/// when it lands.
class FeedNotifier extends AsyncNotifier<List<FeedItem>> {
  EventService get _events => ref.read(eventServiceProvider);

  MinigameService get _minigames => ref.read(minigameServiceProvider);

  String? get _userId =>
      ref.read(supabaseClientProvider).auth.currentUser?.id;

  @override
  Future<List<FeedItem>> build() async {
    // Cache-first: show the persisted timeline immediately, then refresh in
    // the background so first paint never waits on the network.
    final cached = _readCache();
    if (cached != null && cached.isNotEmpty) {
      Future.microtask(_load);
      return cached;
    }
    return _load();
  }

  /// Pull-to-refresh: refetch and replace the timeline.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<List<FeedItem>> _load() async {
    final items = <FeedItem>[];

    // Public (non group-scoped) upcoming events.
    try {
      final rows = await _events.listEvents('upcoming');
      for (final event in rows.where((e) => e.groupId == null)) {
        items.add(
          FeedEventItem(
            event: event,
            activityAt: event.startsAt,
          ),
        );
      }
    } catch (_) {
      // A failed events half must not blank the whole feed.
    }

    // The user's matches: own sessions + pending invites (the invite is an
    // interaction by another participant, so it floats to the top).
    final sessions = <String, FeedMinigameItem>{};
    try {
      for (final session in await _minigames.listMySessions()) {
        final item = _toMinigame(session, fromParticipant: false);
        if (item != null) sessions[item.session['id'] as String] = item;
      }
    } catch (_) {}
    try {
      for (final session in await _minigames.listMyPendingInvites()) {
        final item = _toMinigame(session, fromParticipant: true);
        if (item != null) sessions[item.session['id'] as String] = item;
      }
    } catch (_) {}
    items.addAll(sessions.values);

    items.sort(_compare);
    _writeCache(items);
    return items;
  }

  /// Pending participant interactions first, then featured events, then
  /// most-recent activity.
  static int _compare(FeedItem a, FeedItem b) {
    if (a.fromParticipant != b.fromParticipant) {
      return a.fromParticipant ? -1 : 1;
    }
    final aFeatured = a is FeedEventItem && a.event.featured;
    final bFeatured = b is FeedEventItem && b.event.featured;
    if (aFeatured != bFeatured) return aFeatured ? -1 : 1;
    return b.activityAt.compareTo(a.activityAt);
  }

  FeedMinigameItem? _toMinigame(
    Map<String, dynamic> session, {
    required bool fromParticipant,
  }) {
    final id = session['id'];
    if (id is! String) return null;
    final created = session['created_at'];
    final activityAt = created is String
        ? (DateTime.tryParse(created) ?? DateTime.now())
        : DateTime.now();
    return FeedMinigameItem(
      session: session,
      activityAt: activityAt,
      fromParticipant: fromParticipant,
    );
  }

  List<FeedItem>? _readCache() {
    final userId = _userId;
    if (userId == null) return null;
    final raw = ref.read(hiveServiceProvider).getCachedFeed(userId);
    if (raw == null) return null;
    return raw
        .map(FeedItem.fromJson)
        .whereType<FeedItem>()
        .toList();
  }

  void _writeCache(List<FeedItem> items) {
    final userId = _userId;
    if (userId == null) return;
    ref
        .read(hiveServiceProvider)
        .cacheFeed(userId, items.map((e) => e.toJson()).toList());
  }
}

/// The agnostic feed timeline.
final feedProvider = AsyncNotifierProvider<FeedNotifier, List<FeedItem>>(
  FeedNotifier.new,
);
