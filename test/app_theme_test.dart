import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samay/features/groups/theme/group_theme_colors.dart';
import 'package:samay/core/services/shards_service.dart' show tierRank;
import 'package:samay/core/theme/app_palette.dart';
import 'package:samay/core/models/group_theme.dart';
import 'package:samay/core/theme/app_theme_presets.dart';
import 'package:samay/features/groups/theme/group_theme_theme.dart';
import 'package:samay/core/theme/themed_data.dart';
import 'package:samay/core/theme/app_theme.dart';

/// The server palette from `240_group_theme.get_group_theme` (pro/vip).
const _palette = <String>[
  '#000000',
  '#1E3A8A',
  '#14532D',
  '#4C1D95',
  '#7C2D12',
  '#0F766E',
  '#3F2D0B',
  '#1E293B',
  '#831843',
  '#164E63',
];

AppPalette _derive(String bg, {String accent = '#FACC15'}) {
  final background = groupThemeColor(bg);
  final accentColor = groupThemeColor(accent);
  // Mirrors `theme_best_foreground` / `theme_best_foreground(accent)`.
  return AppPalette.derive(
    background: background,
    foreground: _bestForeground(background),
    accent: accentColor,
    accentForeground: _bestForeground(accentColor),
  );
}

Color _bestForeground(Color bg) {
  final onBlack = AppPalette.contrastRatio(bg, Colors.black);
  final onWhite = AppPalette.contrastRatio(bg, Colors.white);
  return onBlack >= onWhite ? Colors.black : Colors.white;
}

/// Composite a translucent colour the way the widget paints it.
Color _flat(Color c, Color over) {
  if (c.a >= 1) return c;
  return Color.fromARGB(
    255,
    (c.r * 255 * c.a + (over.r * 255) * (1 - c.a)).round(),
    (c.g * 255 * c.a + (over.g * 255) * (1 - c.a)).round(),
    (c.b * 255 * c.a + (over.b * 255) * (1 - c.a)).round(),
  );
}

double _ratio(Color a, Color b, {Color over = const Color(0xFF000000)}) =>
    AppPalette.contrastRatio(_flat(a, over), _flat(b, over));

void main() {
  group('AppPalette.derive', () {
    test('standard palette matches the design tokens exactly', () {
      expect(AppPalette.standard.background, const Color(0xFF000000));
      expect(AppPalette.standard.surface, const Color(0xFF0A0A0A));
      expect(AppPalette.standard.foreground, const Color(0xFFFFFFFF));
    });

    test('every server palette keeps AA text on every derived surface', () {
      for (final bg in _palette) {
        for (final accent in const [
          '#FFFFFF',
          '#FACC15',
          '#FDE68A',
          '#A7F3D0',
        ]) {
          final p = _derive(bg, accent: accent);
          final label = 'bg=$bg';

          // Primary text on the page and on both raised steps.
          expect(
            _ratio(p.foreground, p.background),
            greaterThanOrEqualTo(4.5),
            reason: '$label foreground on background',
          );
          expect(
            _ratio(p.foreground, p.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$label foreground on surface',
          );
          expect(
            _ratio(p.foreground, p.surfaceAlt),
            greaterThanOrEqualTo(4.5),
            reason: '$label foreground on surfaceAlt',
          );

          // Secondary/label text on the card steps it actually appears on.
          expect(
            _ratio(p.mutedForeground, p.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$label mutedForeground on surface',
          );
          expect(
            _ratio(p.mutedForeground, p.surfaceAlt),
            greaterThanOrEqualTo(4.5),
            reason: '$label mutedForeground on surfaceAlt',
          );

          // Accent pair.
          expect(
            _ratio(p.accentForeground, p.accent),
            greaterThanOrEqualTo(4.5),
            reason: '$label accent=$accent accentForeground on accent',
          );
        }
      }
    });

    test('surface steps are visibly distinct but stay under the text', () {
      for (final bg in _palette) {
        final p = _derive(bg);
        final bgL = AppPalette.relativeLuminance(p.background);
        final surfaceL = AppPalette.relativeLuminance(p.surface);
        final altL = AppPalette.relativeLuminance(p.surfaceAlt);
        final fgL = AppPalette.relativeLuminance(p.foreground);

        // Raised steps move toward the foreground and are ordered.
        expect(surfaceL, greaterThan(bgL), reason: 'bg=$bg surface bumps up');
        expect(altL, greaterThan(surfaceL), reason: 'bg=$bg surfaceAlt bumps');
        // ...but never approach the foreground's luminance.
        expect(altL, lessThan(fgL), reason: 'bg=$bg surfaceAlt stays under fg');

        // The step is perceptible (contrast between steps >= 1.03:1).
        expect(
          _ratio(p.surface, p.background, over: p.background),
          greaterThanOrEqualTo(1.03),
          reason: 'bg=$bg surface is a visible step',
        );
      }
    });

    test('hairline and border are decorative but ordered', () {
      final p = _derive('#1E3A8A');
      final hairline = _ratio(p.hairline, p.surface, over: p.surface);
      final border = _ratio(p.border, p.surface, over: p.surface);
      expect(border, greaterThan(hairline));
      // Border is a control indicator → must hit the 3:1 non-text rule on the
      // card it outlines.
      expect(border, greaterThanOrEqualTo(3.0));
    });

    test('a bright background is auto-clamped dark server-side; derivation '
        'still yields readable text', () {
      // The server clamps; simulate a pathological all-white background to
      // prove the helper degrades instead of producing invisible text.
      final bg = Colors.white;
      final p = AppPalette.derive(
        background: bg,
        foreground: _bestForeground(bg),
        accent: Colors.white,
        accentForeground: _bestForeground(Colors.white),
      );
      expect(_ratio(p.foreground, p.background), greaterThanOrEqualTo(4.5));
      expect(_ratio(p.mutedForeground, p.surface), greaterThanOrEqualTo(4.5));
    });

    test('derivation is deterministic', () {
      final a = _derive('#14532D');
      final b = _derive('#14532D');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('every themed colour is 75% darker than the host pick', () {
      for (final bg in _palette) {
        final p = _derive(bg);
        final raw = groupThemeColor(bg);
        // 75% darker == each channel x 0.25 (rounded).
        expect(
          p.background.r * 255,
          closeTo(raw.r * 255 * 0.25, 1.0),
          reason: 'bg=$bg red channel darkened',
        );
        expect(
          p.background.g * 255,
          closeTo(raw.g * 255 * 0.25, 1.0),
          reason: 'bg=$bg green channel darkened',
        );
        expect(
          p.background.b * 255,
          closeTo(raw.b * 255 * 0.25, 1.0),
          reason: 'bg=$bg blue channel darkened',
        );
        // The accent is darkened too.
        final rawAccent = groupThemeColor('#FACC15');
        expect(p.accent.r * 255, closeTo(rawAccent.r * 255 * 0.25, 1.0));
        expect(p.accent.g * 255, closeTo(rawAccent.g * 255 * 0.25, 1.0));
        expect(p.accent.b * 255, closeTo(rawAccent.b * 255 * 0.25, 1.0));
      }
    });

    test('a white foreground becomes the opposite hue of the background', () {
      // Blue page -> complement is a warm/orange hue.
      final blue = _derive('#1E3A8A');
      expect(
        blue.foreground.r * 255,
        greaterThan(blue.foreground.b * 255),
        reason: 'complement of blue is warm (red > blue)',
      );
      // Green page -> complement is magenta-ish (red and blue > green).
      final green = _derive('#14532D');
      expect(green.foreground.r * 255, greaterThan(green.foreground.g * 255));
      expect(green.foreground.b * 255, greaterThan(green.foreground.g * 255));
      // It is never plain white any more.
      for (final bg in _palette) {
        if (bg == '#000000') continue; // complement of black is white
        final p = _derive(bg);
        expect(p.foreground, isNot(Colors.white), reason: 'bg=$bg foreground');
      }
    });

    test('darken and complement behave as documented', () {
      expect(
        AppPalette.darken(Colors.white, 0.75),
        const Color(0xFF404040),
      );
      expect(
        AppPalette.darken(const Color(0xFF000000), 0.75),
        const Color(0xFF000000),
      );
      expect(
        AppPalette.complement(const Color(0xFF1E3A8A)),
        const Color(0xFFE1C575),
      );
      expect(AppPalette.complement(Colors.white), Colors.black);
      expect(AppPalette.complement(Colors.black), Colors.white);
    });

    test('distinct backgrounds produce distinct palettes', () {
      final a = _derive('#1E3A8A');
      final b = _derive('#7C2D12');
      expect(a, isNot(b));
    });
  });

  group('contrast helpers match the SQL implementation', () {
    test('black/white ratio is 21:1', () {
      final r = AppPalette.contrastRatio(Colors.black, Colors.white);
      expect(r, closeTo(21.0, 0.01));
    });

    test('mid grey (#777777) picks black as the better foreground', () {
      final bg = const Color(0xFF777777);
      final onBlack = AppPalette.contrastRatio(bg, Colors.black);
      final onWhite = AppPalette.contrastRatio(bg, Colors.white);
      // Same ordering the SQL `theme_best_foreground` uses.
      expect(onBlack, greaterThan(onWhite));
      expect(math.max(onBlack, onWhite), greaterThanOrEqualTo(4.5));
    });
  });

  _presets();
  _groupFollowsApp();

  group('themedData', () {
    test('a colourless Material shows the page instead of painting black', () {
      final palette = _derive('#1E3A8A');
      final theme = themedData(SamayTheme.dark, palette);
      // `Chip` wraps itself in a colourless `Material`, which falls back to
      // `canvasColor` — the black-chip defect's root cause.
      expect(theme.canvasColor, const Color(0x00000000));
      expect(theme.scaffoldBackgroundColor, palette.background);
      expect(theme.dividerColor, palette.hairline);
      expect(theme.colorScheme.surface, palette.background);
      expect(theme.colorScheme.onSurface, palette.foreground);
    });

    test(
      'unselected chips resolve transparent, selected use the foreground',
      () {
        final palette = _derive('#1E3A8A');
        final chip = themedData(SamayTheme.dark, palette).chipTheme;
        expect(chip.color!.resolve({}), const Color(0x00000000));
        expect(chip.color!.resolve({WidgetState.selected}), palette.foreground);
        expect(chip.surfaceTintColor, const Color(0x00000000));
      },
    );
  });
}

/// App-wide theme presets + the group↔app inheritance rule.
void _presets() {
  group('AppThemePreset', () {
    test('every preset derives an AA-safe palette', () {
      for (final preset in AppThemePreset.values) {
        final palette = preset.palette;
        expect(
          AppPalette.contrastRatio(palette.foreground, palette.background),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} ink on page',
        );
        expect(
          AppPalette.contrastRatio(
            palette.accentForeground,
            palette.accent,
          ),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} accent pair',
        );
        expect(
          AppPalette.contrastRatio(palette.mutedForeground, palette.surfaceAlt),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} muted ink on the raised step',
        );
      }
    });

    test('classic IS the design tokens, so an unset app is unchanged', () {
      expect(AppThemePreset.classic.palette, AppPalette.standard);
    });

    test('every other preset paints a different page', () {
      for (final preset in AppThemePreset.values) {
        if (preset == AppThemePreset.classic) continue;
        expect(preset.palette.background, isNot(AppPalette.standard.background));
      }
    });

    test('tiers gate as free < pro < vip', () {
      bool unlocked(AppThemePreset p, String tier) =>
          tierRank(p.tierRequirement) <= tierRank(tier);
      expect(unlocked(AppThemePreset.classic, 'free'), isTrue);
      expect(unlocked(AppThemePreset.midnight, 'free'), isTrue);
      expect(unlocked(AppThemePreset.violet, 'free'), isFalse);
      expect(unlocked(AppThemePreset.violet, 'pro'), isTrue);
      expect(unlocked(AppThemePreset.teal, 'pro'), isFalse);
      expect(unlocked(AppThemePreset.teal, 'vip'), isTrue);
    });

    test('tryParse round-trips every id and rejects junk', () {
      for (final preset in AppThemePreset.values) {
        expect(AppThemePreset.tryParse(preset.id), preset);
      }
      expect(AppThemePreset.tryParse(null), isNull);
      expect(AppThemePreset.tryParse('nope'), isNull);
    });
  });
}

/// The owner rule: a group on the server default follows the app theme.
void _groupFollowsApp() {
  group('groupSurfacePalette', () {
    GroupTheme theme(String background) => GroupTheme(
      groupId: 'g',
      controlMode: 'everyone',
      backgroundColor: background,
      accentColor: '#FFFFFF',
      foregroundColor: '#FFFFFF',
      accentForegroundColor: '#000000',
    );

    test('a default group inherits the app palette', () {
      final app = AppThemePreset.midnight.palette;
      expect(
        groupSurfacePalette(theme('#000000'), appPalette: app),
        app,
      );
    });

    test('a custom group overrides the app palette', () {
      final app = AppThemePreset.midnight.palette;
      final palette = groupSurfacePalette(
        theme('#4C1D95'),
        appPalette: app,
      );
      expect(palette, isNot(app));
      expect(palette.background, isNot(app.background));
    });

    test('default + classic app collapses onto the design tokens', () {
      expect(
        groupSurfacePalette(
          theme('#000000'),
          appPalette: AppPalette.standard,
        ),
        AppPalette.standard,
      );
    });

    test('background comparison is case-insensitive', () {
      expect(isDefaultGroupTheme(theme('#000000')), isTrue);
      expect(isDefaultGroupTheme(theme('#1E3A8A')), isFalse);
    });
  });
}
