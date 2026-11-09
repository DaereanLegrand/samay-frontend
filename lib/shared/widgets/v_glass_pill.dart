import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Apple-style floating glass pill — the iOS "liquid glass" toolbar element.
///
/// A stadium capsule (a perfect circle on a square child) that blurs whatever
/// is behind it: `ClipRRect` → [BackdropFilter] (blur 20) → a `surface` α0.1
/// fill with a white α0.15 hairline. This is the exact recipe of the floating
/// bottom-nav pill (`MainShell._FloatingNavBar`) and `VPillTabBar`, so every
/// glass surface in the app reads the same.
///
/// The pill hugs its [child]'s size (plus [padding]); the child is painted ON
/// TOP of the glass, un-clipped and untransformed, so a badge or a shadow that
/// spills past the button still shows and only the bubble animates.
///
/// [reveal] (0→1) materialises the bubble for the header's morph: it ramps the
/// blur sigma and the fill/border alpha together. It deliberately does NOT use
/// an `Opacity` widget — `BackdropFilter` as a child of `Opacity` (or any filter
/// widget that pushes a saveLayer) does not blur (flutter#31706); animating the
/// blur sigma and the tint alpha is the safe way to fade a backdrop blur.
class VGlassPill extends StatelessWidget {
  const VGlassPill({
    super.key,
    required this.child,
    this.blur = 20,
    this.padding = EdgeInsets.zero,
    this.reveal = 1,
    this.scale = 1,
    this.alignment = Alignment.center,
  });

  /// The pill's content, painted over the glass (never clipped or scaled).
  final Widget child;

  /// Backdrop-blur sigma (logical px) at full reveal — matches the nav pill.
  final double blur;

  /// Optional inner padding so a bare glyph gets a capsule around it.
  final EdgeInsetsGeometry padding;

  /// 0 = bubble invisible, 1 = full glass. Ramps blur + tint (not `Opacity`).
  final double reveal;

  /// Bubble scale about [alignment] (the bubble grows in; the child does not).
  final double scale;

  /// Origin of the [scale] transform.
  final AlignmentGeometry alignment;

  /// Stadium geometry — Clips clamp the radius to the shorter side, so a square
  /// child becomes a circle and a wide one a capsule.
  static const double _radius = 999;

  /// `surface` fill opacity of the full glass.
  static const double _fillOpacity = 0.1;

  /// White hairline opacity of the full glass.
  static const double _sheenOpacity = 0.15;

  @override
  Widget build(BuildContext context) {
    final r = reveal.clamp(0.0, 1.0);
    // Skip the (expensive) backdrop layer entirely when the bubble is hidden,
    // so a header at rest costs nothing.
    Widget glass = ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur * r, sigmaY: blur * r),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.palette.surface.withValues(alpha: _fillOpacity * r),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: context.palette.foreground.withValues(alpha: _sheenOpacity * r),
            ),
          ),
        ),
      ),
    );
    if (scale != 1) {
      glass = Transform.scale(scale: scale, alignment: alignment, child: glass);
    }
    final Widget? bubble = r <= 0.001 ? null : Positioned.fill(child: glass);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ?bubble,
        Padding(padding: padding, child: child),
      ],
    );
  }
}
