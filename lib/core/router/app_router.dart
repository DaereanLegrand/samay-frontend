import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/router/auth_guard.dart';
import 'package:samay/core/router/route_paths.dart';
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
import 'package:samay/features/feed/feed_screen.dart';
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
import 'package:samay/shared/widgets/v_coming_soon.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authGuard = AuthGuard(ref);
  return GoRouter(
    initialLocation: RoutePaths.login,
    redirect: authGuard.call,
    routes: [
      GoRoute(path: RoutePaths.welcome, builder: (_, _) => const WelcomeScreen()),
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
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OtpVerificationScreen(
            email: extra['email'] as String,
            password: extra['password'] as String,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.ageGate,
        builder: (_, state) => AgeGateScreen(email: state.extra as String?),
      ),
      GoRoute(
        path: RoutePaths.privacyTerms,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PrivacyTermsScreen(
            email: extra['email'] as String,
            dateOfBirth: extra['dateOfBirth'] as String,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.profileSetup,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ProfileSetupScreen(
            email: extra['email'] as String,
            dateOfBirth: extra['dateOfBirth'] as String,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          final tab = state.matchedLocation;
          int currentIndex = 0;
          if (tab.startsWith('/main/groups')) currentIndex = 1;
          if (tab.startsWith('/main/events')) currentIndex = 2;
          if (tab.startsWith('/main/notifications')) currentIndex = 3;
          if (tab.startsWith('/main/profile')) currentIndex = 4;
          return Scaffold(
            body: child,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (i) {
                switch (i) {
                  case 0: context.go(RoutePaths.mainFeed);
                  case 1: context.go(RoutePaths.mainGroups);
                  case 2: context.go(RoutePaths.mainEvents);
                  case 3: context.go(RoutePaths.mainNotifications);
                  case 4: context.go(RoutePaths.mainProfile);
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Feed'),
                BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'Grupos'),
                BottomNavigationBarItem(icon: Icon(Icons.event_outlined), label: 'Eventos'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Notis'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
              ],
            ),
          );
        },
        routes: [
          GoRoute(path: RoutePaths.mainFeed, builder: (_, _) => const FeedScreen()),
          GoRoute(path: RoutePaths.mainGroups, builder: (_, _) => const MyGroupsScreen()),
          GoRoute(path: RoutePaths.mainEvents, builder: (_, _) => const VComingSoonScreen(title: 'Eventos', description: 'Los eventos de tus grupos aparecer\u00e1n aqu\u00ed pronto.')),
          GoRoute(path: RoutePaths.mainNotifications, builder: (_, _) => const VComingSoonScreen(title: 'Notificaciones', description: 'Tus notificaciones aparecer\u00e1n aqu\u00ed pronto.')),
          GoRoute(path: RoutePaths.mainProfile, builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: RoutePaths.eventDetail(':eventId'), builder: (_, _) => const VComingSoonScreen(title: 'Evento', description: 'El detalle del evento estar\u00e1 disponible pronto.')),
      GoRoute(path: RoutePaths.eventEdit(':eventId'), builder: (_, _) => const VComingSoonScreen(title: 'Editar evento', description: 'La edici\u00f3n de eventos estar\u00e1 disponible pronto.')),
      GoRoute(path: RoutePaths.eventInvite(':eventId'), builder: (_, _) => const VComingSoonScreen(title: 'Invitar', description: 'La invitaci\u00f3n a eventos estar\u00e1 disponible pronto.')),
      GoRoute(path: RoutePaths.eventPhotos(':eventId'), builder: (_, _) => const VComingSoonScreen(title: 'Fotos', description: 'Las fotos del evento estar\u00e1n disponibles pronto.')),
      GoRoute(path: RoutePaths.eventCollage(':eventId'), builder: (_, _) => const VComingSoonScreen(title: 'Collage', description: 'El collage de fotos estar\u00e1 disponible pronto.')),
      GoRoute(path: RoutePaths.eventInviteToken(':inviteToken'), builder: (_, _) => const VComingSoonScreen(title: 'Invitaci\u00f3n', description: 'Las invitaciones a eventos aparecer\u00e1n aqu\u00ed pronto.')),
      GoRoute(
        path: RoutePaths.groupCreate,
        builder: (_, _) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: RoutePaths.groupDetail(':groupId'),
        builder: (_, state) => GroupDetailScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: RoutePaths.groupMembers(':groupId'),
        builder: (_, state) => GroupMembersScreen(
          groupId: state.pathParameters['groupId']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.donateToGroup(':groupId'),
        builder: (_, state) => DonateShardsScreen(
          groupId: state.pathParameters['groupId']!,
          groupName: state.extra as String? ?? 'Grupo',
        ),
      ),
      GoRoute(
        path: RoutePaths.createGroupEvent(':groupId'),
        builder: (_, _) => const VComingSoonScreen(title: 'Crear evento', description: 'La creaci\u00f3n de eventos estar\u00e1 disponible pronto.'),
      ),
      GoRoute(
        path: RoutePaths.inviteToGroup(':groupId'),
        builder: (_, state) => InviteScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: RoutePaths.groupsLeaderboard,
        builder: (_, _) => const LeaderboardScreen(),
      ),
      GoRoute(path: RoutePaths.chat(':chatId'), builder: (_, _) => const VComingSoonScreen(title: 'Chat', description: 'El chat estar\u00e1 disponible pronto.')),
      GoRoute(path: RoutePaths.userSearch, builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: RoutePaths.userProfile(':userId'),
        builder: (_, state) => PublicProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(path: RoutePaths.friendsRequests, builder: (_, _) => const RequestsScreen()),
      GoRoute(path: RoutePaths.friendsList, builder: (_, _) => const FriendsListScreen()),
      GoRoute(path: RoutePaths.blockedUsers, builder: (_, _) => const BlockedUsersScreen()),
      GoRoute(path: RoutePaths.qr(':eventId'), builder: (_, _) => const VComingSoonScreen(title: 'QR', description: 'El c\u00f3digo QR del evento estar\u00e1 disponible pronto.')),
      GoRoute(path: RoutePaths.scanner(':eventId'), builder: (_, _) => const VComingSoonScreen(title: 'Esc\u00e1ner', description: 'El esc\u00e1ner de c\u00f3digos QR estar\u00e1 disponible pronto.')),
      GoRoute(path: RoutePaths.subscriptions, builder: (_, _) => const VComingSoonScreen(title: 'Suscripciones', description: 'Las suscripciones estar\u00e1n disponibles pronto.')),
      GoRoute(path: RoutePaths.partyFinder, builder: (_, _) => const VComingSoonScreen(title: 'Party Finder', description: 'El Party Finder estar\u00e1 disponible pronto.')),
      GoRoute(path: RoutePaths.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: RoutePaths.deleteAccount, builder: (_, _) => const DeleteAccountScreen()),
      GoRoute(path: RoutePaths.profileEdit, builder: (_, _) => const EditProfileScreen()),
    ],
  );
});
