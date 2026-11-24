import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';

/// The routing decision, as a pure function of (auth state, location).
///
/// Split out from [AuthGuard] so it can be tested without a GoRouter,
/// Supabase or a BuildContext — the consent gate is the one piece of routing
/// that must never regress, because letting it slip means a visitor can play
/// before confirming 18+/terms.
///
/// The funnel is tiny on purpose:
///
///   still loading         → /onboarding  (never the deck; nothing interactive)
///   banned                → /banned (+ appeals only)
///   no session            → /onboarding  (one tap creates the guest)
///   session, no profile   → /onboarding  (acceptance not recorded yet)
///   session + profile     → /            (the games deck)
///
/// Apple/Google sign-in is never required, so there is no "must authenticate"
/// redirect: the guest session IS the authenticated state.
String? consentRedirect({
  required AsyncValue<AuthState> auth,
  required String location,
}) {
  // Still resolving the initial session. Returning null here paints the
  // REQUESTED route, which on a cold start is the games deck — that is exactly
  // how the app used to be browsable before the gate appeared. Hold at
  // onboarding instead: it is the only route that is always safe, and the boot
  // cover in `app.dart` hides the screen until state resolves.
  if (auth.isLoading) {
    return location == RoutePaths.onboarding ? null : RoutePaths.onboarding;
  }

  final data = auth.valueOrNull;

  // A banned account is confined to the ban screen (store compliance: the user
  // must be able to read the reason and file an appeal).
  if (data != null && data.banned) {
    final allowedWhileBanned =
        location == RoutePaths.banned || location == RoutePaths.appeals;
    return allowedWhileBanned ? null : RoutePaths.banned;
  }

  final onboarded = data != null && data.authenticated && data.hasProfile;

  if (!onboarded) {
    // Before the guest profile exists only the consent surfaces are reachable:
    // onboarding, and the declined dead-end its X leads to. A deep link to any
    // game lands on onboarding first.
    final allowedBeforeConsent = location == RoutePaths.onboarding ||
        location == RoutePaths.onboardingDeclined;
    return allowedBeforeConsent ? null : RoutePaths.onboarding;
  }

  // Onboarded: the consent screens have nothing left to do.
  if (location == RoutePaths.onboarding ||
      location == RoutePaths.onboardingDeclined) {
    return RoutePaths.gamesHome;
  }

  return null;
}

/// Routing gate. Thin adapter: reads the auth provider and delegates the
/// decision to [consentRedirect].
class AuthGuard {
  final Ref ref;

  AuthGuard(this.ref);

  FutureOr<String?> call(BuildContext context, GoRouterState state) {
    return consentRedirect(
      auth: ref.read(authStateProvider),
      location: state.matchedLocation,
    );
  }
}
