import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/shared/widgets/glass/v_gradient_border.dart';

/// Liquid-glass surface (LUXE v2, XL-02).
///
/// Layered from the back forward:
/// 1. `BackdropFilter(blur)` over a white gradient fill (α0.05 → α0.01,
///    topLeft → bottomRight) — clipped to [radius].
/// 2. The [child] content (padded, clipped to [radius]).
/// 3. A 1px top highlight line (white α0.10, fading at the ends).
/// 4. A [VGradientBorder] ring on top: white α0.28 → pastel α0.18 →
///    transparent (white-only when [gradient] is null).
/// 5. A soft pastel BoxShadow glow ([AppGradients.glowShadows]) on an outer
///    DecoratedBox when [glowAlpha] > 0.
///
/// IMPORTANT: BackdropFilter over pure black is invisible — the glass reads
/// through its white fill + border + glow; the blur only matters over content
/// (images, other glass). Over flat black it degrades to a
/// subtle white-tinted surface, which is exactly the design intent.
///
/// [gradient] is the screen's `AppGradient` family (rose/violet/cyan/...);
/// null yields white-only glass with no pastel border or glow.
class VGlass extends StatelessWidget {
  /// The pastel family driving the border + glow. Null → white-only glass.
  final AppGradient? gradient;

  /// Corner geometry — zero for cards (brutalism), 16–20 for chips/inputs/
  /// sheets (liquid).
  final BorderRadius radius;

  /// Backdrop sigma blur applied to the content beneath.
  final double blur;

  /// Glow intensity (0 → no shadow). Applied via `glowShadows` when > 0 and
  /// [gradient] is not null.
  final double glowAlpha;

  /// Inner content insets.
  final EdgeInsets? padding;

  /// The content shown through the glass.
  final Widget child;

  const VGlass({
    super.key,
    this.gradient,
    this.radius = BorderRadius.zero,
    this.blur = 12.0,
    this.glowAlpha = 0.0,
    this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final glass = RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(child: _backdrop()),
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: ClipRRect(borderRadius: radius, child: child),
          ),
          Positioned.fill(child: _topHighlight()),
          // The border ring is pure chrome (a `SizedBox.expand` child) — it
          // must never intercept pointer events above the content (XL-07:
          // the transparent-filled ring otherwise eats every tap/hit-test
          // on glass surfaces, warning "tap missed" in widget tests).
          Positioned.fill(
            child: IgnorePointer(
              child: VGradientBorder(
                gradient: _borderGradient(),
                radius: radius,
                color: Colors.transparent,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
    if (glowAlpha <= 0 || gradient == null) return glass;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppGradients.glowShadows(gradient!, alpha: glowAlpha),
      ),
      child: glass,
    );
  }

  /// The blurred white fill — the actual "glass" body. Clipped to [radius]
  /// because a BackdropFilter otherwise blurs everything on screen.
  Widget _backdrop() {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white.withValues(alpha: 0.05),
                AppColors.white.withValues(alpha: 0.01),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1px specular sheen at the top edge, fading at both ends — reads as the
  /// glass rim catching light. Painted above content, below the border ring.
  Widget _topHighlight() {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: radius,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.white.withValues(alpha: 0.0),
                  AppColors.white.withValues(alpha: 0.10),
                  AppColors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// White α0.28 → pastel α0.18 → transparent (design language); white-only
  /// when there is no gradient family.
  LinearGradient _borderGradient() {
    final pastel = gradient?.colors.first;
    final mid = pastel ?? AppColors.white;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.white.withValues(alpha: 0.28),
        mid.withValues(alpha: pastel == null ? 0.10 : 0.18),
        mid.withValues(alpha: 0.0),
      ],
    );
  }
}

/// Sharp, brutalist glass card — [VGlass] with radius zero, `glowAlpha` 0.18
/// and card padding 16 (the liquid-glass sibling of [VCard]).
///
/// Border semantics: hairline ring via [VGradientBorder] (white-only when no
/// [gradient] family is given, pastel-ringed otherwise).
class VGlassCard extends StatelessWidget {
  /// The pastel family driving the border + glow. Null → white-only glass.
  final AppGradient? gradient;

  /// Glow intensity (default 0.18).
  final double glowAlpha;

  /// The card content.
  final Widget child;

  const VGlassCard({
    super.key,
    this.gradient,
    this.glowAlpha = 0.18,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return VGlass(
      gradient: gradient,
      radius: BorderRadius.zero,
      glowAlpha: glowAlpha,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }
}
