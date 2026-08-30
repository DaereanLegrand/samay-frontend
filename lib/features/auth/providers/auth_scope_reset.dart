import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/user_provider.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/feed/providers/feed_providers.dart';
import 'package:samay/features/friends/providers/friends_cache_provider.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/friends/providers/recent_friends_provider.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/notifications/providers/notifications_providers.dart';
import 'package:samay/features/party_finder/providers/party_finder_providers.dart';
import 'package:samay/features/photos/providers/photos_providers.dart';
import 'package:samay/features/profile/providers/profile_providers.dart' as profile;
import 'package:samay/features/qr/providers/qr_providers.dart';
import 'package:samay/features/shards/providers/shard_ledger_providers.dart';

/// Account-switch staleness fix (2026-08-14).
///
/// **ON LOGOUT, FLUSH ALL DATA** (user directive): non-autodispose providers
/// live for the whole container lifetime, so after signing out — and then
/// signing in as another user in the same app session — every cached
/// user-scoped provider used to show the PREVIOUS account's data (friends
/// lists, requests, groups, notifications, chats, QR tokens...).
///
/// This widget is mounted once at the app root (`SamayApp`, above the
/// Navigator) and `ref.listen`s [authStateProvider]: the instant the session
/// ends (authenticated → signed out, uid → null) — or the uid changes
/// between two sessions (safety net) — it invalidates every user-scoped
/// provider, flushing the whole per-account cache. The next read rebuilds
/// fresh for the new session.
///
/// Invalidating a `.family` provider (chat messages, QR tokens, event
/// details...) clears ALL its instances. Derived providers
/// (`pendingCountsProvider`, `unreadCountProvider`) recompute from the
/// invalidated roots. The realtime listener (`FriendshipsRealtimeListener`)
/// independently unsubscribes on sign-out.
class AuthScopeReset extends ConsumerWidget {
  const AuthScopeReset({super.key});

  /// User-scoped providers whose cache must never survive a logout or an
  /// account switch. Family providers are listed without arguments — the
  /// whole family is flushed.
  static final List<ProviderOrFamily> _userScoped = [
    // friends
    friendsListProvider,
    friendRequestsProvider,
    blockedUsersProvider,
    searchResultsProvider,
    recentFriendsProvider,
    friendsCacheProvider,
    // groups
    myGroupsProvider,
    groupInvitesProvider,
    groupDetailProvider,
    groupMembersProvider,
    leaderboardProvider,
    contributionsProvider,
    // profile (both myGroups: the groups tab's and the profile's own)
    profile.myProfileProvider,
    profile.myGroupsProvider,
    currentUserProvider,
    // notifications / chat / qr / minigames / photos / party / feed / shards
    notificationsProvider,
    chatMessagesProvider,
    chatInboxProvider,
    // chat service + E2EE stores (2026-08-15): the ChatService singleton
    // caches sessions/outbox in memory — without flushing it, a same-process
    // sign-out/in keeps sending with the previous account's stale sessions
    // (the "Mensaje no descifrable" bug survived sign-out because of this).
    chatE2eeServiceProvider,
    chatE2eeRepositoryProvider,
    e2eePrekeyServiceProvider,
    e2eeKeyStoreProvider,
    e2eeSessionStoreProvider,
    myQrTokenProvider,
    minigameSessionsProvider,
    minigameInviteProvider,
    minigameInviteFriendsOnlyProvider,
    minigameGameStateProvider,
    eventPhotosProvider,
    partyMatchesProvider,
    feedProvider,
    shardLedgerProvider,
    // events
    eventDetailProvider,
    sessionStatusProvider,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (previous, next) {
      final prevAuth = previous?.valueOrNull;
      final nextAuth = next.valueOrNull;
      final prevUid = prevAuth?.user?['id'];
      final nextUid = nextAuth?.user?['id'];
      final loggedOut = prevAuth?.authenticated == true &&
          nextAuth?.authenticated != true;
      if (!loggedOut && prevUid == nextUid) return;
      // Logout (or account switch) → flush the per-account cache.
      for (final provider in _userScoped) {
        ref.invalidate(provider);
      }
    });
    return const SizedBox.shrink();
  }
}
