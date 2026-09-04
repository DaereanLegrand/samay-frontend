import 'package:flutter/material.dart';

/// Samay motion durations — DESIGN.md §4.5 (the source of
/// truth, owned by U-18). Screens and shared widgets must take their
/// durations from here; never hardcode ms values in features.
class SamayDurations {
  SamayDurations._();

  /// Micro-interactions: button press, chip select, icon swaps, focus states.
  static const fast = Duration(milliseconds: 150);

  /// Page transitions, dialog/sheet open, snackbar.
  static const standard = Duration(milliseconds: 250);

  /// Hero/display fade-in.
  static const slow = Duration(milliseconds: 500);

  /// Default curve for all transitions — §6.1 "easeOutCubic".
  static const defaultCurve = Curves.easeOutCubic;

  /// Skeleton shimmer sweep (§5.8/§6.3 — promoted from U-06's local
  /// `_shimmerSweep` const into the §4.5 token).
  static const shimmer = Duration(milliseconds: 1200);

  /// Live-dot α pulse, one-directional ramp (§6.3: "1.5s α pulse 0.6→1.0").
  static const liveDotPulse = Duration(milliseconds: 1500);

  /// Static settle between pulse cycles. A hard `repeat()` schedules
  /// frames forever, hanging every `pumpAndSettle`-based widget test over
  /// the affected screens — the pause lets the animation run a continuous
  /// `liveDotPulse` alternate and then rest so tests land
  /// deterministically (see `VStatusDot`).
  static const motionCycleRest = Duration(milliseconds: 300);

  /// Slow periodic drift period for ambient light-motion accents. Kept as a
  /// stable duration token; its value is locked by `samay_durations_test`.
  static const auroraDrift = Duration(milliseconds: 10000);

  /// Minigame reaction-burst pop (tap feedback): a duplicate of the tapped
  /// emoji scales up in its own deck slot while its opacity ramps, then
  /// vanishes. One-shot, ~700 ms.
  static const reactionBurst = Duration(milliseconds: 700);

  /// [VThinkingDots] per-dot pulse period (up-down alternate, staggered).
  static const thinkingDot = Duration(milliseconds: 900);

  /// Minigame reaction rise (realtime echo): an incoming reaction emoji
  /// floats bottom → top across the by_turns answer card — fully hidden
  /// below the card's bottom edge to fully hidden above its top edge,
  /// clipped to the card. One-shot, ~1.6 s (user spec).
  static const reactionFloat = Duration(milliseconds: 1600);

  /// Minigame reaction-tap cooldown: the minimum gap between two reaction
  /// taps on ONE device. A tap within this window of the previous is
  /// swallowed (no RPC, no rise) — the per-device spam guard for "same emoji
  /// can be re-tapped" (deliberate taps after the window each animate).
  static const reactionTapCooldown = Duration(milliseconds: 350);
}
