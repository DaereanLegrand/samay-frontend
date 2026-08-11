import 'dart:async';

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/theme/samay_durations.dart';

/// Live/online presence dot with the §6.3 α pulse (U-18).
///
/// The §5.5 dot — `discoCyan` 8px circle (13.65:1 — U-10's friends list) —
/// plus the doc's pulse: the dot α oscillates 0.6 → 1.0 on a
/// `liveDotPulse` (1.5s) easeInOut ramp (1.5s up + 1.5s down +
/// [SamayDurations.motionCycleRest] static settle — the same idle-safe
/// cycle as [VBreathingGlow], so `pumpAndSettle`-based widget tests over
/// the friends screens land during the pause).
///
/// Reduced motion (`MediaQuery.disableAnimationsOf(context)`) → static dot
/// at full α1.0, no ticker (§6.3 "disabled under reduced motion" / §7.5).
class VStatusDot extends StatefulWidget {
  /// Dot diameter — §5.5 online dot = 8px.
  final double size;

  /// Dot color — the `statusOnline` (discoCyan) alias by default (§2.3).
  final Color color;

  const VStatusDot({
    super.key,
    this.size = 8,
    this.color = AppColors.statusOnline,
  });

  @override
  State<VStatusDot> createState() => _VStatusDotState();
}

class _VStatusDotState extends State<VStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.liveDotPulse,
  );

  late final Animation<double> _opacity = Tween<double>(begin: 0.6, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  Timer? _pulseTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
      _controller.stop();
      _controller.value = 1.0; // §6.3: reduced motion → static full α
    } else if (_pulseTimer == null) {
      _pulseTimer = Timer.periodic(_cyclePeriod, (_) => _runCycle());
      _runCycle();
    }
  }

  /// One pulse: up (α0.6→α1.0) then down (α1.0→α0.6); the periodic timer
  /// restarts it after the static settle. The `isAnimating` guard makes a
  /// late timer tick (jank, backgrounded frames) a no-op instead of a
  /// mid-cycle jump.
  void _runCycle() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0).then((_) {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      _controller.reverse();
    });
  }

  /// Full alternate (1.5s up + 1.5s down) + the static settle.
  Duration get _cyclePeriod =>
      SamayDurations.liveDotPulse * 2 + SamayDurations.motionCycleRest;

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Icon(Icons.circle, size: widget.size, color: widget.color),
    );
  }
}
