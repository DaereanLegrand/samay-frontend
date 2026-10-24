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
    // authenticated) may render for them.
    if (data != null && data.banned) {
      // The ban screen and the appeal form are the only routes available to a
      // suspended account (Q6: ban appeals must ship).
      final allowedWhileBanned =
          location == RoutePaths.banned || location == RoutePaths.appeals;
      return allowedWhileBanned ? null : RoutePaths.banned;
    }

    // Password recovery confines the session to the reset screen until the
    // new password is set.
    if (data != null && data.passwordRecovery) {
      return location == RoutePaths.resetPassword
          ? null
          : RoutePaths.resetPassword;
    }

    final isPreAuthRoute =
        location == RoutePaths.welcome ||
        location == RoutePaths.login ||
        location == RoutePaths.forgotPassword ||
        location == RoutePaths.resetPassword;

    if (data == null || !data.authenticated) {
      // Unauthenticated: only the pre-auth screens, the signup ENTRY (contact)
      // and the OTP step (which the user reaches from the contact screen
      // BEFORE the code is verified) are visible. Every funnel step AFTER
      // verification — age gate / privacy terms / profile setup — requires an
      // authenticated in-progress signup, so a deep link or stale route can
      // never drop an unauthenticated user onto the birthdate screen.
      final inExplicitSignup =
          isPreAuthRoute ||
          location == RoutePaths.signup ||
          location == RoutePaths.verify;
      return inExplicitSignup ? null : RoutePaths.login;
    }

    final isFunnelStep =
        location == RoutePaths.verify ||
        location == RoutePaths.ageGate ||
        location == RoutePaths.privacyTerms ||
        location == RoutePaths.profileSetup;

    // Funnel-scoped gate: the signup funnel (verify / age gate /
    // privacy terms / profile setup) is STRICTLY part of the signup process.
    // It is reachable only while authenticated AND without a completed profile
    // — i.e. exactly the signup-in-progress state that walks OTP → age gate →
    // terms → profile setup. An authenticated user who already has a profile
    // (hasProfile: true) must NEVER see these screens and is redirected to the
    // feed; a restored profile-less session is signed out at startup
    // (AuthNotifier._resolveInitialState) before it ever reaches the router.
    // There is no implicit bounce into the funnel — ever.
    if (isFunnelStep) {
      return data.hasProfile ? RoutePaths.mainFeed : null;
    }

    if (location == RoutePaths.login || location == RoutePaths.welcome) {
      // Authenticated with a completed profile → feed. A profile-less session
      // is left on the pre-auth route: the explicit social sign-in flow owns
      // navigating it into the onboarding funnel (age gate → terms → profile
      // setup) so the typed email extra is preserved. Restored orphans never
      // reach here — they are signed out on restore.
      if (!data.hasProfile) return null;
      return RoutePaths.mainFeed;
    }

    return null;
  }
}

// NOTE: the guard must never navigate a
// user to an UNRELATED screen they did not explicitly request. The only
// implicit redirects are: banned → ban screen, unauthenticated → login,
// authenticated → feed. The signup funnel (verify / age gate / privacy terms /
// profile setup) is never entered implicitly: it is reachable only while
// authenticated-without-profile, and a fully-registered user is redirected
// away from it to the feed. Any error in the profile check surfaces as an
// error (with code) at the explicit action that triggered it; a failed check
// never bounces the user around.
