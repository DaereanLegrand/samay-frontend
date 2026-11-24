import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/deep_links/deep_link_handler.dart';
import 'package:samay/core/providers/theme_provider.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/theme/app_palette.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/core/theme/app_theme.dart';
import 'package:samay/core/theme/app_theme_provider.dart';
import 'package:samay/core/theme/app_theme_scope.dart';
import 'package:samay/core/theme/themed_data.dart';
import 'package:samay/core/router/app_router.dart';
import 'package:samay/features/auth/providers/auth_scope_reset.dart';
import 'package:samay/features/friends/providers/friends_cache_provider.dart';
import 'package:samay/features/notifications/providers/push_notification_listener.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/connectivity_banner.dart';
import 'package:samay/shared/widgets/crash_recovery_banner.dart';

class SamayApp extends ConsumerWidget {
  /// True when a crash marker existed at launch and was recovered —
  /// [main.dart] feeds the `recoverCrashMarker` result through here so the
  /// user-facing recovery banner shows exactly once after a real crash.
  final bool recoveredFromCrash;

  const SamayApp({super.key, this.recoveredFromCrash = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // the persisted theme-mode choice (default dark)
    // drives MaterialApp's mode. Both `theme` and `darkTheme` are the disco
    // theme — dark is the brand (design doc §1 P1) — so 'system' is a
    // future-proof seam, not a light mode.
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;
    // The app-wide theme (Settings → Apariencia, paywalled). `classic` is the
    // design tokens verbatim, so an app with no choice paints byte-identically
    // to before; any other preset re-maps Material defaults onto its scale.
    final palette = ref.watch(appPaletteProvider);
    final theme = palette == AppPalette.standard
        ? SamayTheme.dark
        : themedData(SamayTheme.dark, palette);
    return MaterialApp.router(
      title: 'Samay',
      theme: theme,
      darkTheme: theme,
      themeMode: themeMode,
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // the connectivity banner mounts below Localizations/Theme/
      // MediaQuery (so its copy resolves and it can measure) but above the
      // Navigator — a global, route-independent offline indicator. Optimistic:
      // hidden while the status is loading/unknown (valueOrNull ?? true).
      // EINV: the deep-link listener mounts below Localizations (so
      // its snackbar copy resolves) but above the Navigator. Inert when
      // deepLinkStreamProvider is null (default — tests).
      // ANIM-ON: the forced `disableAnimations: true` override
      // is REMOVED — animations run and honor the
      // OS-level reduced-motion preference via `MediaQuery.disableAnimationsOf`
      // per widget.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // BOOT GATE: the initial session probe is network I/O (ban check +
        // profile lookup), so the router used to evaluate against
        // `AsyncLoading` and paint the requested route — the games deck — for
        // a second or two before the consent gate appeared. Nothing may be
        // interactive before consent, so hold a blank brand surface until the
        // auth state resolves. The router then redirects deterministically.
        final authResolved = ref.watch(authStateProvider).hasValue;
        // The ambient palette for EVERY route. A group screen mounts its own
        // [GroupThemeSurface] inside and overrides this when the group has a
        // real (non-default) theme.
        return AppThemeScope(
          palette: palette,
          child: Stack(
            children: [
              // Main content fills the screen — no margin push from banners.
              Positioned.fill(
                child: authResolved
                    ? Stack(children: [?child, const DeepLinkListener()])
                    : const _BootCover(),
              ),
              // LOGOUT FLUSH: mounted above the Navigator so
              // the auth screens are covered too — on logout every
              // user-scoped provider is invalidated (no stale data survives
              // an account switch in the same session).
              const AuthScopeReset(),
              // PUSH: mounted once at the root (it used to live in the deleted
              // nav shell). It is inert until the player is onboarded, then it
              // activates FCM, asks for the permission and syncs the token.
              const PushNotificationListener(),
              // FRIENDS CACHE: fetches the friend list in the
              // background on auth and persists it to the device DB so the
              // invite/buscar pickers render friends for empty + <5-char
              // queries with zero network I/O.
              const FriendsCacheWarmer(),
              // the connectivity banner overlays the top of the screen.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ConnectivityBanner(),
              ),
              // The recovery banner sits above the bottom nav bar,
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

/// Brand-blank surface painted until the initial auth probe resolves.
///
/// Exists so no route — and therefore no game — is interactive before the
/// consent gate has been evaluated. Deliberately silent: the wordmark and the
/// gate appear together once [authStateProvider] has a value, so there is no
/// flash of the deck, and no spinner that implies play is imminent.
class _BootCover extends StatelessWidget {
  const _BootCover();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.background,
      child: const SizedBox.expand(),
    );
  }
}
