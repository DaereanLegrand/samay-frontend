import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

/// Terminal screen for suspended accounts (AUTH spec: ban enforcement, I-35).
///
/// Minimalist per DESIGN.md §1 (black always, white core, one
/// idea per screen): an icon, the suspension title, the stored ban reason
/// (when the administrator provided one) and a single logout action. Every
/// route redirects here while [AuthState.banned] is set ([AuthGuard]); after
/// sign-out the guard routes to login normally.
class BannedScreen extends ConsumerWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reason = ref.watch(authStateProvider).valueOrNull?.banReason;
    final family = AppGradients.familyOf('banned');

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.block,
                        size: AppIconSizes.xxl,
                        color: AppColors.white,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // LUXE §6.2: the suspension title is the display
                      // voice — mint-family VDisplayText (gradient fill +
                      // slowly pulsing glow).
                      VDisplayText(
                        text: l10n.bannedTitle,
                        gradient: family,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        reason != null && reason.isNotEmpty
                            ? l10n.bannedReasonLabel(reason)
                            : l10n.bannedDefaultBody,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.mutedStrong),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      // U-19: the sign-out CTA is full-width (max 320) — the
                      // fixed 200px width clipped long labels at 1.5× scale.
                      // LUXE v2: the action rides a liquid-glass card
                      // (mint-family ring + soft glow).
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: VCard(
                          child: VButton.outlined(
                            label: l10n.profileSignOut,
                            onPressed: () => ref
                                .read(authStateProvider.notifier)
                                .signOut(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
