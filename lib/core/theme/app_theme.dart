import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

/// Samay disco theme — phase 1 (I-17) rebuilt on the I-16 design tokens.
///
/// Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` (D-11, §1–§4). Palette and
/// ThemeExtension live in `lib/core/design_tokens/app_colors.dart`
/// ([AppColors] + [SamayThemeExtension]) — the single source for
/// U-01..U-05. This file only composes them into a `ThemeData`.
class SamayTheme {
  SamayTheme._();

  /// Signature glow stacks (design doc §3.4): blur radii are `em`-relative —
  /// computed from the style's fontSize like the CSS source
  /// (`text-shadow: 0 0 0.35em/0.7em/1em var(--pink)`).
  ///
  /// [soft] selects the 2-layer glow-soft stack (headlines ≥28px) instead of
  /// the 3-layer glow-strong stack (display titles ≥32px). The glyph fill is
  /// left untouched (full opacity) — the halo is strictly behind the text
  /// (§7.4 legibility contract).
  static TextStyle glowTitleStyle(TextStyle style, {bool soft = false}) {
    final size = style.fontSize ?? 32;
    final glowPink = AppColors.glowPink;
    if (soft) {
      return style.copyWith(
        shadows: [
          Shadow(
            color: glowPink.withValues(alpha: 0.6),
            blurRadius: size * 0.3,
          ),
          Shadow(
            color: glowPink.withValues(alpha: 0.25),
            blurRadius: size * 0.6,
          ),
        ],
      );
    }
    return style.copyWith(
      shadows: [
        Shadow(
          color: glowPink.withValues(alpha: 0.9),
          blurRadius: size * 0.35,
        ),
        Shadow(
          color: glowPink.withValues(alpha: 0.5),
          blurRadius: size * 0.7,
        ),
        Shadow(
          color: glowPink.withValues(alpha: 0.25),
          blurRadius: size * 1.0,
        ),
      ],
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.discoBlack,
      primaryColor: AppColors.white,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.white,
        onPrimary: AppColors.discoBlack,
        secondary: AppColors.white,
        onSecondary: AppColors.discoBlack,
        surface: AppColors.discoBlack,
        onSurface: AppColors.white,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.discoBlack,
        foregroundColor: AppColors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.discoBlack,
        selectedItemColor: AppColors.white,
        // Design doc §2.1/§2.4: `muted #666666` is the unselected-nav-icon
        // color (3.66:1 ≥ the 3:1 non-text rule).
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: false,
        showSelectedLabels: false,
      ),
      extensions: const [SamayThemeExtension.dark],
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
    );
  }

  /// Design doc §3.3 type scale. Playfair Display italic 700 for display
  /// roles (glow baked in); Inter for everything else. Body/UI voices stay
  /// light per the MVP spec.
  static TextTheme _textTheme(TextTheme base) {
    const playfair = 'Playfair Display';
    const inter = 'Inter';

    return base.copyWith(
      displayLarge: glowTitleStyle(
        const TextStyle(
          fontFamily: playfair,
          fontSize: 64,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.9,
          height: 1.0,
        ),
      ),
      displayMedium: glowTitleStyle(
        const TextStyle(
          fontFamily: playfair,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.2,
          height: 1.0,
        ),
      ),
      displaySmall: glowTitleStyle(
        const TextStyle(
          fontFamily: playfair,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.0,
          height: 1.05,
        ),
      ),
      headlineLarge: glowTitleStyle(
        const TextStyle(
          fontFamily: playfair,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        soft: true,
      ),
      headlineMedium: const TextStyle(
        fontFamily: inter,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      headlineSmall: const TextStyle(
        fontFamily: inter,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      titleLarge: const TextStyle(
        fontFamily: inter,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleMedium: const TextStyle(
        fontFamily: inter,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      bodyLarge: const TextStyle(
        fontFamily: inter,
        fontSize: 16,
        fontWeight: FontWeight.w300,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        fontFamily: inter,
        fontSize: 14,
        fontWeight: FontWeight.w300,
        height: 1.5,
      ),
      bodySmall: const TextStyle(
        fontFamily: inter,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      labelLarge: const TextStyle(
        fontFamily: inter,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        height: 1.2,
      ),
      labelMedium: const TextStyle(
        fontFamily: inter,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        height: 1.3,
      ),
      labelSmall: const TextStyle(
        fontFamily: inter,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        height: 1.3,
      ),
    );
  }
}
