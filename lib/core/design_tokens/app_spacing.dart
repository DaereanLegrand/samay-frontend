import 'package:flutter/widgets.dart';

/// Samay spacing tokens — 8-step scale + semantic aliases
/// (DESIGN.md §4.1, owned by U-03 for finalization).
///
/// Values are logical pixels. Screens and widgets must reference these
/// tokens instead of ad-hoc literals (finding UI-01 / M-25).
abstract final class AppSpacing {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // ── Semantic aliases (§4.1 table) ─────────────────────────────────────────

  /// Horizontal page padding (matches current screens).
  static const double screenHorizontal = xl;

  /// Vertical page padding.
  static const double screenVertical = xl;

  /// `VCard` inner padding (matches `v_card.dart`).
  static const double cardPadding = lg;

  /// `VButton` padding.
  static const double buttonPadding = lg;

  /// `VInput` padding.
  static const double inputPadding = lg;

  /// Gap between list items.
  static const double listGap = sm;

  /// Gap between page sections.
  static const double sectionGap = xl;

  /// Standard avatar diameter.
  static const double avatar = 40;

  /// Large avatar diameter (profile hero).
  static const double avatarLarge = 80;

  /// Responsive spacing (finding UI-09 / §7.3): scales [value] by the
  /// `MediaQuery` text scaler so layout grows with user text settings.
  static double scale(BuildContext context, double value) {
    return value * MediaQuery.textScalerOf(context).scale(1);
  }
}
