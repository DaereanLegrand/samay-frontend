import 'package:flutter/material.dart';
import 'package:samay/core/models/group_theme.dart';
import 'package:samay/core/theme/app_palette.dart';

/// Parses a server `#RRGGBB` theme colour. Falls back to black on malformed
/// input (the server always returns a valid hex).
Color groupThemeColor(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null) return Colors.black;
  return Color(0xFF000000 | value);
}

/// Builds the full derived scale from a server [GroupTheme] payload.
AppPalette groupThemePaletteOf(GroupTheme theme) =>
    AppPalette.derive(
      background: groupThemeColor(theme.backgroundColor),
      foreground: groupThemeColor(theme.foregroundColor),
      accent: groupThemeColor(theme.accentColor),
      accentForeground: groupThemeColor(theme.accentForegroundColor),
    );
