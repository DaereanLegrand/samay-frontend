import 'package:flutter/material.dart';

/// Samay corner-radius tokens — **SHARP** per the MVP spec ("no rounded
/// pastel") and DESIGN.md §4.2.
///
/// Every UI component radius is `0`: buttons, cards, chips, inputs, dialogs,
/// sheets, badges. The `#333333` hairline borders carry the geometry.
/// Documented exceptions (only these): avatars `full` (circle), live/online
/// dots (circle), progress spinners (natively round). `BottomSheet` top
/// corners stay 0 (flush).
abstract final class AppRadius {
  /// Sharp corners — the Samay default for every component.
  static const double none = 0;

  /// Alias making the intent explicit at call sites.
  static const double radiusZero = none;

  // Nominal scale values exist for parity with the design-doc table but are
  // **unused** by design: the doc marks xs/sm/md/lg as `(unused)`.
  /// Unused — sharp design does not use small radii.
  static const double xs = 2;

  /// Unused — sharp design does not use small radii.
  static const double sm = 4;

  /// Unused — sharp design does not use small radii.
  static const double md = 8;

  /// Unused — sharp design does not use small radii.
  static const double lg = 12;

  /// Circles only — avatars, live/online dots (the only non-sharp elements,
  /// per §4.2 exceptions). Never for boxes.
  static const double full = 999;

  /// The sanctioned rounded-surface exception (DESIGN.md §3, user directive
  /// 2026-09-21): the Games-tab card deck renders its cards as a fanned
  /// hand, and a card reads as a *card* only with a corner radius. Scoped to
  /// the minigame deck (`games_deck.dart`) — not a general licence for
  /// rounded boxes.
  static const double card = 16;

  /// Convenience for `RoundedRectangleBorder(borderRadius:...)`.
  static const BorderRadius sharp = BorderRadius.zero;

  /// Circle avatar geometry (radius value, not diameter — matches
  /// `CircleAvatar.radius` semantics).
  static const double avatarCircle = full;
}
