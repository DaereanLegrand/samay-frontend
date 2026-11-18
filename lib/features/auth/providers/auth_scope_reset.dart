import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/providers/user_provider.dart';
import 'package:samay/features/friends/providers/friends_cache_provider.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/notifications/providers/notifications_providers.dart';
import 'package:samay/features/packs/providers/packs_providers.dart';
import 'package:samay/features/profile/providers/profile_providers.dart' as profile;

/// Account-switch staleness guard.
///
/// **ON LOGOUT, FLUSH ALL DATA**: non-autodispose providers live for the whole
/// container lifetime, so after signing out — and then signing in as another
/// user in the same app session — every cached user-scoped provider would
/// otherwise show the PREVIOUS account's data (friends lists, requests,
/// groups, notifications, partidas, packs...).
///
/// This widget is mounted once at the app root (`SamayApp`, above the
/// Navigator) and `ref.listen`s [authStateProvider]: the instant the session
/// ends (authenticated → signed out, uid → null) — or the uid changes
/// between two sessions (safety net) — it invalidates every user-scoped
/// provider, flushing the whole per-account cache. The next read rebuilds
/// fresh for the new session.
///
/// Invalidating a `.family` provider clears ALL its instances. Derived
/// providers (`pendingCountsProvider`) recompute from
/// the invalidated roots. The realtime listeners independently unsubscribe on
/// sign-out.
///
/// Slim build note: only the kept features are listed. Guest → social
/// conversion keeps the SAME uid (GoTrue manual linking), so it is not an
/// account switch and deliberately does NOT flush the cache.
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
    friendsCacheProvider,
    // groups
    myGroupsProvider,
    groupInvitesProvider,
    groupDetailProvider,
    groupMembersProvider,
    // profile (both myGroups: the social tab's and the profile's own)
    profile.myProfileProvider,
    profile.myGroupsProvider,
    currentUserProvider,
    // notifications / minigames / packs
    notificationsProvider,
    minigameSessionsProvider,
    myMinigameSessionsProvider,
    myPendingInvitesProvider,
    minigameInviteProvider,
    minigameInviteFriendsOnlyProvider,
    minigameInviteContextProvider,
    minigameInviteeStatesProvider,
    minigameAliasesProvider,
    minigameGameStateProvider,
    minigameParticipantsProvider,
    minigamePlayerContentProvider,
    minigameResultProvider,
    sessionStatusProvider,
    promptPacksProvider,
    localPacksForProvider,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (previous, next) {
      final prevAuth = previous?.valueOrNull;
      final nextAuth = next.valueOrNull;
      final prevUid = prevAuth?.user?['id'];
      final nextUid = nextAuth?.user?['id'];
      final loggedOut =
          prevAuth?.authenticated == true && nextAuth?.authenticated != true;
      if (!loggedOut && prevUid == nextUid) return;
      // Logout (or account switch) → flush the per-account cache.
      for (final provider in _userScoped) {
        ref.invalidate(provider);
      }
      // SEC-033: the on-disk caches and network-image cache must be gone too —
      // invalidating providers only clears memory. An initial authentication
      // (no previous uid) is NOT a logout and must not wipe a cache warming
      // up for the same session.
      final switchedAccount =
          prevUid != null && nextUid != null && prevUid != nextUid;
      if (loggedOut || switchedAccount) {
        unawaited(ref.read(localDataPurgerProvider).purge());
      }
    });
    return const SizedBox.shrink();
  }
}
