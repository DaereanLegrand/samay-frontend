import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Terminal screen for suspended accounts (ban enforcement).
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
                      Icon(
                        Icons.block,
                        size: AppIconSizes.xxl,
                        color: context.palette.foreground,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // Monochrome: the suspension title is the
                      // display voice — verbatim copy, flat white glyphs.
                      VDisplayText(
                        text: l10n.bannedTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        reason != null && reason.isNotEmpty
                            ? l10n.bannedReasonLabel(reason)
                            : l10n.bannedDefaultBody,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.palette.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      // The sign-out CTA is full-width (max 320) — the
                      // fixed 200px width clipped long labels at 1.5× scale.
                      // LUXE v2: the action rides a liquid-glass card
                      // (mint-family ring + soft glow).
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          children: [
                            VButton.outlined(
                              label: l10n.bannedAppealCta,
                              onPressed: () => context.push(
                                RoutePaths.appeal(banAppeal: true),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            VCard(
                              child: VButton.outlined(
                                label: l10n.profileSignOut,
                                onPressed: () => ref
                                    .read(authStateProvider.notifier)
                                    .signOut(),
                              ),
                            ),
                          ],
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
