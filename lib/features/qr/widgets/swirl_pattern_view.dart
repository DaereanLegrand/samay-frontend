import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/features/qr/logic/swirl_code.dart';

// ===========================================================================
// Animated swirl attendance pattern (Stage 4, 2026-09-08).
//
// The swirl encodes the 24-hex swirl code as a RADIAL-LENGTH ring: 24 angular
// sectors (one per hex digit, most significant first), each holding a bright
// "tick" bar whose length outward from a faint baseline ring encodes the hex
// value — value v => bar reaches (v + 1) of 16 equal steps between the
// baseline ring and the outer ring. Encoding contract for the Stage-5
// camera decoder:
//
//   * centre of the whole constellation is the pattern's centre;
//   * the two faint full circles (baseline + outer) and the oversized origin
//     dot (sector 0's leading edge, cyan) give rotation + scale anchors;
//   * sector i spans 15° starting at `origin + i * 15°` (clockwise);
//   * the bar is drawn on the sector centre line; digit d is recovered by
//     measuring its outer-edge radius from the baseline: nearest of
//     `baseline + (d + 1) * step` — 16 discrete radial steps, each > 4px at
//     display size, so a phone camera resolves it (a plain angular scheme
//     would land at sub-pixel per-state spacing — rejected on purpose).
//   * the whole constellation rotates together (relative geometry — and
//     therefore the code — is rotation-invariant), breathes with a traveling
//     wave, and dim companion dots orbit the ring for the Apple "linking
//     devices" motion feel.
//
// Code regeneration is SEAMLESS: when the 24-hex code changes, each bar
// animates its radial length from the old digit to the new one (short,
// eased), reading as the pattern growing/extending — never a hard swap.
// ===========================================================================

/// Radial encoding steps available between the two anchor rings.
const int swirlRadialSteps = 16;

/// Base bar radial position, as a fraction of the pattern's max radius.
const double swirlBaselineFraction = 0.46;

/// Outer (data-limit) ring, as a fraction of the pattern's max radius.
const double swirlOuterFraction = 0.96;

/// Duration of one full visual motion cycle.
const Duration _motionCycle = Duration(seconds: 12);

/// Duration of the bar-length morph when the code regenerates.
const Duration _morphDuration = Duration(milliseconds: 900);

/// Rotations per motion cycle (integer — the field wraps cleanly).
const double _rotationsPerCycle = 2.0;

/// Traveling-wave periods around the ring per motion cycle.
const double _wavesPerCycle = 2.0;

/// The animated, code-carrying pattern. Sized by the parent (square).
class SwirlPatternView extends StatefulWidget {
  const SwirlPatternView({super.key, required this.code});

  /// The currently displayed 24-hex swirl code. Changes are morphed.
  final String code;

  @override
  State<SwirlPatternView> createState() => _SwirlPatternViewState();
}

class _SwirlPatternViewState extends State<SwirlPatternView>
    with TickerProviderStateMixin {
  /// Continuous motion (rotation + breathing wave). Skipped under reduced
  /// motion (ANIM-OFF convention, 2026-08-14).
  AnimationController? _motion;

  /// One-shot morph between the previous and the current code.
  late final AnimationController _morph;

  List<int> _shown = const [];

  /// The digits the current morph is transitioning AWAY from.
  List<int> _morphFromDigits = const [];

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _shown = _digitsOf(widget.code);
    _morph = AnimationController(
      vsync: this,
      duration: _reduceMotion ? Duration.zero : _morphDuration,
    );
    if (!_reduceMotion) {
      _motion = AnimationController(vsync: this, duration: _motionCycle)
        ..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SwirlPatternView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code == widget.code) return;
    final next = _digitsOf(widget.code);
    if (listEquals(_shown, next)) return;
    _morph.stop();
    _morphFromDigits = _shown;
    _shown = next;
    _morph
      ..reset()
      ..forward(); // zero duration under reduced motion → instant swap
  }

  @override
  void dispose() {
    _motion?.dispose();
    _morph.dispose();
    super.dispose();
  }

  static List<int> _digitsOf(String code) {
    return code
        .split('')
        .map((c) => int.parse(c, radix: 16))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[_morph];
    final motion = _motion;
    if (motion != null) listenables.add(motion);
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final animT = motion?.value ?? 0.0;
        final morphing = !_reduceMotion && _morph.isAnimating;
        // Continuous digits: current value eases from the previous digit while
        // the morph controller runs; idle digits are the plain code values.
        final eased = List<double>.generate(_shown.length, (i) {
          final to = _shown[i].toDouble();
          if (!morphing) return to;
          final from = i < _morphFromDigits.length
              ? _morphFromDigits[i].toDouble()
              : to;
          return from +
              (to - from) * Curves.easeInOutCubic.transform(_morph.value);
        });

        return CustomPaint(
          painter: _SwirlPainter(
            digits: eased,
            animT: animT,
            reduceMotion: _reduceMotion,
          ),
        );
      },
    );
  }
}

/// Paints the rotating, breathing radial-length ring of [digits].
class _SwirlPainter extends CustomPainter {
  const _SwirlPainter({
    required this.digits,
    required this.animT,
    required this.reduceMotion,
  });

  final List<double> digits;
  final double animT;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxR = (size.shortestSide / 2) * 0.92;
    final baselineR = swirlBaselineFraction * maxR;
    final outerR = swirlOuterFraction * maxR;
    final step = (outerR - baselineR) / swirlRadialSteps;

    // Global rotation: the whole field turns together; every dot/bar/ring
    // shares it, so the encoded geometry stays relative (rotation-invariant).
    final rotation = reduceMotion ? 0.0 : animT * 2 * math.pi * _rotationsPerCycle;
    final wave = reduceMotion ? 0.0 : animT * 2 * math.pi * _wavesPerCycle;

    final cell = 2 * math.pi / swirlDigitCount;
    final halfWidth = cell * 0.28;

    // --- Anchor rings (rotation + scale calibration) -----------------------
    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.white.withValues(alpha: 0.10);
    canvas.drawCircle(centre, baselineR, guidePaint);
    canvas.drawCircle(centre, outerR, guidePaint);

    // --- Sector tick bars (the data) ----------------------------------------
    for (var i = 0; i < digits.length; i++) {
      final sectorAngle = rotation + (i + 0.5) * cell;
      final breathe = reduceMotion
          ? 1.0
          : 1.0 + 0.04 * math.sin(wave + i * 0.6);
      final value = digits[i].clamp(0.0, 15.0);
      final innerR = baselineR * 0.98;
      final lengthR = baselineR + step * (1.0 + value);
      final bright = (0.86 + 0.14 * breathe).clamp(0.0, 1.0);

      canvas.drawPath(
        _annularSector(
          centre,
          innerR,
          math.max(lengthR, innerR + step),
          sectorAngle - halfWidth,
          sectorAngle + halfWidth,
        ),
        Paint()..color = AppColors.white.withValues(alpha: bright),
      );

      // Crisp outer edge dot — the measurable radius edge for the decoder.
      canvas.drawCircle(
        _polar(centre, lengthR, sectorAngle),
        math.max(1.6, step * 0.34),
        Paint()..color = AppColors.white,
      );
    }

    // --- Origin marker: sector 0's leading edge (breaks ring symmetry) -----
    canvas.drawCircle(
      _polar(centre, baselineR, rotation),
      math.max(2.4, step * 0.5),
      Paint()..color = AppColors.discoCyan,
    );

    // --- Companion swirl dots (dim, non-encoded, motion only) ---------------
    if (!reduceMotion) {
      final dotPaint = Paint()..color = AppColors.white.withValues(alpha: 0.14);
      for (var k = 0; k < 9; k++) {
        final a = rotation +
            cell * (k + 0.5) +
            animT * 0.9 * 2 * math.pi;
        final r = baselineR +
            (outerR - baselineR) * 0.5 +
            math.sin(animT * 2 * math.pi * 2 + k * 1.9) *
                (outerR - baselineR) *
                0.16;
        canvas.drawCircle(_polar(centre, r, a), step * 0.18, dotPaint);
      }
    }
  }

  /// Point at (angle [a], radius [r]) around [centre].
  static Offset _polar(Offset centre, double r, double a) {
    return centre + Offset(r * math.cos(a), r * math.sin(a));
  }

  /// Filled annular sector between radii [r0]/[r1] and angles [a0]/[a1].
  static Path _annularSector(
    Offset centre,
    double r0,
    double r1,
    double a0,
    double a1,
  ) {
    final path = Path()
      ..moveTo(centre.dx + r0 * math.cos(a0), centre.dy + r0 * math.sin(a0));
    final innerArc = Rect.fromCircle(center: centre, radius: r0);
    path.arcTo(innerArc, a0, a1 - a0, false);
    path.lineTo(
      centre.dx + r1 * math.cos(a1),
      centre.dy + r1 * math.sin(a1),
    );
    final outerArc = Rect.fromCircle(center: centre, radius: r1);
    path.arcTo(outerArc, a1, a0 - a1, true);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_SwirlPainter oldDelegate) =>
      oldDelegate.animT != animT ||
      oldDelegate.reduceMotion != reduceMotion ||
      !listEquals(oldDelegate.digits, digits);
}
