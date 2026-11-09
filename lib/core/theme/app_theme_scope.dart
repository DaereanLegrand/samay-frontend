import 'package:flutter/widgets.dart';
import 'package:samay/core/theme/app_palette.dart';

/// Ambient palette for a themed screen subtree.
///
/// Two producers mount it:
///
/// * the **app-wide theme** (Settings → Apariencia, paywalled) wraps the whole
///   app, so every screen paints the user's chosen palette;
/// * a **group theme** wraps just that group's surfaces (chat, members,
///   detail, minigames) and overrides the app palette inside.
///
/// Shared widgets read [paletteOf] and fall back to [standardPalette] — the
/// exact design tokens — when no scope exists, so a build with no theme set
/// renders byte-for-byte as before.
class AppThemeScope extends InheritedWidget {
  const AppThemeScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final AppPalette palette;

  /// The standard (un-themed) palette — the app's design tokens.
  static const AppPalette standardPalette = AppPalette.standard;

  /// The palette of the nearest themed ancestor, or [standardPalette] outside
  /// a themed surface.
  static AppPalette paletteOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    return scope?.palette ?? standardPalette;
  }

  /// True when [context] sits inside ANY theme scope whose palette differs from
  /// the design tokens. Use this instead of comparing references: a themed app
  /// supplies a computed palette, and a group inheriting the app palette must
  /// still count as themed.
  static bool isThemed(BuildContext context) =>
      paletteOf(context) != standardPalette;

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) =>
      oldWidget.palette != palette;
}
