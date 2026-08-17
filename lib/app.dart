import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/deep_links/deep_link_handler.dart';
import 'package:samay/core/providers/theme_provider.dart';
import 'package:samay/core/theme/app_theme.dart';
import 'package:samay/core/router/app_router.dart';
import 'package:samay/features/auth/providers/auth_scope_reset.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/connectivity_banner.dart';
import 'package:samay/shared/widgets/crash_recovery_banner.dart';

class SamayApp extends ConsumerWidget {
  /// LOG-03: true when a crash marker existed at launch and was recovered —
  /// [main.dart] feeds the `recoverCrashMarker` result through here so the
  /// user-facing recovery banner shows exactly once after a real crash.
  final bool recoveredFromCrash;

  const SamayApp({super.key, this.recoveredFromCrash = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // UI-05 / L-16 (I-65): the persisted theme-mode choice (default dark)
    // drives MaterialApp's mode. Both `theme` and `darkTheme` are the disco
    // theme — dark is the brand (design doc §1 P1) — so 'system' is a
    // future-proof seam, not a light mode.
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;
    return MaterialApp.router(
      title: 'Samay',
      theme: SamayTheme.dark,
      darkTheme: SamayTheme.dark,
      themeMode: themeMode,
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // I-67: the connectivity banner mounts below Localizations/Theme/
      // MediaQuery (so its copy resolves and it can measure) but above the
      // Navigator — a global, route-independent offline indicator. Optimistic:
      // hidden while the status is loading/unknown (valueOrNull ?? true).
      // EINV (I-66): the deep-link listener mounts below Localizations (so
      // its snackbar copy resolves) but above the Navigator. Inert when
      // deepLinkStreamProvider is null (default — tests).
      // ANIM-OFF (2026-08-14): ALL animations are deactivated app-wide —
      // the MediaQuery override below propagates `disableAnimations: true`
      // to every route/screen, which every motion widget honors
      // (`MediaQuery.disableAnimationsOf` → static; zero-duration implicit
      // animations; static spinners; static page transitions).
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: true),
          child: Stack(
            children: [
              // Main content fills the screen — no margin push from banners.
              Positioned.fill(
                child: Stack(children: [?child, const DeepLinkListener()]),
              ),
              // LOGOUT FLUSH (2026-08-14): mounted above the Navigator so
              // the auth screens are covered too — on logout every
              // user-scoped provider is invalidated (no stale data survives
              // an account switch in the same session).
              const AuthScopeReset(),
              // I-67: the connectivity banner overlays the top of the screen.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ConnectivityBanner(),
              ),
              // LOG-03: the recovery banner sits above the bottom nav bar,
              // fully reachable regardless of the OS status bar or Dynamic
              // Island. Positioned with safe-area inset so it never hides
              // behind the gesture bar on iOS/home-indicator devices.
              if (recoveredFromCrash)
                Positioned(
                  bottom:
                      kBottomNavigationBarHeight + mediaQuery.padding.bottom,
                  left: 0,
                  right: 0,
                  child: const CrashRecoveryBanner(visible: true),
                ),
            ],
          ),
        );
      },
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
