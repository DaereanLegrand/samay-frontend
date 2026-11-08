import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/features/groups/theme/group_theme_scope.dart';
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

  /// When false, a [loading] button disables (drops to `muted`) but keeps
  /// rendering its [child]/[label] instead of the foreground spinner.
  final bool showLoadingSpinner;

  /// Drops the 1px border stroke (the variant fill/foreground are unchanged).
  final bool borderless;
  final VButtonVariant variant;

  const VButton._({
    super.key,
    this.label,
    this.onPressed,
    this.loading = false,
    this.showLoadingSpinner = true,
    this.borderless = false,
    this.child,
    this.variant = VButtonVariant.outlined,
  });

  factory VButton({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    bool showLoadingSpinner = true,
    bool borderless = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      showLoadingSpinner: showLoadingSpinner,
      borderless: borderless,
      child: child,
    );
  }

  factory VButton.outlined({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    bool showLoadingSpinner = true,
    bool borderless = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      showLoadingSpinner: showLoadingSpinner,
      borderless: borderless,
      child: child,
    );
  }

  factory VButton.emphasized({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    bool showLoadingSpinner = true,
    bool borderless = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      showLoadingSpinner: showLoadingSpinner,
      borderless: borderless,
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
    bool showLoadingSpinner = true,
    bool borderless = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      showLoadingSpinner: showLoadingSpinner,
      borderless: borderless,
      variant: VButtonVariant.dark,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = GroupThemeScope.paletteOf(context);
    final themed = !identical(palette, GroupThemeScope.standardPalette);
    // Inside a themed group surface the button ink/fill come from the derived
    // scale, so a "dark" button is a shade of the theme instead of black.
    final themedInk = palette.foreground;
    final themedFill = palette.surfaceAlt;

    final Color fill;
    final Color text;
    final Color? borderColor;
    final Color overlayBase;
    switch (variant) {
      case VButtonVariant.outlined:
        fill = AppColors.transparent;
        text = themed ? themedInk : AppColors.white;
        borderColor = themed ? themedInk : AppColors.white;
        overlayBase = themed ? themedInk : AppColors.white;
      case VButtonVariant.emphasized:
        fill = themed ? themedInk : AppColors.white;
        text = themed ? palette.background : AppColors.discoBlack;
        borderColor = null;
        overlayBase = themed ? palette.background : AppColors.discoBlack;
      case VButtonVariant.dark:
        // BLACK button: black fill, white text,
        // 1px white hairline. On a themed surface: raised tone + foreground.
        fill = themed ? themedFill : AppColors.surfaceAlt;
        text = themed ? themedInk : AppColors.white;
        borderColor = themed ? themedInk : AppColors.white;
        overlayBase = themed ? themedInk : AppColors.white;
    }

    // Disabled (and loading) drop outline/text to `muted` (§5.1).
    final WidgetStateProperty<Color?> foregroundColor =
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return themed ? palette.mutedForeground : AppColors.muted;
          }
          return text;
        });
    final WidgetStateProperty<BorderSide?> side = borderless
        ? const WidgetStatePropertyAll<BorderSide?>(
            BorderSide(color: AppColors.transparent),
          )
        : WidgetStateProperty.resolveWith((states) {
            final color = states.contains(WidgetState.disabled)
                ? (themed ? palette.mutedForeground : AppColors.muted)
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
        child: loading && showLoadingSpinner
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
