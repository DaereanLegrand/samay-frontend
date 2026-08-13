import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

/// 1px gradient border primitive (LUXE v2 liquid glass, XL-02).
///
/// The classic double-container trick: an outer [Container] paints the
/// [gradient] across a ring of [width] (its `padding`), an inner [Container]
/// fills the rest with [color] (default surface) and clips its child to the
/// radius minus the border width. No custom painter needed — two boxes.
///
/// Used by [VGlass] and by callers that want a bare gradient ring (chips,
/// inputs, sheets). Const-constructible; the deflated inner radius is
/// computed at build time.
class VGradientBorder extends StatelessWidget {
  /// The border ring gradient — callers build it from `AppGradient.linear()`.
  final LinearGradient gradient;

  /// Ring thickness in logical pixels (default 1 — the liquid-glass hairline).
  final double width;

  /// Corner geometry shared by both boxes. Default zero — sharp (brutalism).
  final BorderRadius radius;

  /// Inner fill color (default [AppColors.surface]).
  final Color color;

  /// Insets applied inside the inner box.
  final EdgeInsets padding;

  /// The content wrapped by the gradient ring.
  final Widget child;

  const VGradientBorder({
    super.key,
    required this.gradient,
    this.width = 1.0,
    this.radius = BorderRadius.zero,
    this.color = AppColors.surface,
    this.padding = EdgeInsets.zero,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(width),
      decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
      child: Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          borderRadius: _innerRadius(),
        ),
        child: child,
      ),
    );
  }

  /// The inner box's corners: the outer radius shrunk by the ring [width]
  /// (clamped to zero at render, so sharp corners stay sharp).
  BorderRadiusGeometry _innerRadius() {
    return radius.subtract(BorderRadius.all(Radius.circular(width)));
  }
}
