import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/auth_guard.dart';
import 'package:samay/core/router/auth_refresh_notifier.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/auth/screens/banned_screen.dart';
import 'package:samay/features/auth/screens/onboarding_screen.dart';
import 'package:samay/features/auth/screens/onboarding_declined_screen.dart';
import 'package:samay/features/auth/screens/sign_in_screen.dart';
import 'package:samay/features/friends/screens/blocked_users_screen.dart';
import 'package:samay/features/friends/screens/friends_list_screen.dart';
import 'package:samay/features/friends/screens/muted_users_screen.dart';
import 'package:samay/features/friends/screens/requests_screen.dart';
import 'package:samay/features/friends/screens/search_screen.dart';
import 'package:samay/features/groups/screens/create_group_screen.dart';
import 'package:samay/features/groups/screens/group_detail_screen.dart';
import 'package:samay/features/groups/screens/group_members_screen.dart';
import 'package:samay/features/groups/screens/group_theme_screen.dart';
import 'package:samay/features/groups/screens/invite_screen.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/screens/charades_screen.dart';
import 'package:samay/features/minigames/screens/drunk_bottle_screen.dart';
import 'package:samay/features/minigames/screens/games_home_screen.dart';
import 'package:samay/features/minigames/screens/local_bottle_screen.dart';
import 'package:samay/features/minigames/screens/local_charades_screen.dart';
import 'package:samay/features/minigames/screens/local_lobby_screen.dart';
import 'package:samay/features/minigames/screens/local_leaderboard_screen.dart';
import 'package:samay/features/minigames/screens/local_match_screen.dart';
import 'package:samay/features/minigames/screens/minigame_detail_screen.dart';
import 'package:samay/features/minigames/screens/minigame_leaderboard_screen.dart';
import 'package:samay/features/minigames/screens/minigame_session_detail_screen.dart';
import 'package:samay/features/minigames/screens/minigames_screen.dart';
import 'package:samay/features/minigames/screens/join_scanner_screen.dart';
import 'package:samay/features/minigames/screens/truth_dare_screen.dart';
import 'package:samay/features/minigames/screens/two_lies_screen.dart';
import 'package:samay/features/moderation/screens/appeals_screen.dart';
import 'package:samay/features/notifications/screens/notification_center_screen.dart';
import 'package:samay/features/packs/screens/prompt_packs_screen.dart';
import 'package:samay/features/profile/screens/app_theme_screen.dart';
import 'package:samay/features/profile/screens/delete_account_screen.dart';
import 'package:samay/features/profile/screens/edit_profile_screen.dart';
import 'package:samay/features/profile/screens/export_data_screen.dart';
import 'package:samay/features/profile/screens/profile_screen.dart';
import 'package:samay/features/profile/screens/public_profile_screen.dart';
import 'package:samay/features/profile/screens/settings_screen.dart';
import 'package:samay/features/social/screens/social_screen.dart';
import 'package:samay/features/packs/screens/paywall_screen.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/route_error_screen.dart';

/// Resolves a required path parameter, rendering [RouteErrorScreen] when it is
/// missing instead of crashing on a forced unwrap.
Widget _screenForId(
  GoRouterState state,
  String param,
  Widget Function(String id) builder, {
  required String errorMessage,
}) {
  final id = state.pathParameters[param];
  if (id == null || id.isEmpty) {
    return RouteErrorScreen(message: errorMessage);
  }
  return builder(id);
}

final routerProvider = Provider<GoRouter>((ref) {
  final authGuard = AuthGuard(ref);
  final authRefresh = AuthRefreshNotifier();
  ref.listen<AsyncValue<AuthState>>(
    authStateProvider,
    (previous, next) => authRefresh.refresh(),
  );
  ref.onDispose(authRefresh.dispose);
  return GoRouter(
    initialLocation: RoutePaths.gamesHome,
    redirect: authGuard.call,
    refreshListenable: authRefresh,
    extraCodec: const RouteExtraCodec(),
    errorBuilder: (context, state) => RouteErrorScreen(
      title: AppLocalizations.of(context).routerRouteNotFound,
      message: AppLocalizations.of(context).routerRouteNotFoundBody,
    ),
    routes: [
      // ── Entry ────────────────────────────────────────────────────────────
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboardingDeclined,
        builder: (_, _) => const OnboardingDeclinedScreen(),
      ),
      GoRoute(
        path: RoutePaths.gamesHome,
        builder: (_, _) => const GamesHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.signIn,
        builder: (_, _) => const SignInScreen(),
      ),
      GoRoute(path: RoutePaths.banned, builder: (_, _) => const BannedScreen()),
      GoRoute(
        path: RoutePaths.appeals,
        builder: (_, state) =>
            AppealsScreen(banAppeal: state.uri.queryParameters['ban'] == '1'),
      ),

      // ── Games: server (multi-device) ──────────────────────────────────────
      GoRoute(
        path: RoutePaths.minigamesDirect,
        builder: (_, _) => const MinigamesScreen(),
      ),
      GoRoute(
        path: RoutePaths.joinScanner,
        builder: (_, _) => const JoinScannerScreen(),
      ),
      GoRoute(
        path: RoutePaths.minigames(':groupId'),
        builder: (context, state) => _screenForId(
          state,
          'groupId',
          (groupId) => MinigamesScreen(groupId: groupId),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.minigame(':gameType'),
        builder: (context, state) => _screenForId(
          state,
          'gameType',
          (gameType) {
            final type = minigameTypeFromString(gameType);
            if (type == null) return const RouteErrorScreen();
            return MinigameDetailScreen(gameType: type);
          },
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      // The games-first flow: the deck's play button opens the LOBBY, the
      // lobby's play button opens the game itself. Only the lobby collects
      // players; every play screen just reads the roster it left behind.
      GoRoute(
        path: RoutePaths.localLobby(':gameType'),
        builder: (context, state) => _screenForId(
          state,
          'gameType',
          (gameType) {
            final type = minigameTypeFromString(gameType);
            if (type == null) return const RouteErrorScreen();
            return LocalLobbyScreen(gameType: type);
          },
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.localMatch(':gameType'),
        builder: (context, state) => _screenForId(
          state,
          'gameType',
          (gameType) {
            final type = minigameTypeFromString(gameType);
            if (type == null) return const RouteErrorScreen();
            return LocalMatchScreen(gameType: type);
          },
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.localCharades(':gameType'),
        builder: (context, state) => _screenForId(
          state,
          'gameType',
          (gameType) {
            final type = minigameTypeFromString(gameType);
            if (type == null) return const RouteErrorScreen();
            return LocalCharadesScreen(gameType: type);
          },
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.localBottle(':gameType'),
        builder: (context, state) => _screenForId(
          state,
          'gameType',
          (gameType) {
            final type = minigameTypeFromString(gameType);
            if (type == null) return const RouteErrorScreen();
            return LocalBottleScreen(gameType: type);
          },
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.localLeaderboard,
        builder: (_, _) => const LocalLeaderboardScreen(),
      ),
      GoRoute(
        path: RoutePaths.minigameSession(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => MinigameSessionDetailScreen(sessionId: sessionId),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.truthDare(':sessionId'),
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.path,
          child: _screenForId(
            state,
            'sessionId',
            (sessionId) => TruthDareScreen(sessionId: sessionId),
            errorMessage: AppLocalizations.of(context).routerGroupNotFound,
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.twoLiesOneTruth(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => TwoLiesScreen(sessionId: sessionId),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.drunkBottle(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => DrunkBottleScreen(sessionId: sessionId),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.charades(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => CharadesScreen(sessionId: sessionId),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.minigameLeaderboard(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => MinigameLeaderboardScreen(
            sessionId: sessionId,
            initialParticipantId: state.uri.queryParameters['p'],
          ),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),

      // ── Social: friends + groups ──────────────────────────────────────────
      GoRoute(path: RoutePaths.social, builder: (_, _) => const SocialScreen()),
      GoRoute(
        path: RoutePaths.groupCreate,
        builder: (_, _) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: RoutePaths.groupDetail(':groupId'),
        builder: (context, state) => _screenForId(
          state,
          'groupId',
          (groupId) => GroupDetailScreen(groupId: groupId),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.groupMembers(':groupId'),
        builder: (context, state) => _screenForId(
          state,
          'groupId',
          (groupId) => GroupMembersScreen(groupId: groupId),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.groupTheme(':groupId'),
        builder: (context, state) => _screenForId(
          state,
          'groupId',
          (groupId) => GroupThemeScreen(groupId: groupId),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.inviteToGroup(':groupId'),
        builder: (context, state) => _screenForId(
          state,
          'groupId',
          (groupId) => InviteScreen(groupId: groupId),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.userSearch,
        builder: (_, _) => const SearchScreen(),
      ),
      GoRoute(
        path: RoutePaths.userProfile(':userId'),
        builder: (context, state) => _screenForId(
          state,
          'userId',
          (userId) => PublicProfileScreen(userId: userId),
          errorMessage: AppLocalizations.of(context).routerUserNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.friendsRequests,
        builder: (_, _) => const RequestsScreen(),
      ),
      GoRoute(
        path: RoutePaths.friendsList,
        builder: (_, _) => const FriendsListScreen(),
      ),
      GoRoute(
        path: RoutePaths.blockedUsers,
        builder: (_, _) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: RoutePaths.mutedUsers,
        builder: (_, _) => const MutedUsersScreen(),
      ),

      // ── Packs / monetization ─────────────────────────────────────────────
      GoRoute(
        path: RoutePaths.promptPacks,
        builder: (_, _) => const PromptPacksScreen(),
      ),
      GoRoute(
        // Dark-first: a build without a RevenueCat key renders nothing.
        path: RoutePaths.subscriptions,
        builder: (_, _) => const PaywallScreen(),
      ),

      // ── Notifications ────────────────────────────────────────────────────
      GoRoute(
        path: RoutePaths.notifications,
        builder: (_, _) => const NotificationCenterScreen(),
      ),

      // ── Profile / settings ───────────────────────────────────────────────
      GoRoute(
        path: RoutePaths.profile,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.profileEdit,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.appTheme,
        builder: (_, _) => const AppThemeScreen(),
      ),
      GoRoute(
        path: RoutePaths.deleteAccount,
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: RoutePaths.exportData,
        builder: (_, _) => const ExportDataScreen(),
      ),
    ],
  );
});
