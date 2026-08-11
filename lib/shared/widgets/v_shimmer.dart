import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/theme/samay_durations.dart';

/// One shimmer sweep cycle — DISCO-DESIGN-SYSTEM.md §4.5 `shimmer` 1200ms
/// (U-18 promoted U-06's local const into `SamayDurations`).

/// Skeleton/shimmer loading (DISCO-DESIGN-SYSTEM.md §5.8/§6.3, owned by
/// U-06 for the primitive — U-22 composes skeleton screens with it).
///
/// Wraps [child] — skeleton boxes built with [VShimmerBox] — in a
/// `surfaceAlt #111111`-based gradient sweep: a white highlight band slides
/// across at `shimmer` 1200ms with alpha oscillating 0.5 → 0.9 (§5.8 "α
/// 0.5→0.9"). No color, keep gray.
///
/// Reduced motion: `MediaQuery.disableAnimationsOf(context)` gates the sweep
/// (§7.5) — the child renders as static gray blocks, no ticker, no mask.
/// The sweep restarts automatically when animations are re-enabled.
class VShimmer extends StatefulWidget {
  final Widget child;

  const VShimmer({super.key, required this.child});

  @override
  State<VShimmer> createState() => _VShimmerState();
}

class _VShimmerState extends State<VShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: SamayDurations.shimmer);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        if (reduced) return child!;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.surfaceAlt,
              AppColors.white.withValues(alpha: _highlightAlpha()),
              AppColors.surfaceAlt,
            ],
            stops: const [0.3, 0.5, 0.7],
            transform: _SlidingGradientTransform(_animation.value),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }

  /// §5.8 sweep: highlight alpha oscillates 0.5 → 0.9 with the sweep.
  double _highlightAlpha() => 0.5 + 0.4 * _animation.value;
}

/// Slides the gradient band across the box: value 0 → band at the left
/// edge, value 1 → band at the right edge (repeat(reverse: true) sweeps
/// back and forth, matching the doc's "subtle" P5 motion).
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this._slidePercent);

  final double _slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (_slidePercent * 2 - 1),
      0,
      0,
    );
  }
}

/// Fixed-size skeleton block (DISCO-DESIGN-SYSTEM.md §5.8): `surfaceAlt
/// #111111` fill, sharp corners (radius 0 — §4.2), const-constructible.
///
/// Static on its own; wrap in [VShimmer] to apply the sweep (e.g. a whole
/// skeleton screen with several boxes). U-22 composes screen skeletons from
/// these primitives.
class VShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const VShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.color = AppColors.surfaceAlt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(width: width, height: height, color: color);
  }
}
