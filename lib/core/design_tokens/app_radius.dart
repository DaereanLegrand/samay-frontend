import 'package:flutter/material.dart';

/// Samay corner-radius tokens — **SHARP** per the MVP spec ("no rounded
/// pastel") and DESIGN.md §4.2.
///
/// Every UI component radius is `0`: buttons, cards, chips, inputs, dialogs,
/// sheets, badges. The `#333333` hairline borders carry the geometry.
/// Documented exceptions (only these): avatars `full` (circle), live/online
/// dots (circle), progress spinners (natively round), the minigame card deck /
/// 2 Lies cards (`card`), and the rules bottom sheet, whose top corners use
/// `card` (see `minigame_rules_sheet.dart`).
abstract final class AppRadius {
  /// Sharp corners — the Samay default for every component.
  static const double none = 0;

  /// Alias making the intent explicit at call sites.
  static const double radiusZero = none;

  // Small nominal radii. Most surfaces stay sharp (`none`); these are used by
  // a handful of small insets — the groups-tab dissolve mask (`md`), the
  // leaderboard answer rail (`xs`), the 2 Lies cards (`sm`) and the
  // local-lobby charades deck card (`lg`).
  static const double xs = 2;

  static const double sm = 4;

  static const double md = 8;

  static const double lg = 12;

  /// Circles only — avatars, live/online dots (the only non-sharp elements,
  /// per §4.2 exceptions). Never for boxes.
  static const double full = 999;

  /// The sanctioned rounded-surface exception (DESIGN.md §3, user directives
  /// 2026-09-21 / 2026-09-22): the Games-tab card deck renders its cards as a
  /// fanned hand, and a card reads as a *card* only with a corner radius. The
  /// 2 Lies statement cards use the same radius so an input reads as a card.
  /// Scoped to minigame cards (`games_deck.dart`, the 2 Lies editor) — not a
  /// general licence for rounded boxes.
  static const double card = 16;

  /// Convenience for `RoundedRectangleBorder(borderRadius:...)`.
  static const BorderRadius sharp = BorderRadius.zero;

  /// Circle avatar geometry (radius value, not diameter — matches
  /// `CircleAvatar.radius` semantics).
  static const double avatarCircle = full;
}
