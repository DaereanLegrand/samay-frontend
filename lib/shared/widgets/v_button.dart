import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';

enum VButtonVariant { outlined, emphasized, glow }

/// Samay primary button — DISCO-DESIGN-SYSTEM.md §5.1 (U-05).
///
/// | Variant | Spec |
/// |---|---|---|
/// | `VButton` / `VButton.outlined` | 1px white border, transparent fill, white `labelLarge` text, sharp, full-width, 14px vertical padding |
/// | `VButton.emphasized` | white fill, black text, sharp, full-width |
/// | `VButton.glowAccent` | pink 1px border (or pink fill when `filled`) + black text, optional `glow-hairline` shadow; pressed = `glowPinkDeep` fill + white text (5.87:1). Use ≤ 1 per screen — always a primary action |
///
/// Disabled (`onPressed: null` or [loading]): outline/text drop to
/// `muted #666666` (exempt from contrast as an inactive component). Press
/// feedback: α0.1 white/black overlay (no scale, no bounce). Loading keeps
/// the same shape with the spinner in the foreground color.
class VButton extends StatelessWidget {
  final Widget? child;
  final String? label;
  final VoidCallback? onPressed;
  final bool loading;
  final VButtonVariant variant;
  final bool filled;

  const VButton._({
    super.key,
    this.label,
    this.onPressed,
    this.loading = false,
    this.child,
    this.variant = VButtonVariant.outlined,
    this.filled = false,
  });

  factory VButton({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      child: child,
    );
  }

  factory VButton.outlined({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      child: child,
    );
  }

  factory VButton.emphasized({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      variant: VButtonVariant.emphasized,
      child: child,
    );
  }

  /// §5.1 glow-accent variant — pink border (or pink fill when [filled]).
  factory VButton.glowAccent({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    bool filled = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      filled: filled,
      variant: VButtonVariant.glow,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color text;
    final Color? borderColor;
    final Color overlayBase;
    switch (variant) {
      case VButtonVariant.outlined:
        fill = Colors.transparent;
        text = AppColors.white;
        borderColor = AppColors.white;
        overlayBase = AppColors.white;
      case VButtonVariant.emphasized:
        fill = AppColors.white;
        text = AppColors.discoBlack;
        borderColor = null;
        overlayBase = AppColors.discoBlack;
      case VButtonVariant.glow:
        fill = filled ? AppColors.glowPink : Colors.transparent;
        text = filled ? AppColors.discoBlack : AppColors.glowPink;
        borderColor = AppColors.glowPink;
        overlayBase = filled ? AppColors.discoBlack : AppColors.white;
    }

    // Disabled (and loading) drop outline/text to `muted` (§5.1); the glow
    // variant's pressed state is `glowPinkDeep` fill + white text (5.87:1).
    final WidgetStateProperty<Color?> backgroundColor =
        WidgetStateProperty.resolveWith((states) {
          if (variant == VButtonVariant.glow &&
              states.contains(WidgetState.pressed)) {
            return AppColors.glowPinkDeep;
          }
          return fill;
        });
    final WidgetStateProperty<Color?> foregroundColor =
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.muted;
          if (variant == VButtonVariant.glow &&
              states.contains(WidgetState.pressed)) {
            return AppColors.white;
          }
          return text;
        });
    final WidgetStateProperty<BorderSide?> side =
        WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.disabled)
              ? AppColors.muted
              : (borderColor ?? Colors.transparent);
          return BorderSide(color: color);
        });

    // §5.1 press feedback: α0.1 overlay of the variant's base color — the
    // per-state alphas are derived by TextButton.styleFrom.
    final base = TextButton.styleFrom(
      foregroundColor: text,
      backgroundColor: fill,
      overlayColor: overlayBase,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      // Design doc §5.1: 14px vertical padding (not on the 8-step scale).
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
    final style = base.copyWith(
      side: side,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: style,
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: text),
              )
            : child ??
                  Text(
                    label ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // §5.1: glow-accent text may carry the glow-hairline shadow
                    // (1 layer, glowPink α0.35, blur = fontSize × 0.25).
                    style: variant == VButtonVariant.glow && !filled
                        ? TextStyle(
                            shadows: [
                              Shadow(
                                color: AppColors.glowPink.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 3.5,
                              ),
                            ],
                          )
                        : null,
                  ),
      ),
    );
  }
}
