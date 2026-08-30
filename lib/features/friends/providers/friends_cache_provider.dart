import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/friends_repository.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';

/// The on-device friend-list cache contract (2026-08-29 user directive):
///
/// * Fetched ONCE in the BACKGROUND at app launch (once authenticated),
///   awaited, then persisted to the device DB (encrypted Hive box
///   `friends_cache`, keyed by user id).
/// * Read SYNCHRONOUSLY by the invite/buscar/search pickers for empty and
///   < 5-char queries — zero network I/O on the typing path, and never the
///   N+1 profile-fetch error ("Error del servidor") the old
///   `friendsListProvider`-based path surfaced.
/// * Kept fresh by the background warmer (also re-runs on the realtime
///   friendships stream via [FriendshipsRealtimeListener]'s invalidation).
class FriendsCacheController extends AsyncNotifier<List<UserSearchResult>> {
  @override
  Future<List<UserSearchResult>> build() async {
    final uid = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (uid == null) return const [];

    // Warm-from-disk first: the picker must have friends even before the
    // network fetch lands.
    final cached = ref.read(hiveServiceProvider).getCachedFriends(uid);
    List<UserSearchResult>? fromCache;
    if (cached != null) {
      final rows = <UserSearchResult>[];
      for (final row in cached) {
        if (row['id'] is! String || row['username'] is! String) continue;
        rows.add(UserSearchResult.fromJson(row));
      }
      if (rows.isNotEmpty) fromCache = rows;
    }
    if (fromCache != null) return fromCache;

    // Cold cache → fetch from the network and persist.
    final repo = ref.read(friendsRepositoryProvider);
    try {
      final friends = await _fetchFriends(repo);
      final rows = [for (final f in friends) f.toJson()];
      await ref.read(hiveServiceProvider).cacheFriends(uid, rows);
      return friends;
    } catch (e, st) {
      // A background warm-up failure must NEVER block the pickers: fall back
      // to whatever the cache has (may be empty), never throw.
      AppLogger.instance.warn('friends cache warm-up failed: $e', '$st');
      return fromCache ?? const [];
    }
  }

  /// Re-runs [build] after a friendship change (realtime / accept / decline).
  Future<void> refresh() async {
    final uid = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (uid != null) {
      await ref.read(hiveServiceProvider).clearCachedFriends(uid);
    }
    ref.invalidateSelf();
  }

  /// Fetches the accepted-friend profiles and shapes them as search rows.
  ///
  /// Uses ONE batched `user_search_view` query (no N+1) and skips any friend
  /// whose profile cannot be resolved (deleted/blocked/missing/null-username)
  /// — a single bad row can never abort the whole cache warm-up.
  Future<List<UserSearchResult>> _fetchFriends(
    FriendsRepository repo,
  ) async {
    final res = await repo.getFriends();
    final friendIds = [for (final f in res) f.userId];
    final rows = await repo.getUserSearchRows(friendIds);
    final byId = {for (final row in rows) row['id'] as String: row};
    final results = <UserSearchResult>[];
    for (final id in friendIds) {
      final row = byId[id];
      if (row == null) continue;
      results.add(
        UserSearchResult(
          id: id,
          username: row['username'] as String,
          avatarUrl: row['avatar_url'] as String?,
          friendshipStatus: 'accepted',
        ),
      );
    }
    results.sort((a, b) => a.username.compareTo(b.username));
    return results;
  }
}

/// The current user's friends from the on-device cache, as search-shaped
/// rows (used by `userSearchProvider` for empty + <5-char queries).
final friendsCacheProvider = AsyncNotifierProvider<FriendsCacheController,
    List<UserSearchResult>>(FriendsCacheController.new);

/// Background warmer mounted at the app root: once authenticated, it reads
/// [friendsCacheProvider] (which fetches + persists to the device DB) so the
/// invite/buscar pickers always have the friends list ready. Best-effort —
/// a failure logs and never blocks the shell.
class FriendsCacheWarmer extends ConsumerStatefulWidget {
  const FriendsCacheWarmer({super.key});

  @override
  ConsumerState<FriendsCacheWarmer> createState() => _FriendsCacheWarmerState();
}

class _FriendsCacheWarmerState extends ConsumerState<FriendsCacheWarmer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      _sync();
    });
    ref.listen(friendsListProvider, (_, _) {
      // The friends-tab list changed (accept/decline/realtime) → refresh the
      // on-device cache too.
      ref.read(friendsCacheProvider.notifier).refresh();
    });
    return const SizedBox.shrink();
  }

  void _sync() {
    final uid = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (uid == null) return;
    // Kick the fetch + persist; failures are caught inside the notifier.
    ref.read(friendsCacheProvider);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
