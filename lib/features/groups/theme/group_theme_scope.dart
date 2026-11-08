import 'package:flutter/widgets.dart';
import 'package:samay/features/groups/theme/group_theme_palette.dart';

/// Ambient group theme for a themed screen subtree.
///
/// Wrap the body of the surfaces the owner decisions name — group chat, the
/// member list and group minigames — with this scope. Shared widgets
/// ([VCard], chat bubbles, dividers) read [paletteOf] and fall back to the
/// standard black palette when no group theme is in scope, so every other
/// screen renders exactly as before.
class GroupThemeScope extends InheritedWidget {
  const GroupThemeScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final GroupThemePalette palette;

  /// The standard (un-themed) palette — the app's design tokens.
  static const GroupThemePalette standardPalette = GroupThemePalette.standard;

  /// The palette of the nearest themed ancestor, or [standardPalette] outside
  /// a themed group surface.
  static GroupThemePalette paletteOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GroupThemeScope>();
    return scope?.palette ?? standardPalette;
  }

  @override
  bool updateShouldNotify(GroupThemeScope oldWidget) =>
      oldWidget.palette != palette;
}
