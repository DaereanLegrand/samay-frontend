import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/theme/app_theme_scope.dart';

/// Samay card — DESIGN.md §5.3.
///
/// `surface #0A0A0A` fill over black, **hairline** `#1A1A1A` 1px borders,
/// sharp corners, `cardPadding` 16. The hairline is depth decoration (§7.2
/// boundary rule) — a card is never the only indicator of interactivity.
///
/// Inside a [AppThemeScope] the fill/borders switch to the theme's derived
/// tonal steps, so a card on a coloured group page is a shade of that colour
/// rather than a black box.
class VCard extends StatelessWidget {
  final Widget child;

  /// Inner padding. Defaults to [AppSpacing.cardPadding] (16). Pass
  /// [EdgeInsets.zero] when a child must bleed to the card's edges (e.g. a
  /// full-bleed picture inside a card).
  final EdgeInsetsGeometry padding;

  /// Use the raised tonal step ([AppPalette.surfaceAlt]) instead of the
  /// base [AppPalette.surface]. Defaults to the base step.
  final bool raised;

  const VCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    return Container(
      decoration: BoxDecoration(
        color: themed
            ? (raised ? palette.surfaceAlt : palette.surface)
            : AppColors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(
            color: themed ? palette.hairline : AppColors.hairline,
          ),
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}
