import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';

class AuthGuard {
  final Ref ref;

  AuthGuard(this.ref);

  FutureOr<String?> call(BuildContext context, GoRouterState state) {
    final auth = ref.read(authStateProvider);
    final location = state.matchedLocation;

    if (auth.isLoading) return null;

    final data = auth.valueOrNull;

    // Banned users are confined to the ban screen — no route (public or
    // authenticated) may render for them (AUTH spec: ban enforcement, I-35).
    if (data != null && data.banned) {
      return location == RoutePaths.banned ? null : RoutePaths.banned;
    }

    final isPublicRoute = location == RoutePaths.welcome ||
        location == RoutePaths.login ||
        location == RoutePaths.forgotPassword ||
        location.startsWith(RoutePaths.authPrefix);

    if (data == null || !data.authenticated) {
      return isPublicRoute ? null : RoutePaths.login;
    }

    if (!data.hasProfile && !location.startsWith(RoutePaths.authPrefix)) {
      return RoutePaths.signup;
    }

    if (location == RoutePaths.login || location == RoutePaths.welcome) {
      return RoutePaths.mainFeed;
    }

    return null;
  }
}
