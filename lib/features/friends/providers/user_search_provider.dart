import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/friends/providers/friends_cache_provider.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';

/// Combined user-search rows for the user-picking UIs (groups invite, friends
/// buscar/search, minigame picker) — the "cached friends + backend search"
/// contract:
///
/// * **Query < [InputSanitizer.searchQueryMinLength] (5)** → the on-device
///   friends cache only, filtered by the partial query. No `search_users` RPC
///   is ever fired here — the server rejects short queries with SR002
///   `invalid_query_length`, and a cold friends cache degrades to an empty
///   list, never an error.
/// * **Query ≥ 5** → the backend `search_users` results merged with the
///   on-device friends that match the query (deduplicated by id), friends
///   listed FIRST — so the 20-row backend cap can never hide a friend.
///
/// Screens watch this single provider instead of `searchResultsProvider`
/// directly; the threshold + merge + friends-first ordering live here so
/// every picking surface behaves identically.
final userSearchProvider = Provider.family<AsyncValue<List<UserSearchResult>>,
    String>((ref, arg) {
  final query = arg.trim();
  final needle = query.toLowerCase();
  final friends = ref.watch(friendsCacheProvider);

  if (query.length < InputSanitizer.searchQueryMinLength) {
    return friends.whenData(
      (list) => list
          .where(
            (f) => needle.isEmpty || f.username.toLowerCase().contains(needle),
          )
          .toList(),
    );
  }

  return ref.watch(searchResultsProvider(query)).whenData((users) {
    final matchingFriends = friends.valueOrNull
            ?.where((f) => f.username.toLowerCase().contains(needle))
            .toList() ??
        const <UserSearchResult>[];
    final friendIds = matchingFriends.map((f) => f.id).toSet();
    final backendOnly = users
        .where((u) => !friendIds.contains(u.id))
        .toList();
    final merged = <UserSearchResult>[...matchingFriends, ...backendOnly];
    merged.sort((a, b) {
      final aFriend = a.friendshipStatus == 'accepted';
      final bFriend = b.friendshipStatus == 'accepted';
      if (aFriend == bFriend) return 0;
      return aFriend ? -1 : 1;
    });
    return merged;
  });
});
