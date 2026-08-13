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

    final isPublicRoute =
        location == RoutePaths.welcome ||
        location == RoutePaths.login ||
        location == RoutePaths.forgotPassword ||
        location.startsWith(RoutePaths.authPrefix);

    if (data == null || !data.authenticated) {
      return isPublicRoute ? null : RoutePaths.login;
    }

    // Funnel-completion gate (2026-08-13): an authenticated user without a
    // `users` row must NOT enter the app — age verification, terms and
    // username selection are mandatory, not skippable (a mid-funnel app
    // restart previously dropped these users straight onto the feed).
    // The age gate is the ONLY legitimate next step: it resolves the email
    // from the session and re-establishes the explicit chain age gate →
    // privacy/terms → profile setup. This is not a hidden navigation — it is
    // the funnel itself; every screen in it is under `authPrefix`, so the
    // redirect fires only when the user is NOT already in the funnel.
    if (!data.hasProfile && !location.startsWith(RoutePaths.authPrefix)) {
      return RoutePaths.ageGate;
    }

    if (location == RoutePaths.login || location == RoutePaths.welcome) {
      return RoutePaths.mainFeed;
    }

    return null;
  }
}

// NOTE (no-fallback policy, 2026-08-13): the guard must never navigate a
// user to an UNRELATED screen they did not explicitly request. The only
// implicit redirects are: banned → ban screen, unauthenticated → login,
// authenticated → feed, and (funnel-completion) authenticated-without-profile
// → the age gate — the start of the explicit signup-completion funnel. Any
// error in the profile check surfaces as an error (with code) at the explicit
// action that triggered it; a failed check never bounces the user around.
