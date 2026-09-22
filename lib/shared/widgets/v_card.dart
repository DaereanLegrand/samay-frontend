import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';

/// Samay card — DESIGN.md §5.3.
///
/// `surface #0A0A0A` fill over black, **hairline** `#1A1A1A` 1px borders,
/// sharp corners, `cardPadding` 16. The hairline is depth decoration (§7.2
/// boundary rule) — a card is never the only indicator of interactivity.
class VCard extends StatelessWidget {
  final Widget child;

  /// Inner padding. Defaults to [AppSpacing.cardPadding] (16). Pass
  /// [EdgeInsets.zero] when a child must bleed to the card's edges (e.g. a
  /// full-bleed picture inside a card).
  final EdgeInsetsGeometry padding;

  const VCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}
