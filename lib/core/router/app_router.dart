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
          GoRoute(path: '/main/feed', builder: (_, _) => const Scaffold()),
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
      GoRoute(path: '/group/:groupId', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/group/:groupId/members', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/group/:groupId/create-event', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/chat/:chatId', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/user/:userId',
        builder: (_, state) => PublicProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(path: '/user/:userId/friend', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/user/search', builder: (_, _) => const Scaffold()),
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
