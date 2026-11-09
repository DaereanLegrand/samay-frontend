import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/theme/app_palette.dart';

/// Re-maps the app's Material defaults onto a palette's tonal scale.
///
/// Used by BOTH the app-wide theme (Settings → Apariencia) and a group's own
/// theme. The reason it is needed at all: the shared widgets read the palette
/// through [AppThemeScope], but everything Material paints by itself — the
/// `Chip` fill, dividers, dialog/menu surfaces, default body text, list tiles —
/// keeps resolving the compiled-in black tokens unless the `ThemeData` carries
/// the palette too.
///
/// Two details matter:
///
/// * `canvasColor` is TRANSPARENT: a colourless `Material` (which `Chip` wraps
///   itself in) falls back to `canvasColor`, and a black canvas is exactly what
///   painted the old "black box" chips on a coloured page.
/// * `Customer`-facing widget colours stay in their own widgets; this only sets
///   the defaults so untouched Material widgets follow the theme.
ThemeData themedData(ThemeData base, AppPalette palette) {
  final scheme = base.colorScheme.copyWith(
    primary: palette.foreground,
    onPrimary: palette.background,
    secondary: palette.foreground,
    onSecondary: palette.background,
    surface: palette.background,
    onSurface: palette.foreground,
    onSurfaceVariant: palette.mutedForeground,
    outline: palette.border,
    outlineVariant: palette.hairline,
    shadow: palette.background,
    surfaceTint: AppColors.transparent,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: AppRadius.sharp,
    side: BorderSide(color: palette.border),
  );
  return base.copyWith(
    colorScheme: scheme,
    canvasColor: AppColors.transparent,
    scaffoldBackgroundColor: palette.background,
    primaryColor: palette.foreground,
    cardColor: palette.surface,
    dividerColor: palette.hairline,
    textTheme: base.textTheme.apply(
      bodyColor: palette.foreground,
      displayColor: palette.foreground,
    ),
    iconTheme: base.iconTheme.copyWith(color: palette.foreground),
    dividerTheme: base.dividerTheme.copyWith(color: palette.hairline),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: palette.background,
      foregroundColor: palette.foreground,
    ),
    bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
      backgroundColor: palette.surface,
      selectedItemColor: palette.foreground,
      unselectedItemColor: palette.mutedForeground,
    ),
    chipTheme: base.chipTheme.copyWith(
      // `color` outranks `backgroundColor` in Material 3; unselected chips are
      // transparent so the themed page shows through.
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.foreground
            : AppColors.transparent,
      ),
      backgroundColor: AppColors.transparent,
      selectedColor: palette.foreground,
      disabledColor: AppColors.transparent,
      labelStyle: TextStyle(color: palette.foreground),
      secondaryLabelStyle: TextStyle(color: palette.background),
      side: BorderSide(color: palette.foreground),
      elevation: 0,
      pressElevation: 0,
      surfaceTintColor: AppColors.transparent,
      shadowColor: AppColors.transparent,
      shape: shape,
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.transparent,
        foregroundColor: palette.foreground,
        selectedBackgroundColor: palette.foreground,
        selectedForegroundColor: palette.background,
        side: BorderSide(color: palette.foreground),
        shape: shape,
      ),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: palette.surface,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sharp,
        side: BorderSide(color: palette.hairline),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: palette.surface,
      surfaceTintColor: AppColors.transparent,
      shape: shape,
      titleTextStyle: base.dialogTheme.titleTextStyle?.copyWith(
        color: palette.foreground,
      ),
      contentTextStyle: base.dialogTheme.contentTextStyle?.copyWith(
        color: palette.mutedForeground,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: palette.surface,
      surfaceTintColor: AppColors.transparent,
      textStyle: TextStyle(color: palette.foreground),
      iconColor: palette.foreground,
      shape: shape,
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: palette.surfaceAlt,
      contentTextStyle: TextStyle(color: palette.foreground),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(
            foregroundColor: WidgetStatePropertyAll(palette.foreground),
            overlayColor: WidgetStatePropertyAll(palette.foreground),
          ) ??
          TextButton.styleFrom(foregroundColor: palette.foreground),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.foreground
            : AppColors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(palette.background),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sharp),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.background
            : palette.mutedForeground,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.foreground
            : palette.border,
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: palette.foreground,
      thumbColor: palette.foreground,
      inactiveTrackColor: palette.border,
      disabledActiveTrackColor: palette.border,
      disabledInactiveTrackColor: palette.surfaceAlt,
      disabledThumbColor: palette.mutedForeground,
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      indicatorColor: palette.foreground,
      labelColor: palette.foreground,
      unselectedLabelColor: palette.mutedForeground,
    ),
    progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
      color: palette.foreground,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      hintStyle:
          base.inputDecorationTheme.hintStyle?.copyWith(
            color: palette.mutedForeground,
          ) ??
          TextStyle(color: palette.mutedForeground),
      errorStyle: const TextStyle(color: AppColors.error),
    ),
    tooltipTheme: base.tooltipTheme.copyWith(
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: AppRadius.sharp,
      ),
      textStyle: TextStyle(color: palette.foreground),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      textColor: palette.foreground,
      iconColor: palette.foreground,
    ),
    datePickerTheme: base.datePickerTheme.copyWith(
      backgroundColor: palette.surface,
      surfaceTintColor: AppColors.transparent,
      headerBackgroundColor: palette.surfaceAlt,
      headerForegroundColor: palette.foreground,
      shape: shape,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: palette.surface,
      surfaceTintColor: AppColors.transparent,
      modalBackgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(),
    ),
  );
}
