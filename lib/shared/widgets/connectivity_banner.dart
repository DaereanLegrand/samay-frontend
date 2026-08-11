import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/providers/connectivity_provider.dart';
import 'package:samay/l10n/app_localizations.dart';

/// Global offline indicator (I-67): a slim black banner with the red
/// `wifi_off` icon and the localized copy, mounted by [SamayApp] inside
/// `MaterialApp.router`'s builder — below Localizations/Theme/MediaQuery but
/// above the Navigator, so it overlays every route (auth flow included, where
/// network failures are most confusing).
///
/// Optimistic by design: while the connectivity status is still loading — or
/// the stream is unavailable/errors (e.g. platform plugin absent in tests) —
/// `valueOrNull ?? true` keeps the banner hidden, so a transient ambiguity
/// never flashes a false "offline" state.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectivityProvider).valueOrNull ?? true;
    if (connected) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      color: AppColors.discoBlack,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // §5.2: never raw red on black — the offline/error signal uses the
          // semantic `AppColors.error` (glowPink, 6.00:1 — AA).
          const Icon(Icons.wifi_off, size: 14, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              l10n.connectivityOfflineBanner,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
