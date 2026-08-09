import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/feature_flags.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/auth_guard.dart';
import 'package:samay/core/router/auth_refresh_notifier.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/features/auth/banned_screen.dart';
import 'package:samay/features/auth/login_screen.dart';
import 'package:samay/features/auth/welcome_screen.dart';
import 'package:samay/features/auth/signup_contact_screen.dart';
import 'package:samay/features/auth/otp_verification_screen.dart';
import 'package:samay/features/auth/age_gate_screen.dart';
import 'package:samay/features/auth/privacy_terms_screen.dart';
import 'package:samay/features/auth/profile_setup_screen.dart';
import 'package:samay/features/profile/profile_screen.dart';
import 'package:samay/features/profile/edit_profile_screen.dart';
import 'package:samay/features/profile/settings_screen.dart';
import 'package:samay/features/profile/public_profile_screen.dart';
import 'package:samay/features/profile/delete_account_screen.dart';
import 'package:samay/features/events/event_detail_screen.dart';
import 'package:samay/features/events/event_edit_screen.dart';
import 'package:samay/features/events/create_event_screen.dart';
import 'package:samay/features/feed/feed_screen.dart';
import 'package:samay/features/chat/chat_screen.dart';
import 'package:samay/features/friends/search_screen.dart';
import 'package:samay/features/friends/requests_screen.dart';
import 'package:samay/features/friends/friends_list_screen.dart';
import 'package:samay/features/friends/blocked_users_screen.dart';
import 'package:samay/features/groups/create_group_screen.dart';
import 'package:samay/features/groups/donate_shards_screen.dart';
import 'package:samay/features/groups/group_detail_screen.dart';
import 'package:samay/features/groups/invite_screen.dart';
import 'package:samay/features/groups/leaderboard_screen.dart';
import 'package:samay/features/groups/my_groups_screen.dart';
import 'package:samay/features/groups/group_members_screen.dart';
import 'package:samay/features/notifications/notification_center_screen.dart';
import 'package:samay/shared/widgets/route_error_screen.dart';
import 'package:samay/shared/widgets/v_coming_soon.dart';

/// Resolves a required path parameter, rendering [RouteErrorScreen] when it is
/// missing (finding NAV-03 / H-03) instead of crashing on a forced unwrap.
Widget _screenForId(
  GoRouterState state,
  String param,
  Widget Function(String id) builder, {
  required String errorMessage,
}) {
  final id = RouteParams.fromState(state, param);
  if (id == null) return RouteErrorScreen(message: errorMessage);
  return builder(id);
}

final routerProvider = Provider<GoRouter>((ref) {
  final authGuard = AuthGuard(ref);
  final authRefresh = AuthRefreshNotifier();
  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, _) => authRefresh.refresh());
  ref.onDispose(authRefresh.dispose);
  return GoRouter(
    initialLocation: RoutePaths.login,
    redirect: authGuard.call,
    refreshListenable: authRefresh,
    errorBuilder: (context, state) => RouteErrorScreen(
      title: AppLocalizations.of(context).routerRouteNotFound,
      message: AppLocalizations.of(context).routerRouteNotFoundBody,
    ),
    routes: [
      GoRoute(path: RoutePaths.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: RoutePaths.banned,
        builder: (_, _) => const BannedScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.signup,
        builder: (_, _) => const SignupContactScreen(),
      ),
      GoRoute(
        path: RoutePaths.verify,
        builder: (context, state) {
          final extra = VerifyExtra.fromState(state);
          if (extra == null) {
            return RouteErrorScreen(
              message: AppLocalizations.of(context).routerMissingSignupData,
            );
          }
          return OtpVerificationScreen(
            email: extra.email,
            password: extra.password,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.ageGate,
        builder: (_, state) =>
            AgeGateScreen(email: AgeGateExtra.fromState(state)?.email),
      ),
      GoRoute(
        path: RoutePaths.privacyTerms,
        builder: (context, state) {
          final extra = PrivacyTermsExtra.fromState(state);
          if (extra == null) {
            return RouteErrorScreen(
              message: AppLocalizations.of(context).routerMissingAgeGateData,
            );
          }
          return PrivacyTermsScreen(
            email: extra.email,
            dateOfBirth: extra.dateOfBirth,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.profileSetup,
        builder: (context, state) {
          final extra = ProfileSetupExtra.fromState(state);
          if (extra == null) {
            return RouteErrorScreen(
              message: AppLocalizations.of(context).routerMissingProfileData,
            );
          }
          return ProfileSetupScreen(
            email: extra.email,
            dateOfBirth: extra.dateOfBirth,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(
          currentIndex: shellIndexFor(state.matchedLocation),
          child: child,
        ),
        routes: [
          GoRoute(path: RoutePaths.mainFeed, builder: (_, _) => const FeedScreen()),
          GoRoute(path: RoutePaths.mainGroups, builder: (_, _) => const MyGroupsScreen()),
          GoRoute(
            path: RoutePaths.mainEvents,
            builder: (context, _) => FlagGate(
              flag: AppFeatureFlag.events,
              child: VComingSoonScreen(
                title: AppLocalizations.of(context).comingSoonEventsTitle,
                description: AppLocalizations.of(context).comingSoonEventsBody,
              ),
            ),
          ),
          GoRoute(
            path: RoutePaths.mainNotifications,
            builder: (_, _) => FlagGate(
              flag: AppFeatureFlag.notifications,
              child: const NotificationCenterScreen(),
            ),
          ),
          GoRoute(path: RoutePaths.mainProfile, builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        // NOTE (I-55): `/event/create` (ECRT, I-54) must be declared BEFORE
        // this route when it lands — go_router matches in order and
        // `/event/:eventId` would shadow it otherwise.
        path: RoutePaths.eventDetail(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (eventId) => EventDetailScreen(eventId: eventId),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.eventEdit(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (eventId) => EventEditScreen(eventId: eventId),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.eventInvite(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (_) => VComingSoonScreen(
            title: AppLocalizations.of(context).comingSoonEventInviteTitle,
            description: AppLocalizations.of(context).comingSoonEventInviteBody,
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.eventPhotos(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (_) => VComingSoonScreen(
            title: AppLocalizations.of(context).comingSoonPhotosTitle,
            description: AppLocalizations.of(context).comingSoonPhotosBody,
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.eventCollage(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (_) => VComingSoonScreen(
            title: AppLocalizations.of(context).comingSoonCollageTitle,
            description: AppLocalizations.of(context).comingSoonCollageBody,
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.eventInviteToken(':inviteToken'),
        builder: (context, state) => _screenForId(
          state,
          'inviteToken',
          (_) => VComingSoonScreen(
            title: AppLocalizations.of(context).comingSoonInvitationTitle,
            description: AppLocalizations.of(context).comingSoonInvitationBody,
          ),
          errorMessage: AppLocalizations.of(context).routerInvalidInvite,
        ),
      ),
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
        path: RoutePaths.donateToGroup(':groupId'),
        builder: (context, state) => _screenForId(
          state,
          'groupId',
          (groupId) => DonateShardsScreen(
            groupId: groupId,
            groupName: state.extra is String
                ? state.extra as String
                : AppLocalizations.of(context).commonGroup,
          ),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        // NOTE (I-54): no standalone `/event/create` path — it would be
        // shadowed by `/event/:eventId` (registered above) unless declared
        // BEFORE it; ECRT creates from group detail and public events are
        // reachable here via the visibility toggle. Gated on the events flag
        // (dark-first): disabled keeps the previous coming-soon copy.
        path: RoutePaths.createGroupEvent(':groupId'),
        builder: (context, state) => _screenForId(
          state,
          'groupId',
          (groupId) => FlagGate(
            flag: AppFeatureFlag.events,
            fallback: VComingSoonScreen(
              title: AppLocalizations.of(context).comingSoonCreateEventTitle,
              description:
                  AppLocalizations.of(context).comingSoonCreateEventBody,
            ),
            child: CreateEventScreen(groupId: groupId),
          ),
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
        path: RoutePaths.groupsLeaderboard,
        builder: (_, _) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: RoutePaths.chat(':chatId'),
        builder: (context, state) => _screenForId(
          state,
          'chatId',
          (chatId) => ChatScreen(chatId: chatId),
          errorMessage: AppLocalizations.of(context).routerChatNotFound,
        ),
      ),
      GoRoute(path: RoutePaths.userSearch, builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: RoutePaths.userProfile(':userId'),
        builder: (context, state) => _screenForId(
          state,
          'userId',
          (userId) => PublicProfileScreen(userId: userId),
          errorMessage: AppLocalizations.of(context).routerUserNotFound,
        ),
      ),
      GoRoute(path: RoutePaths.friendsRequests, builder: (_, _) => const RequestsScreen()),
      GoRoute(path: RoutePaths.friendsList, builder: (_, _) => const FriendsListScreen()),
      GoRoute(path: RoutePaths.blockedUsers, builder: (_, _) => const BlockedUsersScreen()),
      GoRoute(
        path: RoutePaths.qr(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (_) => VComingSoonScreen(
            title: AppLocalizations.of(context).comingSoonQrTitle,
            description: AppLocalizations.of(context).comingSoonQrBody,
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.scanner(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (_) => VComingSoonScreen(
            title: AppLocalizations.of(context).comingSoonScannerTitle,
            description: AppLocalizations.of(context).comingSoonScannerBody,
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.subscriptions,
        builder: (context, _) => FlagGate(
          flag: AppFeatureFlag.subscriptions,
          child: VComingSoonScreen(
            title: AppLocalizations.of(context).comingSoonSubscriptionsTitle,
            description:
                AppLocalizations.of(context).comingSoonSubscriptionsBody,
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.partyFinder,
        builder: (context, _) => FlagGate(
          flag: AppFeatureFlag.partyFinder,
          child: VComingSoonScreen(
            title: AppLocalizations.of(context).comingSoonPartyFinderTitle,
            description:
                AppLocalizations.of(context).comingSoonPartyFinderBody,
          ),
        ),
      ),
      GoRoute(path: RoutePaths.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: RoutePaths.deleteAccount, builder: (_, _) => const DeleteAccountScreen()),
      GoRoute(path: RoutePaths.profileEdit, builder: (_, _) => const EditProfileScreen()),
    ],
  );
});
