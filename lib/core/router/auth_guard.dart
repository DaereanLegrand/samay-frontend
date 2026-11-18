import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';

/// Routing gate for the slim, guest-first app.
///
/// The funnel is tiny on purpose:
///
///   no session            → /onboarding   (one checkbox creates the guest)
///   session, no profile   → /onboarding   (acceptance not recorded yet)
///   banned                → /banned (+ appeals only)
///   session + profile     → /             (the games deck)
///
/// Apple/Google sign-in is never required, so there is no "must authenticate"
/// redirect: the guest session IS the authenticated state.
class AuthGuard {
  final Ref ref;

  AuthGuard(this.ref);

  FutureOr<String?> call(BuildContext context, GoRouterState state) {
    final auth = ref.read(authStateProvider);
    final location = state.matchedLocation;

    // Still resolving the initial session: paint nothing (the splash holds).
    if (auth.isLoading) return null;

    final data = auth.valueOrNull;

    // A banned account is confined to the ban screen (store compliance: the
    // user must be able to read the reason and file an appeal).
    if (data != null && data.banned) {
      final allowedWhileBanned =
          location == RoutePaths.banned || location == RoutePaths.appeals;
      return allowedWhileBanned ? null : RoutePaths.banned;
    }

    final onboarded = data != null && data.authenticated && data.hasProfile;

    if (!onboarded) {
      // Only the onboarding screen is reachable before the guest profile
      // exists. A deep link to any game lands on onboarding first.
      return location == RoutePaths.onboarding ? null : RoutePaths.onboarding;
    }

    // Onboarded: the onboarding screen has nothing left to do.
    if (location == RoutePaths.onboarding) return RoutePaths.gamesHome;

    return null;
  }
}
