import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/features/groups/theme/group_theme_colors.dart';
import 'package:samay/features/groups/theme/group_theme_palette.dart';
import 'package:samay/features/groups/theme/group_theme_scope.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_chip.dart';

/// Guards the "no black boxes on a themed group surface" rule: every shared
/// widget that paints a fill must switch to the derived scale inside a
/// [GroupThemeScope], and must be untouched outside one.
void main() {
  // A pale background forces a BLACK foreground, so the assertions below can
  // prove the widgets stop using the hardcoded white token.
  final palette = GroupThemePalette.derive(
    background: groupThemeColor('#E8D5A3'),
    foreground: Colors.black,
    accent: groupThemeColor('#FACC15'),
    accentForeground: Colors.black,
  );

  Widget host(Widget child, {bool themed = true}) {
    final wrapped = themed
        ? GroupThemeScope(palette: palette, child: child)
        : child;
    return MaterialApp(
      home: Scaffold(backgroundColor: Colors.black, body: wrapped),
    );
  }

  Color cardColor(WidgetTester tester) {
    final box = tester.widget<Container>(
      find
          .descendant(of: find.byType(VCard), matching: find.byType(Container))
          .first,
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  group('VCard', () {
    testWidgets('themed card uses the derived surface, never black', (
      tester,
    ) async {
      await tester.pumpWidget(host(const VCard(child: Text('x'))));
      final color = cardColor(tester);
      expect(color, palette.surface);
      expect(color, isNot(AppColors.surface));
      expect(color, isNot(const Color(0xFF000000)));
    });

    testWidgets('raised card uses the surfaceAlt step', (tester) async {
      await tester.pumpWidget(
        host(const VCard(raised: true, child: Text('x'))),
      );
      expect(cardColor(tester), palette.surfaceAlt);
    });

    testWidgets('un-themed card keeps the design-token fill', (tester) async {
      await tester.pumpWidget(
        host(const VCard(child: Text('x')), themed: false),
      );
      expect(cardColor(tester), AppColors.surface);
    });
  });

  group('VBadge', () {
    testWidgets('the default badge is a theme shade, not #333', (tester) async {
      await tester.pumpWidget(host(const VBadge(label: 'host')));
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(VBadge),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((box.decoration! as BoxDecoration).color, palette.surfaceAlt);
    });

    testWidgets('un-themed badge keeps #333', (tester) async {
      await tester.pumpWidget(host(const VBadge(label: 'host'), themed: false));
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(VBadge),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((box.decoration! as BoxDecoration).color, AppColors.border);
    });

    testWidgets('badge text meets AA on its themed fill', (tester) async {
      await tester.pumpWidget(host(const VBadge(label: 'member')));
      final text = tester.widget<Text>(find.text('MEMBER'));
      final fill = palette.surfaceAlt;
      expect(
        GroupThemePalette.contrastRatio(text.style!.color!, fill),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('VChip', () {
    testWidgets('unselected chip ink is the theme foreground', (tester) async {
      await tester.pumpWidget(host(VChip(label: 'Directa', onSelected: () {})));
      final chip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect((chip.side as BorderSide).color, palette.foreground);
      expect((chip.side as BorderSide).color, isNot(AppColors.white));
    });

    testWidgets('no Material elevation tint (which reads as a black box)', (
      tester,
    ) async {
      await tester.pumpWidget(host(const VChip(label: 'Grupo')));
      final chip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(chip.elevation, 0);
      expect(chip.surfaceTintColor, AppColors.transparent);
      expect(chip.shadowColor, AppColors.transparent);
    });

    testWidgets('un-themed chip keeps white ink', (tester) async {
      await tester.pumpWidget(
        host(const VChip(label: 'Directa'), themed: false),
      );
      final chip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect((chip.side as BorderSide).color, AppColors.white);
    });
  });

  group('VButton', () {
    testWidgets('dark button fill is the derived surfaceAlt when themed', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(VButton.dark(label: 'Crear partida', onPressed: () {})),
      );
      final button = tester.widget<TextButton>(find.byType(TextButton));
      final bg = button.style!.backgroundColor!.resolve({});
      expect(bg, palette.surfaceAlt);
      expect(bg, isNot(AppColors.surfaceAlt));
    });

    testWidgets('un-themed dark button stays token black + white text', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          VButton.dark(label: 'Crear partida', onPressed: () {}),
          themed: false,
        ),
      );
      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.style!.backgroundColor!.resolve({}), AppColors.surfaceAlt);
      expect(button.style!.foregroundColor!.resolve({}), AppColors.white);
    });
  });

  group('ProfileAvatar', () {
    testWidgets('avatar ring and fill follow the theme', (tester) async {
      await tester.pumpWidget(
        host(const ProfileAvatar(initials: 'AB', size: 40)),
      );
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ProfileAvatar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, palette.surfaceAlt);
      expect((decoration.border! as Border).top.color, palette.border);
    });
  });
}
