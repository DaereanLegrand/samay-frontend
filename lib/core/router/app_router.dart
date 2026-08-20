import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/auth_guard.dart';
import 'package:samay/core/router/auth_refresh_notifier.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/telemetry_service.dart';
import 'package:samay/core/telemetry/route_observer.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/features/auth/screens/banned_screen.dart';
import 'package:samay/features/auth/screens/login_screen.dart';
import 'package:samay/features/auth/screens/forgot_password_screen.dart';
import 'package:samay/features/auth/screens/welcome_screen.dart';
import 'package:samay/features/auth/screens/signup_contact_screen.dart';
import 'package:samay/features/auth/screens/otp_verification_screen.dart';
import 'package:samay/features/auth/screens/age_gate_screen.dart';
import 'package:samay/features/auth/screens/privacy_terms_screen.dart';
import 'package:samay/features/auth/screens/profile_setup_screen.dart';
import 'package:samay/features/profile/screens/profile_screen.dart';
import 'package:samay/features/profile/screens/edit_profile_screen.dart';
import 'package:samay/features/profile/screens/settings_screen.dart';
import 'package:samay/features/profile/screens/public_profile_screen.dart';
import 'package:samay/features/profile/screens/delete_account_screen.dart';
import 'package:samay/features/events/screens/create_event_screen.dart';
import 'package:samay/features/events/screens/event_collage_screen.dart';
import 'package:samay/features/events/screens/event_detail_screen.dart';
import 'package:samay/features/events/screens/event_edit_screen.dart';
import 'package:samay/features/events/screens/my_events_screen.dart';
import 'package:samay/features/events/widgets/event_invite_route.dart';
import 'package:samay/features/feed/screens/feed_screen.dart';
import 'package:samay/features/photos/screens/photo_gallery_screen.dart';
import 'package:samay/features/chat/screens/chat_list_screen.dart';
import 'package:samay/features/chat/screens/chat_screen.dart';
import 'package:samay/features/cosmetics/screens/cosmetics_shop_screen.dart';
import 'package:samay/features/friends/screens/search_screen.dart';
import 'package:samay/features/friends/screens/requests_screen.dart';
import 'package:samay/features/friends/screens/friends_list_screen.dart';
import 'package:samay/features/friends/screens/blocked_users_screen.dart';
import 'package:samay/features/groups/screens/create_group_screen.dart';
import 'package:samay/features/groups/screens/donate_shards_screen.dart';
import 'package:samay/features/groups/screens/group_detail_screen.dart';
import 'package:samay/features/groups/screens/invite_screen.dart';
import 'package:samay/features/groups/screens/leaderboard_screen.dart';
import 'package:samay/features/groups/screens/group_members_screen.dart';
import 'package:samay/features/social/screens/social_screen.dart';
import 'package:samay/features/social/screens/user_ranking_screen.dart';
import 'package:samay/features/minigames/screens/minigames_screen.dart';
import 'package:samay/features/notifications/screens/notification_center_screen.dart';
import 'package:samay/features/party_finder/screens/party_finder_screen.dart';
import 'package:samay/features/qr/screens/attendance_qr_screen.dart';
import 'package:samay/features/qr/screens/qr_scanner_screen.dart';
import 'package:samay/features/shards/screens/shard_ledger_screen.dart';
import 'package:samay/features/subscriptions/screens/paywall_screen.dart';
import 'package:samay/shared/widgets/route_error_screen.dart';
import 'package:uuid/uuid.dart';

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

/// NAV-08: the shell tab routes build [NoTransitionPage]s — switching tabs
/// must NOT slide or zoom (Juega uses NoTransitionPage for its shell
/// children; the tab switch's subtle motion comes from `MainShell`'s
/// [VTabFade] 150ms fade-in instead — DISCO §6.1 "subtle, fast", U-18).
/// Pushed routes keep their normal transitions (§6.1 page fade-through is a
/// separate surface; see the U-18 daily log).
///
/// The page keeps go_router's default naming (`state.name ?? state.path`) —
/// the telemetry observer (I-68) reads `RouteSettings.name`, so a custom
/// pageBuilder must set it explicitly or tab screens stop reporting
/// `screen_view` (U-29 integration-suite finding: U-18's custom pages
/// dropped the name; the telemetry shell flow went red).
CustomTransitionPage<void> _tabPage(GoRouterState state, Widget child) {
  return NoTransitionPage(
    key: state.pageKey,
    name: state.name ?? state.path,
    child: child,
  );
}

/// EINV (I-66): one `/event/:param` route serves both the event detail (UUID
/// event ids) and the invite-token deep links (`samay://event/{token}`,
/// MVP §6.3). The former `/event/:inviteToken` route was SHADOWED by this
/// route (I-55's documented ordering issue) and has been removed — instead
/// the handler (`DeepLinkHandler`) resolves the token to an event id and the
/// route branches here: UUID params go straight to [EventDetailScreen],
/// token-shaped params resolve through [EventInviteRoute] (loading →
/// detail/not-found). `nonStrict` UUID validation is format-only, matching
/// the repo's test fixtures; the DB stores ids and tokens as text.
Widget _eventDetailRoute(BuildContext context, GoRouterState state) {
  final param = RouteParams.fromState(state, 'eventId');
  if (param == null || param.isEmpty) {
    return RouteErrorScreen(
      message: AppLocalizations.of(context).routerEventNotFound,
    );
  }
  if (Uuid.isValidUUID(
    fromString: param,
    validationMode: ValidationMode.nonStrict,
  )) {
    return EventDetailScreen(eventId: param);
  }
  return EventInviteRoute(token: param);
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
    initialLocation: RoutePaths.login,
    redirect: authGuard.call,
    refreshListenable: authRefresh,
    // U-29 smoke finding: auth-state emissions refresh the router, which
    // re-parses the engine route-information state — without the codec the
    // pushed typed extras (VerifyExtra/…, the OTP funnel) serialize as null
    // and the pushed screens flip to RouteErrorScreen. See RouteExtraCodec.
    extraCodec: const RouteExtraCodec(),
    // I-68: telemetry — every route change reports a `screen_view` event via
    // the TelemetryService (stub mode = no-op with an info log). One observer
    // per navigator (a NavigatorObserver can attach to only one navigator):
    // the root one covers the plain routes; the ShellRoute's own observer
    // covers the tab screens (the root push of the shell page itself carries
    // no name and is ignored by the observer).
    observers: [RouterObserver(ref.read(telemetryServiceProvider))],
    errorBuilder: (context, state) => RouteErrorScreen(
      title: AppLocalizations.of(context).routerRouteNotFound,
      message: AppLocalizations.of(context).routerRouteNotFoundBody,
    ),
    routes: [
      GoRoute(
        path: RoutePaths.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(path: RoutePaths.banned, builder: (_, _) => const BannedScreen()),
      GoRoute(path: RoutePaths.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        // U-14 R3: the dedicated password-recovery screen. Registered with
        // the other pre-auth routes (before the ShellRoute) so no parameter
        // pattern can shadow its static path; the guard treats it as public.
        path: RoutePaths.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
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
        // I-68: the shell's nested Navigator needs its own observer (see the
        // routerProvider note above) so tab switches report screen_view too.
        observers: [RouterObserver(ref.read(telemetryServiceProvider))],
        routes: [
          // I-69: the feed is LIVE but the flag stays wired as the
          // kill-switch/remote-config knob (I-58 flipped it on; the gate is
          // what makes the knob functional).
          GoRoute(
            path: RoutePaths.mainFeed,
            pageBuilder: (context, state) => _tabPage(
              state,
              const FlagGate(flag: AppFeatureFlag.feed, child: FeedScreen()),
            ),
          ),
          GoRoute(
            path: RoutePaths.mainGroups,
            pageBuilder: (context, state) =>
                _tabPage(state, const SocialScreen()),
          ),
          GoRoute(
            // I-69: the events tab is LIVE (R1 events sweep) but the flag
            // stays wired as the kill-switch/remote-config knob — the real
            // [MyEventsScreen] ships behind it.
            path: RoutePaths.mainEvents,
            pageBuilder: (context, state) => _tabPage(
              state,
              const FlagGate(
                flag: AppFeatureFlag.events,
                child: MyEventsScreen(),
              ),
            ),
          ),
          GoRoute(
            path: RoutePaths.mainNotifications,
            pageBuilder: (context, state) => _tabPage(
              state,
              const FlagGate(
                flag: AppFeatureFlag.notifications,
                child: NotificationCenterScreen(),
              ),
            ),
          ),
          GoRoute(
            path: RoutePaths.mainProfile,
            pageBuilder: (context, state) =>
                _tabPage(state, const ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        // EINV (I-66): `/event/create` (ECRT, I-54) must be declared BEFORE
        // this route when it lands — go_router matches in order and
        // `/event/:eventId` would shadow it otherwise. The param is either a
        // UUID event id or an invite token (see [_eventDetailRoute]).
        path: RoutePaths.eventDetail(':eventId'),
        builder: (context, state) => _eventDetailRoute(context, state),
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
        // EINV (I-66): the invite sub-screen, gated on the events flag
        // (I-69) as the kill-switch knob — the child is the real
        // [EventInviteRoute], which resolves the invite token (UUID event
        // ids land on it too; EventInviteRoute's provider handles both).
        path: RoutePaths.eventInvite(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (eventId) => FlagGate(
            flag: AppFeatureFlag.events,
            child: EventInviteRoute(token: eventId),
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        // PHUP (I-59): gated on the photoUpload flag as the kill-switch knob
        // — the child is the real gallery.
        path: RoutePaths.eventPhotos(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (eventId) => FlagGate(
            flag: AppFeatureFlag.photoUpload,
            child: PhotoGalleryScreen(eventId: eventId),
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        // COLL (phase-08): the auto-collage, gated on the photoUpload flag
        // as the kill-switch knob — the child is the real photo-wall screen.
        path: RoutePaths.eventCollage(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (eventId) => FlagGate(
            flag: AppFeatureFlag.photoUpload,
            child: EventCollageScreen(eventId: eventId),
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
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
        // as the kill-switch knob.
        path: RoutePaths.createGroupEvent(':groupId'),
        builder: (context, state) => _screenForId(
          state,
          'groupId',
          (groupId) => FlagGate(
            flag: AppFeatureFlag.events,
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
        // GMCR (I-63): the group minigames hub, gated on the minigames flag
        // as the kill-switch knob. No static /minigames routes exist, so
        // :groupId cannot be shadowed (registered after the group routes on
        // purpose).
        path: RoutePaths.minigames(':groupId'),
        builder: (context, state) => _screenForId(
          state,
          'groupId',
          (groupId) => FlagGate(
            flag: AppFeatureFlag.minigames,
            child: MinigamesScreen(groupId: groupId),
          ),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.groupsLeaderboard,
        builder: (_, _) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: RoutePaths.userRanking,
        builder: (_, _) => const UserRankingScreen(),
      ),
      GoRoute(
        // I-69: chat is LIVE (I-38 E2EE) but the flag stays wired as the
        // kill-switch/remote-config knob — the disabled state restores the
        // neutral FlagGate fallback.
        path: RoutePaths.chat(':chatId'),
        builder: (context, state) => _screenForId(
          state,
          'chatId',
          (chatId) => FlagGate(
            flag: AppFeatureFlag.chat,
            child: ChatScreen(chatId: chatId),
          ),
          errorMessage: AppLocalizations.of(context).routerChatNotFound,
        ),
      ),
      GoRoute(
        // Chat inbox (2026-08-15): the feed's chat button lands here.
        path: RoutePaths.chatList,
        builder: (context, state) => const FlagGate(
          flag: AppFeatureFlag.chat,
          child: ChatListScreen(),
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
        // QRAT/QRSC (I-57): gated on the qr flag as the kill-switch knob.
        path: RoutePaths.qr(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (eventId) => FlagGate(
            flag: AppFeatureFlag.qr,
            child: AttendanceQrScreen(eventId: eventId),
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        path: RoutePaths.scanner(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (eventId) => FlagGate(
            flag: AppFeatureFlag.qr,
            child: QrScannerScreen(eventId: eventId),
          ),
          errorMessage: AppLocalizations.of(context).routerEventNotFound,
        ),
      ),
      GoRoute(
        // PLAN (I-61): gated on the subscriptions flag (dark-first — the
        // disabled state renders the neutral FlagGate fallback while the
        // RevenueCat SDK key is absent; purchases stay dark).
        path: RoutePaths.subscriptions,
        builder: (context, _) => const FlagGate(
          flag: AppFeatureFlag.subscriptions,
          child: PaywallScreen(),
        ),
      ),
      GoRoute(
        // PFND (I-60): gated on the partyFinder flag as the kill-switch knob.
        path: RoutePaths.partyFinder,
        builder: (context, _) => const FlagGate(
          flag: AppFeatureFlag.partyFinder,
          child: PartyFinderScreen(),
        ),
      ),
      GoRoute(
        // COSM (I-62): gated on the cosmeticsSection flag as the kill-switch
        // knob.
        path: RoutePaths.cosmetics,
        builder: (context, _) => const FlagGate(
          flag: AppFeatureFlag.cosmeticsSection,
          child: CosmeticsShopScreen(),
        ),
      ),
      GoRoute(
        // SLED (I-64): the shard/preshard ledger history. NOT flag-gated —
        // the shards economy is LIVE (donations exist and are recorded), so
        // the ledger ships open like the profile balance it links from.
        path: RoutePaths.shardsLedger,
        builder: (_, _) => const ShardLedgerScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.deleteAccount,
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: RoutePaths.profileEdit,
        builder: (_, _) => const EditProfileScreen(),
      ),
    ],
  );
});
