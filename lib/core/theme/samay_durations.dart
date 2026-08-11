import 'package:flutter/material.dart';

/// Samay motion durations — DISCO-DESIGN-SYSTEM.md §4.5 (the source of
/// truth, owned by U-18). Screens and shared widgets must take their
/// durations from here; never hardcode ms values in features.
class SamayDurations {
  SamayDurations._();

  /// Micro-interactions: button press, chip select, icon swaps, focus states.
  static const fast = Duration(milliseconds: 150);

  /// Page transitions, dialog/sheet open, snackbar.
  static const standard = Duration(milliseconds: 250);

  /// Hero/display fade-in, glow settle.
  static const slow = Duration(milliseconds: 500);

  /// Default curve for all transitions — §6.1 "easeOutCubic".
  static const defaultCurve = Curves.easeOutCubic;

  /// Disco-glow breathing loop (§6.2): the glow alternates α0.75→α1.0 over
  /// this period. [VBreathingGlow] runs it as a 1.5s up + 1.5s down
  /// `easeInOut` alternate (see the widget's cycle note).
  static const glowBreath = Duration(milliseconds: 3000);

  /// Skeleton shimmer sweep (§5.8/§6.3 — promoted from U-06's local
  /// `_shimmerSweep` const into the §4.5 token).
  static const shimmer = Duration(milliseconds: 1200);

  /// Live-dot α pulse, one-directional ramp (§6.3: "1.5s α pulse 0.6→1.0").
  static const liveDotPulse = Duration(milliseconds: 1500);

  /// U-18 engine: static settle between glow/pulse cycles. A hard
  /// `repeat()` schedules frames forever, hanging every `pumpAndSettle`-
  /// based widget test over the affected screens — the pause lets the
  /// animation run a continuous `glowBreath`/`liveDotPulse` alternate and
  /// then rest so tests land deterministically (see `VBreathingGlow`).
  static const motionCycleRest = Duration(milliseconds: 300);
}
