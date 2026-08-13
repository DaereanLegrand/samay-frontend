import 'dart:async';

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/theme/samay_durations.dart';

/// LUXE v2 AI-thinking typing indicator (ORCHESTRATION-LUXE.md component
/// vocabulary — owned by XL-04): 3 small dots with a staggered pulse,
/// α0.4↔1.0 easeInOut, for the chat input.
///
/// Cycle shape: one shared `thinkingDot` (900ms) alternate — each dot
/// completes one full up-down pulse (450ms up + 450ms down) per direction
/// of the alternate, offset by a third of the period, so a soft wave rolls
/// through the dots — followed by the [VBreathingGlow] idle-safe static
/// settle ([SamayDurations.motionCycleRest]) before the next cycle, so
/// `pumpAndSettle`-based tests land deterministically.
///
/// Reduced motion (`MediaQuery.disableAnimationsOf(context)`) → static
/// dots at full alpha, no ticker. Re-enabling animations resumes the pulse.
class VThinkingDots extends StatefulWidget {
  /// Dot fill color (the muted-strong neutral by default — accents stay
  /// minimal per the campaign's luxury = restraint rule).
  final Color color;

  /// Dot diameter (px).
  final double size;

  /// Gap between dots.
  final double spacing;

  const VThinkingDots({
    super.key,
    this.color = AppColors.mutedStrong,
    this.size = 6,
    this.spacing = AppSpacing.sm,
  });

  @override
  State<VThinkingDots> createState() => _VThinkingDotsState();
}

class _VThinkingDotsState extends State<VThinkingDots>
    with SingleTickerProviderStateMixin {
  static const int _dotCount = 3;

  /// Pulse alpha floor/ceiling (§: α0.4↔1.0).
  static const double _alphaMin = 0.4;
  static const double _alphaMax = 1.0;

  /// One direction of the alternate — half of the per-dot pulse period.
  /// The easeInOut shaping is applied in [_dotAlpha] via [Curves.easeInOut]
  /// (this Flutter's `AnimationController` has no constructor curve).
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.thinkingDot ~/ 2,
  );

  Timer? _cycleTimer;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _cycleTimer?.cancel();
      _cycleTimer = null;
      _controller.stop();
      _controller.value = 0;
    } else if (_cycleTimer == null) {
      _cycleTimer = Timer.periodic(_cyclePeriod, (_) => _runCycle());
      _runCycle();
    }
  }

  /// Full alternate: up then down; the periodic timer restarts it after the
  /// static settle. The `isAnimating` guard makes a late timer tick (jank,
  /// backgrounded frames) a no-op instead of a mid-cycle jump.
  void _runCycle() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0).then((_) {
      if (!mounted || _reduced) return;
      _controller.reverse();
    });
  }

  Duration get _cyclePeriod =>
      SamayDurations.thinkingDot + SamayDurations.motionCycleRest;

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Dot [index]'s alpha: reduced motion → static full; otherwise a
  /// triangular wave of the shared eased value staggered by `index/3` of
  /// the period — symmetric, so it stays continuous through the reverse
  /// leg.
  double _dotAlpha(int index) {
    if (_reduced) return _alphaMax;
    final t = Curves.easeInOut.transform(_controller.value);
    final phase = (t + index / _dotCount) % 1.0;
    final wave = 1 - (phase * 2 - 1).abs();
    return _alphaMin + (_alphaMax - _alphaMin) * wave;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _dotCount; i++) ...[
            if (i > 0) SizedBox(width: widget.spacing),
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _dotAlpha(i)),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
