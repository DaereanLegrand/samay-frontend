import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/router/auth_guard.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authGuard = AuthGuard(ref);
  return GoRouter(
    initialLocation: '/login',
    redirect: authGuard.call,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/login', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/auth/verify', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/auth/onboarding', builder: (_, _) => const Scaffold()),
      ShellRoute(
        builder: (_, _, child) => Scaffold(body: child),
        routes: [
          GoRoute(path: '/main/feed', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/main/groups', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/main/events', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/main/notifications', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/main/profile', builder: (_, _) => const Scaffold()),
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
      GoRoute(path: '/user/:userId', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/user/:userId/friend', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/user/search', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/qr/:eventId', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/scanner/:eventId', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/subscriptions', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/party-finder', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/settings', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/settings/delete-account', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/profile/edit', builder: (_, _) => const Scaffold()),
    ],
  );
});
