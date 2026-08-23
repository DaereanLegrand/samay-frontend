import 'dart:async';

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/theme/samay_durations.dart';

/// LUXE v2 generic pulsing glow wrapper (the LUXE restyle pass (historical) component
/// vocabulary — owned by XL-04).
///
/// Renders [child] inside a [DecoratedBox] whose [BoxShadow] stack comes
/// from [AppGradients.glowShadows] with the halo alpha pulsed between
/// [alphaMin] (0.35) and [alphaMax] (0.7) on a `glowPulse` (3800ms)
/// `easeInOut` alternate, matching the campaign's "slowly pulsate" directive
/// (non-negotiable 5: 3.6–4s ease-in-out α ramp).
///
/// Cycle shape: 1.9s easeInOut up (α0.35→α0.7) + 1.9s easeInOut down
/// (α0.7→α0.35), then [SamayDurations.motionCycleRest] static settle at the
/// low point before the next cycle — the idle-safe
/// engine: a hard `repeat()` schedules frames forever, hanging every
/// `pumpAndSettle`-based widget test; the settle pause lets tests land
/// deterministically (controller holding value 0 → the α0.35 floor).
///
/// Reduced motion (`MediaQuery.disableAnimationsOf(context)`) → static glow
/// fixed at α0.55, no ticker. Re-enabling animations resumes the pulse.
class VGlowPulse extends StatefulWidget {
  /// The glow family ([AppGradients.glowShadows] source).
  final AppGradient gradient;

  /// The content the glow wraps (buttons, cards, hero text, ...).
  final Widget child;

  /// Halo blur radius (px) forwarded to [AppGradients.glowShadows].
  final double blur;

  /// Pulse floor — the shadow stack alpha at rest.
  final double alphaMin;

  /// Pulse ceiling — the shadow stack alpha at the peak.
  final double alphaMax;

  /// Full pulse period (up + down); each direction runs half of it.
  final Duration duration;

  const VGlowPulse({
    super.key,
    required this.gradient,
    required this.child,
    this.blur = 48,
    this.alphaMin = 0.35,
    this.alphaMax = 0.7,
    this.duration = SamayDurations.glowPulse,
  });

  @override
  State<VGlowPulse> createState() => _VGlowPulseState();
}

class _VGlowPulseState extends State<VGlowPulse>
    with SingleTickerProviderStateMixin {
  /// Reduced-motion hold: static shadow alpha between the pulse extremes
  /// (spec: 0.55, slightly above the 0.35/0.7 midpoint 0.525).
  static const double _staticAlpha = 0.55;

  /// One direction of the alternate — half of the pulse period. The
  /// easeInOut shaping is applied in [build] via [Curves.easeInOut] (this
  /// Flutter's `AnimationController` has no constructor curve).
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration ~/ 2,
  );

  Timer? _cycleTimer;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      // Static glow at the midpoint between the pulse extremes, no ticker.
      _cycleTimer?.cancel();
      _cycleTimer = null;
      _controller.stop();
      _controller.value = 0;
    } else if (_cycleTimer == null) {
      _cycleTimer = Timer.periodic(_cyclePeriod, (_) => _runCycle());
      _runCycle();
    }
  }

  /// Full alternate: up (α0.35→α0.7) then down (α0.7→α0.35); the periodic
  /// timer restarts it after the static settle. The `isAnimating` guard
  /// makes a late timer tick (jank, backgrounded frames) a no-op instead of
  /// a mid-cycle jump.
  void _runCycle() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0).then((_) {
      if (!mounted || _reduced) return;
      _controller.reverse();
    });
  }

  Duration get _cyclePeriod =>
      widget.duration + SamayDurations.motionCycleRest;

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final alpha = _reduced
            ? _staticAlpha
            : widget.alphaMin + (widget.alphaMax - widget.alphaMin) * t;
        return DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: AppGradients.glowShadows(
              widget.gradient,
              alpha: alpha,
              blur: widget.blur,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
