import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samay/features/groups/theme/group_theme_colors.dart';
import 'package:samay/features/groups/theme/group_theme_palette.dart';
import 'package:samay/features/groups/theme/group_theme_scope.dart';

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

GroupThemePalette _derive(String bg, {String accent = '#FACC15'}) {
  final background = groupThemeColor(bg);
  final accentColor = groupThemeColor(accent);
  // Mirrors `theme_best_foreground` / `theme_best_foreground(accent)`.
  return GroupThemePalette.derive(
    background: background,
    foreground: _bestForeground(background),
    accent: accentColor,
    accentForeground: _bestForeground(accentColor),
  );
}

Color _bestForeground(Color bg) {
  final onBlack = GroupThemePalette.contrastRatio(bg, Colors.black);
  final onWhite = GroupThemePalette.contrastRatio(bg, Colors.white);
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
    GroupThemePalette.contrastRatio(_flat(a, over), _flat(b, over));

void main() {
  group('GroupThemePalette.derive', () {
    test('standard palette matches the design tokens exactly', () {
      expect(GroupThemePalette.standard.background, const Color(0xFF000000));
      expect(GroupThemePalette.standard.surface, const Color(0xFF0A0A0A));
      expect(GroupThemePalette.standard.foreground, const Color(0xFFFFFFFF));
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
        final bgL = GroupThemePalette.relativeLuminance(p.background);
        final surfaceL = GroupThemePalette.relativeLuminance(p.surface);
        final altL = GroupThemePalette.relativeLuminance(p.surfaceAlt);
        final fgL = GroupThemePalette.relativeLuminance(p.foreground);

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
      final p = GroupThemePalette.derive(
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
        expect(p.background.r * 255, closeTo(raw.r * 255 * 0.25, 1.0),
            reason: 'bg=$bg red channel darkened');
        expect(p.background.g * 255, closeTo(raw.g * 255 * 0.25, 1.0),
            reason: 'bg=$bg green channel darkened');
        expect(p.background.b * 255, closeTo(raw.b * 255 * 0.25, 1.0),
            reason: 'bg=$bg blue channel darkened');
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
      expect(blue.foreground.r * 255, greaterThan(blue.foreground.b * 255),
          reason: 'complement of blue is warm (red > blue)');
      // Green page -> complement is magenta-ish (red and blue > green).
      final green = _derive('#14532D');
      expect(green.foreground.r * 255,
          greaterThan(green.foreground.g * 255));
      expect(green.foreground.b * 255,
          greaterThan(green.foreground.g * 255));
      // It is never plain white any more.
      for (final bg in _palette) {
        if (bg == '#000000') continue; // complement of black is white
        final p = _derive(bg);
        expect(p.foreground, isNot(Colors.white), reason: 'bg=$bg foreground');
      }
    });

    test('darken and complement behave as documented', () {
      expect(GroupThemePalette.darken(Colors.white, 0.75),
          const Color(0xFF404040));
      expect(GroupThemePalette.darken(const Color(0xFF000000), 0.75),
          const Color(0xFF000000));
      expect(GroupThemePalette.complement(const Color(0xFF1E3A8A)),
          const Color(0xFFE1C575));
      expect(GroupThemePalette.complement(Colors.white), Colors.black);
      expect(GroupThemePalette.complement(Colors.black), Colors.white);
    });

    test('distinct backgrounds produce distinct palettes', () {
      final a = _derive('#1E3A8A');
      final b = _derive('#7C2D12');
      expect(a, isNot(b));
    });
  });

  group('GroupThemeScope fallbacks', () {
    testWidgets('a widget outside a scope gets the standard palette', (
      tester,
    ) async {
      late GroupThemePalette seen;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              seen = GroupThemeScope.paletteOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, GroupThemePalette.standard);
      expect(seen.surface, const Color(0xFF0A0A0A));
    });

    testWidgets('a widget inside a scope gets the derived palette', (
      tester,
    ) async {
      final palette = _derive('#1E3A8A');
      late GroupThemePalette seen;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GroupThemeScope(
            palette: palette,
            child: Builder(
              builder: (context) {
                seen = GroupThemeScope.paletteOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen, palette);
      expect(seen.background, isNot(const Color(0xFF1E3A8A)));
    });
  });

  group('contrast helpers match the SQL implementation', () {
    test('black/white ratio is 21:1', () {
      final r = GroupThemePalette.contrastRatio(Colors.black, Colors.white);
      expect(r, closeTo(21.0, 0.01));
    });

    test('mid grey (#777777) picks black as the better foreground', () {
      final bg = const Color(0xFF777777);
      final onBlack = GroupThemePalette.contrastRatio(bg, Colors.black);
      final onWhite = GroupThemePalette.contrastRatio(bg, Colors.white);
      // Same ordering the SQL `theme_best_foreground` uses.
      expect(onBlack, greaterThan(onWhite));
      expect(math.max(onBlack, onWhite), greaterThanOrEqualTo(4.5));
    });
  });
}
