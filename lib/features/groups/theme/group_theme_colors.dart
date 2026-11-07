import 'package:flutter/material.dart';

/// Parses a server `#RRGGBB` theme colour. Falls back to black on malformed
/// input (the server always returns a valid hex).
Color groupThemeColor(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null) return Colors.black;
  return Color(0xFF000000 | value);
}
