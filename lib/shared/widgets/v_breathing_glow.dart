import 'dart:async';

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/theme/samay_durations.dart';

/// Disco-glow breathing — DISCO-DESIGN-SYSTEM.md §6.2 (U-18).
///
/// Renders [text] with the canonical §3.4 glow shadow stack (the same stacks
/// as [VGlowText]) and breathes the halo ALPHA between 0.75 and 1.0 of the
/// stack on a `glowBreath` (3000ms) `easeInOut` `alternate` loop — the
/// user's `animation: disco-glow 3s ease-in-out infinite alternate`. Only
/// the shadow alphas move; the glyph fill stays 100% opaque (§7.4), and the
/// α0.75 floor keeps effective contrast ≥ 4.75:1 (§6.2 legibility floor).
///
/// Cycle shape: 1.5s easeInOut up (α0.75→α1.0) + 1.5s easeInOut down
/// (α1.0→α0.75), then [SamayDurations.motionCycleRest] static settle at the
/// low point before the next cycle (period ≈ 3.3s). The motion is a
/// continuous 3s alternate; the brief static pause is deliberate: a hard
/// `AnimationController.repeat()` schedules frames forever, which hangs
/// every `pumpAndSettle`-based widget test that mounts a brand screen
/// (welcome/feed/coming-soon/auth headers) — the same constraint U-06's
/// shimmer dodges by never being settled over. Widget tests land
/// deterministically during the pause, with the controller holding value 0
/// (α0.75).
///
/// Reduced motion (`MediaQuery.disableAnimationsOf(context)`) → static glow:
/// shadows fixed at the full α1.0 canonical stack, no ticker (§6.2/§7.5).
/// Re-enabling animations resumes the breath.
class VBreathingGlow extends StatefulWidget {
  /// The brand title to render (Playfair Display display roles, §3.2).
  final String text;

  /// Base style — typically a §3.3 token (e.g. [AppTypography.displayLarge]
  /// or `Theme.of(context).textTheme.displayMedium` — the theme roles are
  /// nullable).
  final TextStyle? style;

  /// `true` → the 2-layer glow-soft stack (headlines ≥28px);
  /// `false` → the 3-layer glow-strong stack (display titles ≥32px).
  final bool soft;

  /// Halo color — the brand signature [AppColors.glowPink] by default.
  final Color color;

  /// Optional alignment (the parent may already center the text).
  final TextAlign? textAlign;

  const VBreathingGlow({
    super.key,
    required this.text,
    required this.style,
    this.soft = false,
    this.color = AppColors.glowPink,
    this.textAlign,
  });

  @override
  State<VBreathingGlow> createState() => _VBreathingGlowState();
}

class _VBreathingGlowState extends State<VBreathingGlow>
    with SingleTickerProviderStateMixin {
  /// One direction of the alternate — half of the §4.5 `glowBreath` loop.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.glowBreath ~/ 2,
  );

  Timer? _cycleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _cycleTimer?.cancel();
      _cycleTimer = null;
      _controller.stop();
      _controller.value = 1.0; // §6.2: reduced motion → static α1.0 stack
    } else if (_cycleTimer == null) {
      _cycleTimer = Timer.periodic(_cyclePeriod, (_) => _runCycle());
      _runCycle();
    }
  }

  /// Full alternate: up (α0.75→α1.0) then down (α1.0→α0.75); the periodic
  /// timer restarts it after the static settle. The `isAnimating` guard
  /// makes a late timer tick (jank, backgrounded frames) a no-op instead of
  /// a mid-cycle jump.
  void _runCycle() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0).then((_) {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      _controller.reverse();
    });
  }

  Duration get _cyclePeriod =>
      SamayDurations.glowBreath + SamayDurations.motionCycleRest;

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.style?.fontSize ?? 32;
    final base = widget.style ?? const TextStyle();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // §6.2 amplitude: canonical stack × (0.75 → 1.0).
        final breath = 0.75 + 0.25 * _controller.value;
        return Text(
          widget.text,
          textAlign: widget.textAlign,
          style: base.copyWith(shadows: _glowShadows(size, breath)),
        );
      },
    );
  }

  /// The §3.4 canonical stacks (mirror of [VGlowText] /
  /// `AppTypography.fancyTitle`; the parity is pinned by tests) with every
  /// shadow alpha multiplied by [breath] (§6.2 amplitude).
  List<Shadow> _glowShadows(double size, double breath) {
    if (widget.soft) {
      return [
        Shadow(
          color: widget.color.withValues(alpha: 0.6 * breath),
          blurRadius: size * 0.3,
        ),
        Shadow(
          color: widget.color.withValues(alpha: 0.25 * breath),
          blurRadius: size * 0.6,
        ),
      ];
    }
    return [
      Shadow(
        color: widget.color.withValues(alpha: 0.9 * breath),
        blurRadius: size * 0.35,
      ),
      Shadow(
        color: widget.color.withValues(alpha: 0.5 * breath),
        blurRadius: size * 0.7,
      ),
      Shadow(
        color: widget.color.withValues(alpha: 0.25 * breath),
        blurRadius: size * 1.0,
      ),
    ];
  }
}
