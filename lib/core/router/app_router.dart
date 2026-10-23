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
import 'package:samay/features/profile/screens/export_data_screen.dart';
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
import 'package:samay/features/friends/screens/muted_users_screen.dart';
import 'package:samay/features/moderation/screens/appeals_screen.dart';
import 'package:samay/features/groups/screens/create_group_screen.dart';
import 'package:samay/features/groups/screens/donate_shards_screen.dart';
import 'package:samay/features/groups/screens/group_detail_screen.dart';
import 'package:samay/features/groups/screens/invite_screen.dart';
import 'package:samay/features/groups/screens/group_members_screen.dart';
import 'package:samay/features/social/screens/rankings_screen.dart';
import 'package:samay/features/social/screens/social_screen.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/screens/games_tab_screen.dart';
import 'package:samay/features/minigames/screens/minigame_detail_screen.dart';
import 'package:samay/features/minigames/screens/minigame_leaderboard_screen.dart';
import 'package:samay/features/minigames/screens/minigames_screen.dart';
import 'package:samay/features/minigames/screens/minigame_session_detail_screen.dart';
import 'package:samay/features/minigames/screens/charades_screen.dart';
import 'package:samay/features/minigames/screens/drunk_bottle_screen.dart';
import 'package:samay/features/minigames/screens/truth_dare_screen.dart';
import 'package:samay/features/minigames/screens/two_lies_screen.dart';
import 'package:samay/features/notifications/screens/notification_center_screen.dart';
import 'package:samay/features/qr/screens/attendance_code_screen.dart';
import 'package:samay/features/qr/screens/qr_scanner_screen.dart';
import 'package:samay/features/shards/screens/shard_ledger_screen.dart';
import 'package:samay/features/subscriptions/screens/paywall_screen.dart';
import 'package:samay/shared/widgets/route_error_screen.dart';
import 'package:uuid/uuid.dart';

/// Resolves a required path parameter, rendering [RouteErrorScreen] when it is
/// missing instead of crashing on a forced unwrap.
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

/// The shell tab routes build [NoTransitionPage]s — switching tabs
/// must NOT slide or zoom (the reference app uses NoTransitionPage for its shell
/// children; the tab switch's subtle motion comes from `MainShell`'s
/// [VTabFade] 150ms fade-in — "subtle, fast").
/// Pushed routes keep their normal transitions.
///
/// The page keeps go_router's default naming (`state.name ?? state.path`).
CustomTransitionPage<void> _tabPage(GoRouterState state, Widget child) {
  return NoTransitionPage(
    key: state.pageKey,
    name: state.name ?? state.path,
    child: child,
  );
}

/// EINV: one `/event/:param` route serves both the event detail (UUID
/// event ids) and the invite-token deep links (`samay://event/{token}`,
/// MVP §6.3). The former `/event/:inviteToken` route was SHADOWED by this
/// route and has been removed — instead
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
    // smoke finding: auth-state emissions refresh the router, which
    // re-parses the engine route-information state — without the codec the
    // pushed typed extras (VerifyExtra/…, the OTP funnel) serialize as null
    // and the pushed screens flip to RouteErrorScreen. See RouteExtraCodec.
    extraCodec: const RouteExtraCodec(),
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
        // the dedicated password-recovery screen. Registered with
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
        routes: [
          // the feed is live; the flag remains the
          // kill-switch/remote-config knob (the gate is
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
            // The Games tab: the plugged minigames in a column
            // list. Gated on the minigames flag (kill-switch knob).
            path: RoutePaths.mainGames,
            pageBuilder: (context, state) => _tabPage(
              state,
              const FlagGate(
                flag: AppFeatureFlag.minigames,
                child: GamesTabScreen(),
              ),
            ),
          ),
          GoRoute(
            // the events tab is LIVE but the flag
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
        // EINV: `/event/create` must be declared BEFORE
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
        // EINV: the invite sub-screen, gated on the events flag
        // as the kill-switch knob — the child is the real
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
        // gated on the photoUpload flag as the kill-switch knob
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
      // The events-tab "Crear evento" entry: a standalone public
      // flow reachable straight from `/main/events`. `/events/create` is
      // intentionally plural — `/event/:eventId` (registered above) must keep
      // owning the singular segment. Gated on the events flag.
      GoRoute(
        path: RoutePaths.eventCreate,
        builder: (context, state) => const FlagGate(
          flag: AppFeatureFlag.events,
          child: CreateEventScreen(),
        ),
      ),
      GoRoute(
        // NOTE: no standalone `/event/create` path — it would be
        // shadowed by `/event/:eventId` (registered above) unless declared
        // BEFORE it; groups create from group detail and public events are
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
        // Direct (group-less) minigames hub:
        // the DIRECT scope is the default here (a new user with zero groups
        // can play with a friend). Gated on the minigames flag; the toggle
        // inside the hub offers group play. Registered BEFORE the:groupId
        // hub so the static path is never shadowed.
        path: RoutePaths.minigamesDirect,
        builder: (_, _) => const FlagGate(
          flag: AppFeatureFlag.minigames,
          child: MinigamesScreen(),
        ),
      ),
      GoRoute(
        // the group minigames hub, gated on the minigames flag
        // as the kill-switch knob. The static /minigames direct route is
        // registered above so:groupId cannot be shadowed.
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
        // The dedicated per-game landing page: the feed opens
        // /minigames/game/:gameType — title + explanation + audience +
        // "Nueva partida" + the ongoing partidas list. Gated on the
        // minigames flag; an unknown game_type parses to null and shows the
        // route error screen.
        path: RoutePaths.minigame(':gameType'),
        builder: (context, state) => _screenForId(
          state,
          'gameType',
          (gameType) {
            final type = minigameTypeFromString(gameType);
            if (type == null) {
              return const RouteErrorScreen();
            }
            return FlagGate(
              flag: AppFeatureFlag.minigames,
              child: MinigameDetailScreen(gameType: type),
            );
          },
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        // Session detail (140_minigame_invites): accept/decline a pending
        // invite, live status. The fixed `/session` segment keeps this from
        // being shadowed by the `:groupId` hub route.
        path: RoutePaths.minigameSession(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => FlagGate(
            flag: AppFeatureFlag.minigames,
            child: MinigameSessionDetailScreen(sessionId: sessionId),
          ),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        // The Verdad o Reto play screen (150_minigame_play): the reusable
        // play engine's first concrete game. Gated on the minigames flag as
        // the kill-switch knob. A fixed segment keeps the:groupId hub from
        // shadowing it.
        //
        // OPAQUE/INSTANT transition: the countdown→playing
        // handoff pushes this route while the lobby sits underneath. A sliding
        // transition exposed BOTH screens for ~250ms; a NoTransitionPage makes
        // the match screen the only screen that ever paints (the lobby cover is
        // held by MinigameSessionDetailScreen until this page commits).
        path: RoutePaths.truthDare(':sessionId'),
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.path,
          child: _screenForId(
            state,
            'sessionId',
            (sessionId) => FlagGate(
              flag: AppFeatureFlag.minigames,
              child: TruthDareScreen(sessionId: sessionId),
            ),
            errorMessage: AppLocalizations.of(context).routerGroupNotFound,
          ),
        ),
      ),
      GoRoute(
        // Finished-match leaderboard: the dedicated screen wrapping
        // FinishedLeaderboard, optionally focused on one participant via `?p=`.
        // A fixed `/leaderboard` segment keeps the hub routes unshadowed.
        path: RoutePaths.minigameLeaderboard(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => FlagGate(
            flag: AppFeatureFlag.minigames,
            child: MinigameLeaderboardScreen(
              sessionId: sessionId,
              initialParticipantId: state.uri.queryParameters['p'],
            ),
          ),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        // The Two Lies, One Truth play screen (208_minigame_two_lies_one_truth).
        path: RoutePaths.twoLiesOneTruth(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => FlagGate(
            flag: AppFeatureFlag.minigames,
            child: TwoLiesScreen(sessionId: sessionId),
          ),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        // The Botella (drunk bottle) play screen (209_minigame_drunk_bottle).
        // A fixed segment keeps the:groupId hub from shadowing it.
        path: RoutePaths.drunkBottle(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => FlagGate(
            flag: AppFeatureFlag.minigames,
            child: DrunkBottleScreen(sessionId: sessionId),
          ),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        // The Charadas play screen (212_minigame_charades).
        path: RoutePaths.charades(':sessionId'),
        builder: (context, state) => _screenForId(
          state,
          'sessionId',
          (sessionId) => FlagGate(
            flag: AppFeatureFlag.minigames,
            child: CharadesScreen(sessionId: sessionId),
          ),
          errorMessage: AppLocalizations.of(context).routerGroupNotFound,
        ),
      ),
      GoRoute(
        // One Rankings surface: Users | Groups inside.
        path: RoutePaths.rankings,
        builder: (_, _) => const RankingsScreen(),
      ),
      GoRoute(
        // chat is LIVE but the flag stays wired as the
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
        // Chat inbox: the feed's chat button lands here.
        path: RoutePaths.chatList,
        builder: (context, state) =>
            const FlagGate(flag: AppFeatureFlag.chat, child: ChatListScreen()),
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
      GoRoute(
        path: RoutePaths.appeals,
        builder: (_, state) =>
            AppealsScreen(banAppeal: state.uri.queryParameters['ban'] == '1'),
      ),
      GoRoute(
        // QRAT/QRSC, Stage-5 rotating-QR attendee surface: gated on the
        // qr flag as the kill-switch knob. The attendee screen shows a plain
        // QR encoding the rotating 24-hex attendance code
        // (AttendanceCodeScreen); the scanner (QrScannerScreen) reads that QR
        // and validates the code via validate_code.
        path: RoutePaths.qr(':eventId'),
        builder: (context, state) => _screenForId(
          state,
          'eventId',
          (eventId) => FlagGate(
            flag: AppFeatureFlag.qr,
            child: AttendanceCodeScreen(eventId: eventId),
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
        // Gated on the subscriptions flag (dark-first — a build without a
        // RevenueCat key renders NOTHING here, not a placeholder).
        path: RoutePaths.subscriptions,
        builder: (context, _) => const FlagGate(
          flag: AppFeatureFlag.subscriptions,
          fallback: SizedBox.shrink(),
          child: PaywallScreen(),
        ),
      ),
      GoRoute(
        // Gated on the cosmeticsSection flag as the kill-switch
        // knob.
        path: RoutePaths.cosmetics,
        builder: (context, _) => const FlagGate(
          flag: AppFeatureFlag.cosmeticsSection,
          child: CosmeticsShopScreen(),
        ),
      ),
      GoRoute(
        // SLED: the shard/preshard ledger history. NOT flag-gated —
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
        path: RoutePaths.exportData,
        builder: (_, _) => const ExportDataScreen(),
      ),
      GoRoute(
        path: RoutePaths.profileEdit,
        builder: (_, _) => const EditProfileScreen(),
      ),
    ],
  );
});
