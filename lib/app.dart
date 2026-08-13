import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/deep_links/deep_link_handler.dart';
import 'package:samay/core/providers/theme_provider.dart';
import 'package:samay/core/theme/app_theme.dart';
import 'package:samay/core/router/app_router.dart';
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
      builder: (context, child) => Column(
        children: [
          // LOG-03: the recovery banner sits above the offline indicator —
          // it only appears once (right after a real crash) and collapses on
          // dismissal.
          CrashRecoveryBanner(visible: recoveredFromCrash),
          const ConnectivityBanner(),
          Expanded(child: Stack(children: [?child, const DeepLinkListener()])),
        ],
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
