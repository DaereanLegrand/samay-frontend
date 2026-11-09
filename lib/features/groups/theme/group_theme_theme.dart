import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/theme/group_theme_colors.dart';
import 'package:samay/features/groups/theme/group_theme_palette.dart';
import 'package:samay/features/groups/theme/group_theme_scope.dart';

/// Re-maps the app's Material defaults onto a group theme's derived scale.
///
/// [GroupThemeScope] only serves widgets that ask for it; everything painted by
/// Material itself (the `Chip` fill, dividers, dialog and menu surfaces, default
/// body text) keeps resolving the app-wide black palette. That is why unselected
/// chips painted a black box on a coloured group page: `Chip` wraps itself in a
/// colourless `Material`, which falls back to `Theme.canvasColor` — black.
///
/// This builds the `ThemeData` a themed group surface needs:
///
/// * `canvasColor` is TRANSPARENT so colourless `Material`s (chips) reveal the
///   page instead of painting black.
/// * `scaffoldBackgroundColor`, `cardColor`, `dividerColor` and the colour-scheme
///   roles come from the derived palette.
/// * Default text/icon themes use the themed foreground, so widget copy that
///   does not set a colour (ListTile titles, body text, dialog content) is
///   legible on the coloured page.
ThemeData groupThemeTheme(ThemeData base, GroupThemePalette palette) {
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
    // A colourless Material (Chip, Ink) must show the page, never black.
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
    progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
      color: palette.foreground,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      hintStyle: base.inputDecorationTheme.hintStyle?.copyWith(
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
  );
}

/// Wraps [child] in a group's themed Material surface.
///
/// Mounts the [GroupThemeScope] AND the re-mapped `ThemeData` above [child].
/// The palette comes from [palette] when the caller already resolved it, else
/// from the group theme provider for [groupId]. While the theme loads — or when
/// there is no [groupId], a non-member cannot read the theme, or the RPC fails —
/// [child] renders on the app's standard theme unchanged.
class GroupThemeSurface extends ConsumerWidget {
  const GroupThemeSurface({
    super.key,
    this.groupId,
    this.palette,
    required this.child,
  });

  /// The group whose theme paints [child]; null keeps the standard theme.
  final String? groupId;

  /// An already-derived palette. Overrides the provider lookup when present.
  final GroupThemePalette? palette;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = groupId;
    final watched = id == null
        ? null
        : ref.watch(groupThemeProvider(id)).valueOrNull;
    final resolved = palette ?? (watched == null ? null : groupThemePaletteOf(watched));
    if (resolved == null) return child;
    return GroupThemeScope(
      palette: resolved,
      child: Theme(
        data: groupThemeTheme(Theme.of(context), resolved),
        child: child,
      ),
    );
  }
}
