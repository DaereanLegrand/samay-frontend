import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/friends/providers/friends_cache_provider.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';

/// The current user's friends, ordered by RECENT activity for the invite
/// picker: a friend's recency is the latest of their direct-chat
/// `last_message_at` (via the E2EE inbox) and their latest direct minigame
/// session `created_at` (via `myMinigameSessionsProvider`); friends with no
/// activity fall to the end, tie-broken by username ASC.
///
/// The invite/search pickers show this list for empty and query length 0..4
/// so a short query is never empty and never fires a sub-5-char backend
/// search (the `search_users` RPC rejects short queries with SR002).
///
/// **SOURCE = ON-DEVICE CACHE:** the friend list
/// is fetched in the BACKGROUND at app launch and persisted to the encrypted
/// Hive `friends_cache` box ([FriendsCacheController]). This provider reads
/// that cache — NO network I/O on the picker path, and NEVER the
/// `friendsListProvider` N+1 profile-fetch error ("Error del servidor").
/// Recency inputs (chat inbox, minigame
/// sessions) stay cache-only (`ref.exists` + `valueOrNull` — cold caches
/// degrade to username order).
class RecentFriendsNotifier extends AsyncNotifier<List<UserSearchResult>> {
  @override
  Future<List<UserSearchResult>> build() async {
    // The on-device cache (disk-first, background-fetched) — never throws.
    final cached = await ref.watch(friendsCacheProvider.future);
    final chatRecency = _chatRecency();
    final minigameRecency = _minigameRecency();

    final results = [
      for (final f in cached) f,
    ];

    int score(String id) {
      final chat = chatRecency[id]?.millisecondsSinceEpoch ?? 0;
      final game = minigameRecency[id]?.millisecondsSinceEpoch ?? 0;
      return chat > game ? chat : game;
    }

    results.sort((a, b) {
      final byScore = score(b.id).compareTo(score(a.id));
      if (byScore != 0) return byScore;
      return a.username.compareTo(b.username);
    });
    return results;
  }

  /// Peer id → latest direct-chat message time from the CACHED inbox
  /// (`ref.exists` guard, no fetch). Group chats have no single peer.
  Map<String, DateTime> _chatRecency() {
    if (!ref.exists(chatInboxProvider)) return const {};
    final inbox =
        ref.read(chatInboxProvider).valueOrNull ?? const <ChatInboxItem>[];
    final map = <String, DateTime>{};
    for (final item in inbox) {
      final peerId = item.peerId;
      final lastAt = item.lastMessageAt;
      if (peerId == null || lastAt == null) continue;
      final existing = map[peerId];
      if (existing == null || lastAt.isAfter(existing)) {
        map[peerId] = lastAt;
      }
    }
    return map;
  }

  /// Peer id → their latest minigame session `created_at` (direct or group)
  /// from the CACHED sessions list (`ref.exists` guard, no fetch). Only
  /// sessions the current user participates in are listed; peers are the other
  /// ids.
  Map<String, DateTime> _minigameRecency() {
    if (!ref.exists(myMinigameSessionsProvider)) return const {};
    final sessions =
        ref.read(myMinigameSessionsProvider).valueOrNull ?? const [];
    final map = <String, DateTime>{};
    for (final session in sessions) {
      final createdAt = DateTime.tryParse(session['created_at'] as String? ?? '');
      if (createdAt == null) continue;
      final participants =
          (session['participants'] as List?)?.whereType<String>() ?? const [];
      for (final peerId in participants) {
        final existing = map[peerId];
        if (existing == null || createdAt.isAfter(existing)) {
          map[peerId] = createdAt;
        }
      }
    }
    return map;
  }
}

/// The current user's friends ordered by recency, as search-shaped rows
/// (`friendshipStatus: 'accepted'`) so the invite picker can render them
/// alongside backend search results without a second model.
final recentFriendsProvider = AsyncNotifierProvider<RecentFriendsNotifier,
    List<UserSearchResult>>(RecentFriendsNotifier.new);
