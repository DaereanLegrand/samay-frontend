import 'package:flutter/material.dart';
import 'package:samay/core/theme/app_palette.dart';

/// The app-wide theme presets the user can pick from (Settings → Apariencia).
///
/// Each preset is a host colour; the painted scale comes from
/// [AppPalette.derive] — the same darkening + complementary-ink math the group
/// theme uses — so every preset is WCAG-safe by construction and the app reads
/// as one tonal family.
///
/// The [classic] preset is the app's design tokens exactly: it is the default,
/// it is free, and it is what a build with no stored choice paints.
///
/// [tierRequirement] is the paywall seam: `free` | `pro` | `vip`, compared with
/// [tierRank]. The gate is enforced client-side today (the store/backend owns
/// the tier); when the paywall ships the same field tells the UI what to sell.
enum AppThemePreset {
  classic(
    id: 'classic',
    labelKey: 'appThemeClassic',
    background: '#000000',
    accent: '#FFFFFF',
    tierRequirement: 'free',
  ),
  midnight(
    id: 'midnight',
    labelKey: 'appThemeMidnight',
    background: '#1E3A8A',
    accent: '#FACC15',
    tierRequirement: 'free',
  ),
  forest(
    id: 'forest',
    labelKey: 'appThemeForest',
    background: '#14532D',
    accent: '#FDE68A',
    tierRequirement: 'free',
  ),
  violet(
    id: 'violet',
    labelKey: 'appThemeViolet',
    background: '#4C1D95',
    accent: '#FDE047',
    tierRequirement: 'pro',
  ),
  ember(
    id: 'ember',
    labelKey: 'appThemeEmber',
    background: '#7C2D12',
    accent: '#BAE6FD',
    tierRequirement: 'pro',
  ),
  teal(
    id: 'teal',
    labelKey: 'appThemeTeal',
    background: '#0F766E',
    accent: '#FBCFE8',
    tierRequirement: 'vip',
  ),
  rose(
    id: 'rose',
    labelKey: 'appThemeRose',
    background: '#831843',
    accent: '#A7F3D0',
    tierRequirement: 'vip',
  );

  const AppThemePreset({
    required this.id,
    required this.labelKey,
    required this.background,
    required this.accent,
    required this.tierRequirement,
  });

  /// Stable identifier persisted locally (`theme.palette`).
  final String id;

  /// l10n getter name on `AppLocalizations` (resolved by the picker UI).
  final String labelKey;

  /// The host pick; the painted page is this darkened 75%.
  final String background;

  /// Accent pick; painted darkened with its complementary ink.
  final String accent;

  /// Minimum tier that may select this preset (`free` | `pro` | `vip`).
  final String tierRequirement;

  /// The palette this preset paints. [classic] is the design tokens verbatim so
  /// an unthemed app is byte-identical to the old build.
  AppPalette get palette => this == AppThemePreset.classic
      ? AppPalette.standard
      : AppPalette.derive(
          background: parseHex(background),
          foreground: bestForeground(parseHex(background)),
          accent: parseHex(accent),
          accentForeground: bestForeground(parseHex(accent)),
        );

  /// A preview swatch: the painted page.
  Color get paintedBackground => palette.background;

  /// A preview swatch: the painted ink.
  Color get paintedForeground => palette.foreground;

  static AppThemePreset? tryParse(String? id) {
    for (final preset in values) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}

/// Parses a `#RRGGBB` colour used by the presets. Falls back to black.
Color parseHex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null) return Colors.black;
  return Color(0xFF000000 | value);
}

/// Whichever of black/white contrasts more with [bg] — mirrors the server's
/// `theme_best_foreground`.
Color bestForeground(Color bg) =>
    AppPalette.contrastRatio(bg, Colors.black) >=
        AppPalette.contrastRatio(bg, Colors.white)
    ? Colors.black
    : Colors.white;
