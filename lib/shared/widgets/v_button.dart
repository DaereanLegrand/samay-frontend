import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

enum VButtonVariant { outlined, emphasized, dark }

/// Samay primary button — DESIGN.md §5.1, monochrome
///
/// | Variant | Spec |
/// |---|---|
/// | `VButton` / `VButton.outlined` | 1px white border, transparent fill, white `labelLarge` text, sharp, full-width, 14px vertical padding |
/// | `VButton.emphasized` | white fill, black text, sharp, full-width |
/// | `VButton.dark` | black (`surfaceAlt`) fill, white text, 1px white hairline — the primary-CTA voice |
///
/// Disabled (`onPressed: null` or [loading]): outline/text drop to
/// `muted #666666` (exempt from contrast as an inactive component).
/// Press feedback: α0.1 overlay of the variant's base color (no scale, no
/// bounce). Loading keeps the same shape with the spinner in the foreground
/// color (contrast-safe against the fill).
class VButton extends StatelessWidget {
  /// Design doc §5.1: 14px vertical padding (not on the 8-step scale) —
  /// shared by every variant.
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 14,
  );

  final Widget? child;
  final String? label;
  final VoidCallback? onPressed;
  final bool loading;
  final VButtonVariant variant;

  const VButton._({
    super.key,
    this.label,
    this.onPressed,
    this.loading = false,
    this.child,
    this.variant = VButtonVariant.outlined,
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

  /// BLACK button: `surfaceAlt` black fill,
  /// white text, 1px white hairline — the home/login CTA voice.
  factory VButton.dark({
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
      variant: VButtonVariant.dark,
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
        fill = AppColors.transparent;
        text = AppColors.white;
        borderColor = AppColors.white;
        overlayBase = AppColors.white;
      case VButtonVariant.emphasized:
        fill = AppColors.white;
        text = AppColors.discoBlack;
        borderColor = null;
        overlayBase = AppColors.discoBlack;
      case VButtonVariant.dark:
        // BLACK button: black fill, white text,
        // 1px white hairline.
        fill = AppColors.surfaceAlt;
        text = AppColors.white;
        borderColor = AppColors.white;
        overlayBase = AppColors.white;
    }

    // Disabled (and loading) drop outline/text to `muted` (§5.1).
    final WidgetStateProperty<Color?> foregroundColor =
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.muted;
          return text;
        });
    final WidgetStateProperty<BorderSide?> side =
        WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.disabled)
              ? AppColors.muted
              : (borderColor ?? AppColors.transparent);
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
      padding: _padding,
    );
    final style = base.copyWith(side: side, foregroundColor: foregroundColor);

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: style,
        child: loading
            ? VSpinner(size: 20, color: text)
            : child ??
                  Text(
                    label ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
      ),
    );
  }
}
