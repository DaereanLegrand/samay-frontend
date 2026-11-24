import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/auth_guard.dart';
import 'package:samay/core/router/route_paths.dart';

/// Regression tests for the consent gate.
///
/// The bug these pin: the app used to be browsable on a cold start. The
/// router's `initialLocation` is the games deck and the initial auth probe is
/// network I/O, so the guard evaluated while the state was still
/// `AsyncLoading`; that branch returned null, which let the deck paint. A
/// visitor could play several games before the consent screen appeared — which
/// breaks the 18+ / terms confirmation both stores require.
///
/// Contract pinned:
///   loading       → never the deck; hold on onboarding
///   un-onboarded  → onboarding, or the declined dead-end (nothing else)
///   onboarded     → deck; the consent screens bounce to the deck
void main() {
  const loading = AsyncLoading<AuthState>();
  const anonymous = AsyncData(AuthState());
  const guestNoProfile =
      AsyncData(AuthState(authenticated: true, hasProfile: false));
  const onboarded =
      AsyncData(AuthState(authenticated: true, hasProfile: true));
  const banned =
      AsyncData(AuthState(authenticated: true, hasProfile: true, banned: true));

  String? go(AsyncValue<AuthState> auth, String location) =>
      consentRedirect(auth: auth, location: location);

  group('loading — nothing may be interactive', () {
    test('a cold start on the deck is held at onboarding', () {
      expect(go(loading, RoutePaths.gamesHome), RoutePaths.onboarding);
    });

    test('onboarding itself is allowed while loading', () {
      expect(go(loading, RoutePaths.onboarding), isNull);
    });

    test('a deep link into a game is held at onboarding', () {
      expect(
        go(loading, RoutePaths.minigame('truth_dare')),
        RoutePaths.onboarding,
      );
    });

    test('the declined dead-end is not reachable while loading', () {
      expect(
        go(loading, RoutePaths.onboardingDeclined),
        RoutePaths.onboarding,
      );
    });
  });

  group('un-onboarded — consent is mandatory', () {
    test('the deck redirects to onboarding', () {
      expect(go(anonymous, RoutePaths.gamesHome), RoutePaths.onboarding);
    });

    test('the declined dead-end is reachable', () {
      expect(go(anonymous, RoutePaths.onboardingDeclined), isNull);
    });

    test('a deep link into a game lands on onboarding', () {
      expect(
        go(anonymous, RoutePaths.localLobby('truth_dare')),
        RoutePaths.onboarding,
      );
    });

    test('an authenticated user without a profile is un-onboarded', () {
      expect(
        go(guestNoProfile, RoutePaths.gamesHome),
        RoutePaths.onboarding,
      );
    });
  });

  group('onboarded', () {
    test('the deck is reachable', () {
      expect(go(onboarded, RoutePaths.gamesHome), isNull);
    });

    test('onboarding bounces to the deck', () {
      expect(go(onboarded, RoutePaths.onboarding), RoutePaths.gamesHome);
    });

    test('the declined screen bounces to the deck', () {
      expect(
        go(onboarded, RoutePaths.onboardingDeclined),
        RoutePaths.gamesHome,
      );
    });
  });

  group('banned — confined to the compliance surfaces', () {
    test('the deck redirects to /banned', () {
      expect(go(banned, RoutePaths.gamesHome), RoutePaths.banned);
    });

    test('/banned and /appeals stay reachable', () {
      expect(go(banned, RoutePaths.banned), isNull);
      expect(go(banned, RoutePaths.appeals), isNull);
    });
  });
}
