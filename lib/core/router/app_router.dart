import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/router/auth_guard.dart';
import 'package:vive_app/features/auth/login_screen.dart';
import 'package:vive_app/features/auth/welcome_screen.dart';
import 'package:vive_app/features/auth/signup_contact_screen.dart';
import 'package:vive_app/features/auth/otp_verification_screen.dart';
import 'package:vive_app/features/auth/age_gate_screen.dart';
import 'package:vive_app/features/auth/privacy_terms_screen.dart';
import 'package:vive_app/features/auth/profile_setup_screen.dart';
import 'package:vive_app/features/profile/profile_screen.dart';
import 'package:vive_app/features/profile/edit_profile_screen.dart';
import 'package:vive_app/features/profile/settings_screen.dart';
import 'package:vive_app/features/profile/public_profile_screen.dart';
import 'package:vive_app/features/profile/delete_account_screen.dart';
import 'package:vive_app/features/feed/feed_screen.dart';
import 'package:vive_app/features/friends/search_screen.dart';
import 'package:vive_app/features/friends/requests_screen.dart';
import 'package:vive_app/features/friends/friends_list_screen.dart';
import 'package:vive_app/features/friends/blocked_users_screen.dart';
import 'package:vive_app/features/groups/create_group_screen.dart';
import 'package:vive_app/features/groups/group_detail_screen.dart';
import 'package:vive_app/features/groups/donate_shards_screen.dart';
import 'package:vive_app/features/groups/leaderboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authGuard = AuthGuard(ref);
  return GoRouter(
    initialLocation: '/login',
    redirect: authGuard.call,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (_, _) => const SignupContactScreen(),
      ),
      GoRoute(
        path: '/auth/verify',
        builder: (_, state) => OtpVerificationScreen(email: state.extra as String),
      ),
      GoRoute(
        path: '/auth/age-gate',
        builder: (_, state) => AgeGateScreen(email: state.extra as String),
      ),
      GoRoute(
        path: '/auth/privacy-terms',
        builder: (_, state) => PrivacyTermsScreen(email: state.extra as String),
      ),
      GoRoute(
        path: '/auth/profile-setup',
        builder: (_, state) => ProfileSetupScreen(email: state.extra as String),
      ),
      ShellRoute(
        builder: (_, _, child) => Scaffold(body: child),
        routes: [
          GoRoute(path: '/main/feed', builder: (_, _) => const FeedScreen()),
          GoRoute(path: '/main/groups', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/main/events', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/main/notifications', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/main/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/event/:eventId', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/event/:eventId/edit', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/event/:eventId/invite', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/event/:eventId/photos', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/event/:eventId/collage', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/event/:inviteToken', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/group/:groupId',
        builder: (_, state) => GroupDetailScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: '/group/:groupId/members',
        builder: (_, state) => const Scaffold(),
      ),
      GoRoute(
        path: '/group/:groupId/donate',
        builder: (_, state) => DonateShardsScreen(
          groupId: state.pathParameters['groupId']!,
          groupName: state.extra as String? ?? 'Grupo',
        ),
      ),
      GoRoute(
        path: '/group/:groupId/create-event',
        builder: (_, state) => const Scaffold(),
      ),
      GoRoute(
        path: '/group/create',
        builder: (_, _) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/groups/leaderboard',
        builder: (_, _) => const LeaderboardScreen(),
      ),
      GoRoute(path: '/chat/:chatId', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/user/:userId',
        builder: (_, state) => PublicProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(path: '/user/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/friends/requests', builder: (_, _) => const RequestsScreen()),
      GoRoute(path: '/friends/list', builder: (_, _) => const FriendsListScreen()),
      GoRoute(path: '/settings/blocked', builder: (_, _) => const BlockedUsersScreen()),
      GoRoute(path: '/qr/:eventId', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/scanner/:eventId', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/subscriptions', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/party-finder', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/settings/delete-account', builder: (_, _) => const DeleteAccountScreen()),
      GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
    ],
  );
});
