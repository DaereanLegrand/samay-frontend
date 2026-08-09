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

    final isPublicRoute = location == RoutePaths.welcome ||
        location == RoutePaths.login ||
        location.startsWith(RoutePaths.authPrefix);

    if (auth.loading) return null;

    if (!auth.authenticated) {
      return isPublicRoute ? null : RoutePaths.login;
    }

    if (!auth.hasProfile && !location.startsWith(RoutePaths.authPrefix)) {
      return RoutePaths.signup;
    }

    if (location == RoutePaths.login || location == RoutePaths.welcome) {
      return RoutePaths.mainFeed;
    }

    return null;
  }
}
