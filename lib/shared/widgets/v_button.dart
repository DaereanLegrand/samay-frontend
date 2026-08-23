import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

enum VButtonVariant { outlined, emphasized, glow, dark }

/// Samay primary button — DESIGN.md §5.1 (U-05), LUXE v2
/// gradient-capable (the LUXE restyle pass (historical) "NO PINK MAINS", 2026-08-12).
///
/// | Variant | Spec |
/// |---|---|---|
/// | `VButton` / `VButton.outlined` | 1px white border, transparent fill, white `labelLarge` text, sharp, full-width, 14px vertical padding; `gradient:` → pastel gradient border |
/// | `VButton.emphasized` | white fill, black text, sharp, full-width; `gradient:` → family gradient fill — pastel-first stops keep black text contrast |
/// | `VButton.glowAccent` | 1px **violet-family** gradient border (or [gradient]), black text when [filled] / white when outline, `AppGradients.glowShadows` halo at α0.35; pressed → darker-violet overlay + white text. Use ≤ 1 per screen — always a primary action |
///
/// The accent family default is **violet — never pink** (user directive
/// 2026-08-12: pink is not the main color). Callers pass `gradient:` to
/// adopt their screen's family (`AppGradients.familyOf`).
/// [VButtonVariant.glow] always renders its ring as a 1px gradient
/// ([VGradientBorder]) and its fill as the family gradient when [filled].
///
/// Disabled (`onPressed: null` or [loading]): outline/text drop to
/// `muted #666666` (exempt from contrast as an inactive component); the
/// gradient ring drops to a muted rule as well. Press feedback: α0.1
/// white/black overlay (no scale, no bounce); the glow variant's pressed
/// state is the family's darker-violet overlay + white text. Loading keeps
/// the same shape with the spinner in the foreground color (contrast-safe
/// against the fill).
class VButton extends StatelessWidget {
  /// Design doc §5.1: 14px vertical padding (not on the 8-step scale) —
  /// the documented U-03 keeper, shared by both render paths.
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 14,
  );

  final Widget? child;
  final String? label;
  final VoidCallback? onPressed;
  final bool loading;
  final VButtonVariant variant;
  final bool filled;

  /// LUXE gradient family override. Null → the variant default:
  /// [VButtonVariant.glow] resolves to [AppGradients.violet]; the flat
  /// variants keep their white treatment. Never pink.
  final AppGradient? gradient;

  const VButton._({
    super.key,
    this.label,
    this.onPressed,
    this.loading = false,
    this.child,
    this.variant = VButtonVariant.outlined,
    this.filled = false,
    this.gradient,
  });

  factory VButton({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    AppGradient? gradient,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      gradient: gradient,
      child: child,
    );
  }

  factory VButton.outlined({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    AppGradient? gradient,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      gradient: gradient,
      child: child,
    );
  }

  factory VButton.emphasized({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    AppGradient? gradient,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      variant: VButtonVariant.emphasized,
      gradient: gradient,
      child: child,
    );
  }

  /// §5.1 glow-accent variant — LUXE v2: violet-family gradient ring (or
  /// [gradient]), black text when [filled], white when outline; pressed =
  /// darker-violet overlay + white text.
  factory VButton.glowAccent({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    bool filled = false,
    AppGradient? gradient,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      filled: filled,
      variant: VButtonVariant.glow,
      gradient: gradient,
      child: child,
    );
  }

  /// BLACK button (user directive 2026-08-14): `surfaceAlt` black fill,
  /// white text, 1px white hairline — the home/login CTA voice. Never a
  /// family gradient; same press feedback as the flat variants.
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
    // The glow variant always resolves a family (violet by default); the
    // flat variants only gradient-render when the caller passes one.
    final family =
        gradient ??
        (variant == VButtonVariant.glow ? AppGradients.violet : null);
    if (family == null) return _flatButton();
    return _gradientButton(family);
  }

  /// The legacy flat path — byte-identical rendering to the pre-LUXE
  /// button (white border / white fill + black text / muted disabled).
  Widget _flatButton() {
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
      case VButtonVariant.dark:
        // BLACK button (user directive 2026-08-14): black fill, white text,
        // 1px white hairline.
        fill = AppColors.surfaceAlt;
        text = AppColors.white;
        borderColor = AppColors.white;
        overlayBase = AppColors.white;
      case VButtonVariant.glow:
        // Unreachable — the glow variant always resolves a family above.
        // Defensive flat fallback so the switch stays exhaustive.
        fill = Colors.transparent;
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
      padding: _padding,
    );
    final style = base.copyWith(side: side, foregroundColor: foregroundColor);

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: style,
        child: _child(text, glowFamily: null),
      ),
    );
  }

  /// The LUXE gradient path — [VGradientBorder] ring + optional family
  /// gradient fill + the glow variant's halo, all driven by [family].
  Widget _gradientButton(AppGradient family) {
    final glow = variant == VButtonVariant.glow;
    final isDisabled = loading || onPressed == null;

    // Disabled: the ring drops to `muted` (§5.1 inactive components); the
    // fill keeps the family gradient (legacy behavior kept the flat fill).
    final ringColors = isDisabled
        ? [AppColors.muted, AppColors.muted]
        : family.colors;
    final ringGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: ringColors,
      // The disabled ring is a flat muted rule (2 colors) — no stops.
      stops: isDisabled ? null : family.stops,
    );

    // Text color: black on any light fill (pastel-first), white otherwise;
    // disabled text drops to `muted`. The glow variant's pressed state
    // flips to white on the darker-violet overlay.
    final text = glow
        ? (filled ? AppColors.discoBlack : AppColors.white)
        : (variant == VButtonVariant.emphasized
              ? AppColors.discoBlack
              : AppColors.white);
    final WidgetStateProperty<Color?> foregroundColor =
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.muted;
          if (glow && states.contains(WidgetState.pressed)) {
            return AppColors.white;
          }
          return text;
        });

    // Press feedback: the α0.1 base overlay from styleFrom (no scale, no
    // bounce), except the glow variant's pressed state, which darkens the
    // whole face toward the family's vivid end — the M3 InkHighlight paints
    // the resolved overlay color over the full button rect ("pressed →
    // darker violet").
    final baseOverlayColor = glow
        ? AppColors.white
        : variant == VButtonVariant.emphasized
        ? AppColors.discoBlack
        : AppColors.white;
    final baseOverlay = TextButton.styleFrom(
      overlayColor: baseOverlayColor,
    ).overlayColor;
    final WidgetStateProperty<Color?> overlay = WidgetStateProperty.resolveWith(
      (states) {
        if (glow && states.contains(WidgetState.pressed)) {
          return Color.lerp(family.colors.last, AppColors.discoBlack, 0.35);
        }
        return baseOverlay?.resolve(states);
      },
    );

    final style =
        TextButton.styleFrom(
          foregroundColor: text,
          backgroundColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sharp),
          padding: _padding,
        ).copyWith(
          side: const WidgetStatePropertyAll(
            BorderSide(color: Colors.transparent),
          ),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: foregroundColor,
          overlayColor: overlay,
        );

    // Fill: family gradient when the variant is a filled surface — the
    // glow variant only when [filled]; emphasized always (white → gradient).
    final showFill = glow ? filled : variant == VButtonVariant.emphasized;
    final Widget face = DecoratedBox(
      key: showFill ? const ValueKey('vButtonGradientFill') : null,
      decoration: BoxDecoration(
        borderRadius: AppRadius.sharp,
        gradient: showFill ? family.linear() : null,
      ),
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: style,
        child: _child(text, glowFamily: glow && !filled ? family : null),
      ),
    );

    final Widget ring = _GradientBorder(
      gradient: ringGradient,
      width: 1,
      radius: AppRadius.sharp,
      color: Colors.transparent,
      child: face,
    );

    // The glow variant's halo (§5.1 glow-hairline, LUXE slow-glow family
    // stack): three zero-offset layers at α0.35 (tight → wide aura).
    final Widget body = glow
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.sharp,
              boxShadow: AppGradients.glowShadows(family, alpha: 0.35),
            ),
            child: ring,
          )
        : ring;
    return SizedBox(width: double.infinity, child: body);
  }

  /// The button payload — loading spinner in the foreground [text] color
  /// (contrast-safe against the fill) or the label/child. [glowFamily]
  /// non-null → the glow variant's outline label carries the family's
  /// glow-hairline shadow.
  Widget _child(Color text, {required AppGradient? glowFamily}) {
    return loading
        ? VSpinner(size: 20, color: text)
        : child ??
              Text(
                label ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // §5.1: glow-accent outline text may carry the glow-hairline
                // shadow (1 layer, family mid stop α0.35, blur 3.5).
                style: glowFamily != null
                    ? TextStyle(
                        shadows: [
                          Shadow(
                            color: glowFamily.colors[1].withValues(alpha: 0.35),
                            blurRadius: 3.5,
                          ),
                        ],
                      )
                    : null,
              );
  }
}

class _GradientBorder extends StatelessWidget {
  final LinearGradient gradient;
  final double width;
  final BorderRadius radius;
  final Color color;
  final Widget child;

  const _GradientBorder({
    required this.gradient,
    this.width = 1.0,
    this.radius = BorderRadius.zero,
    this.color = AppColors.surface,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(width),
      decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius.subtract(BorderRadius.all(Radius.circular(width))),
        ),
        child: child,
      ),
    );
  }
}
