import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_breathing_glow.dart';
import 'package:samay/shared/widgets/v_button.dart';

/// Coming-soon screen — DISCO-DESIGN-SYSTEM.md §5.7 (U-05).
///
/// Black AppBar (theme), icon at `xxl 48` in `#333333` (pass [iconColor] for
/// the faint `glowPink` α0.5 hero-topic option), "Próximamente" in Playfair
/// Display italic 32 with the soft glow stack, description in `mutedStrong`,
/// outlined back button. Never a full-screen accent. The "Próximamente"
/// title breathes via [VBreathingGlow] (§6.2 — one breathing element per
/// screen, reduced-motion-gated; §5.7 allows "icon fade + glow breathing").
class VComingSoonScreen extends StatelessWidget {
  final String title;
  final String description;
  final bool showBackButton;
  final IconData icon;
  final Color iconColor;

  const VComingSoonScreen({
    super.key,
    required this.title,
    required this.description,
    this.showBackButton = true,
    this.icon = Icons.construction,
    this.iconColor = AppColors.border,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        // §7.3: scroll-safe body (the OTP pattern, U-07) — the centered
        // column overflows small screens at ≥1.5× text scale; keeps the
        // centered layout when the content fits and scrolls when it
        // doesn't. Never clip.
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
                      Icon(icon, size: AppIconSizes.xxl, color: iconColor),
                      const SizedBox(height: AppSpacing.lg),
                      VBreathingGlow(
                        text: l10n.comingSoonSoon,
                        style: AppTypography.displaySmall,
                        soft: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedStrong,
                        ),
                      ),
                      if (showBackButton) ...[
                        const SizedBox(height: AppSpacing.xl),
                        // U-19: the back CTA is full-width (max 320) — the
                        // fixed 200px width clipped long labels at 1.5×.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: VButton.outlined(
                            label: l10n.comingSoonBack,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
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
