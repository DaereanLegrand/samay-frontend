import 'package:flutter/widgets.dart';
import 'package:samay/core/theme/app_palette.dart';
import 'package:samay/core/theme/app_theme_scope.dart';

/// `context.palette` — the ambient painted scale for this widget.
///
/// Resolves the nearest [AppThemeScope] (the app-wide theme, or a group's
/// override) and falls back to [AppPalette.standard] (the design tokens) when
/// no theme is active. Screens use it instead of the compiled-in `AppColors`
/// surface/text roles so the chosen theme actually reaches them.
extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppThemeScope.paletteOf(this);
}
