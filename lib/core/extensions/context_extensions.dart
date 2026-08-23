import 'package:flutter/material.dart';

import 'package:samay/core/design_tokens/app_colors.dart';

/// BuildContext convenience accessors over the Samay theme
/// (finding UI-07; DESIGN.md §8).
extension SamayThemeContext on BuildContext {
  /// The Samay palette resolved from the registered [SamayThemeExtension].
  ///
  /// Falls back to [SamayThemeExtension.dark] when the extension is not
  /// registered (e.g. bare test harnesses), so palette access never crashes.
  SamayThemeExtension get samayColors =>
      Theme.of(this).extension<SamayThemeExtension>() ??
      SamayThemeExtension.dark;

  /// The resolved [TextTheme] — shorthand for `Theme.of(this).textTheme`.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// The resolved [ColorScheme] — shorthand for `Theme.of(this).colorScheme`.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Whether the ambient theme is dark — shorthand for
  /// `Theme.of(this).brightness == Brightness.dark`.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
