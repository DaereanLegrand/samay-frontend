import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/theme/samay_durations.dart';

/// LUXE v2 ambient aurora background (ORCHESTRATION-LUXE.md component
/// vocabulary — owned by XL-04): one per screen, 2–3 huge radial pastel
/// blobs (α 0.04–0.10) drifting slowly (9–12s), reduce-motion → static.
///
/// Full-bleed [Stack]: an `IgnorePointer` + `RepaintBoundary` layer of
/// circular blobs (diameter ≈ 1.5× screen, positioned mostly off-screen at
/// top-left / top-right / bottom-center) under the optional [child]. Each
/// blob is a `RepaintBoundary` around a [BoxDecoration] with a
/// [RadialGradient] fill (no shadows — alpha fills only, per spec); all
/// stops are watered with [opacity] so the aurora stays a whisper over the
/// always-black background.
///
/// Drift: one shared [SamayDurations.auroraDrift] controller orbits every
/// blob by a few px on per-blob sin/cos phases — a slow 10s loop followed by
/// the [VBreathingGlow] idle-safe static settle ([SamayDurations.motionCycleRest])
/// before the next orbit, so `pumpAndSettle`-based tests land
/// deterministically. Reduced motion → static base positions, no ticker.
class VAurora extends StatefulWidget {
  /// The glow families for the blobs — default spans three families
  /// (cyan/violet/mint) so the "all colors used" palette rule holds — NO
  /// pink mains (user directive 2026-08-12: rose may appear only as a
  /// micro-accent, never in the default ambient set).
  final List<AppGradient> gradients;

  /// Alpha applied to every gradient stop of every blob (0.04–0.10 range).
  final double opacity;

  /// Optional content rendered above the aurora layer.
  final Widget? child;

  const VAurora({
    super.key,
    this.gradients = const [
      AppGradients.cyan,
      AppGradients.violet,
      AppGradients.mint,
    ],
    this.opacity = 0.10,
    this.child,
  });

  @override
  State<VAurora> createState() => _VAuroraState();
}

class _VAuroraState extends State<VAurora>
    with SingleTickerProviderStateMixin {
  /// Blob diameter: 1.5× the long edge, so each circle stays mostly
  /// off-screen while its soft cap washes the corner/edge.
  static const double _blobScale = 1.5;

  /// Anchor inset: centers the blob ~0.35× its diameter outside the screen.
  static const double _anchorInset = 0.85;

  /// Orbit radius of the drift (a few px — the aurora must be static-
  /// looking; the motion is barely there).
  static const double _driftRadius = 12;

  static const List<Alignment> _anchors = [
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.bottomCenter,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.auroraDrift,
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
      _controller.value = 0; // static base positions
    } else if (_cycleTimer == null) {
      _cycleTimer = Timer.periodic(_cyclePeriod, (_) => _runCycle());
      _runCycle();
    }
  }

  /// One full drift orbit, restarted by the periodic timer after the
  /// static settle — the `isAnimating` guard makes a late timer tick a
  /// no-op instead of a mid-orbit jump.
  void _runCycle() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0);
  }

  Duration get _cyclePeriod =>
      SamayDurations.auroraDrift + SamayDurations.motionCycleRest;

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => Stack(
                      fit: StackFit.expand,
                      children: [
                        for (var i = 0; i < widget.gradients.length; i++)
                          _buildBlob(i, size),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _buildBlob(int index, Size size) {
    final gradient = widget.gradients[index];
    final base = gradient.radial();
    final radial = RadialGradient(
      center: base.center,
      radius: base.radius,
      colors: [
        for (final color in base.colors)
          color.withValues(alpha: widget.opacity),
      ],
      stops: base.stops,
    );
    final diameter = _blobScale * math.max(size.width, size.height);
    final anchor = _anchors[index % _anchors.length];
    final drift = _driftFor(index);
    return Positioned(
      key: ValueKey('vAuroraBlob$index'),
      left: _left(anchor, size, diameter, drift.dx),
      right: _right(anchor, diameter, drift.dx),
      top: _top(anchor, diameter, drift.dy),
      bottom: _bottom(anchor, diameter, drift.dy),
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: diameter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: radial,
            ),
          ),
        ),
      ),
    );
  }

  /// Per-blob tiny circular orbit: sin/cos of the shared controller value
  /// with a spread phase, so the blobs drift together but out of sync.
  Offset _driftFor(int index) {
    final phase = index * math.pi * 2 / 3;
    return Offset(
      math.sin(2 * math.pi * _controller.value + phase),
      math.cos(2 * math.pi * _controller.value + phase),
    ) * _driftRadius;
  }

  double? _left(Alignment anchor, Size size, double diameter, double dx) {
    switch (anchor) {
      case Alignment.topLeft:
        return -_anchorInset * diameter + dx;
      case Alignment.topRight:
        return null;
      default:
        return (size.width - diameter) / 2 + dx;
    }
  }

  double? _right(Alignment anchor, double diameter, double dx) {
    if (anchor != Alignment.topRight) return null;
    return -_anchorInset * diameter + dx;
  }

  double? _top(Alignment anchor, double diameter, double dy) {
    if (anchor == Alignment.bottomCenter) return null;
    return -_anchorInset * diameter + dy;
  }

  double? _bottom(Alignment anchor, double diameter, double dy) {
    if (anchor != Alignment.bottomCenter) return null;
    return -_anchorInset * diameter + dy;
  }
}
