import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/storage_service.dart';

/// Injectable seam for the encrypted Hive config cache ([HiveService]).
///
/// Production uses the real service (initialized in `main()` by I-26);
/// tests override this provider with an in-memory fake to exercise the
/// theme provider without Hive or platform channels.
final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService();
});

/// UI-05 / L-16 (I-65): persisted theme-mode choice.
///
/// The brand is dark-only (DISCO-DESIGN-SYSTEM §1 P1 "black always"), so this
/// provider exists for **persistence + the 'system' seam**, not for a light
/// theme: [ThemeMode.dark] is the default, and `themeMode 'system'` resolves
/// to [SamayTheme.dark] anyway on most devices (both `theme` and `darkTheme`
/// in `SamayApp` are the disco theme).
///
/// State is persisted under [configKey] in the encrypted `config_cache` Hive
/// box (values `'dark'` / `'system'`). Failures degrade to dark and are
/// logged — a preference must never block boot.
final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  /// Cache key under which the choice is persisted in the encrypted
  /// `config_cache` box. Values: `'dark'` (default) | `'system'`.
  static const configKey = 'theme.mode';

  HiveService get _hive => ref.read(hiveServiceProvider);

  @override
  Future<ThemeMode> build() async {
    try {
      final cached = _hive.getCachedConfig();
      return _modeFor(cached?[configKey]);
    } catch (e, st) {
      // Uninitialized/re-created Hive (I-26 key-loss degradation): the cache
      // is treated as a miss — never a boot failure.
      AppLogger.instance.warn('Theme mode cache unreadable ($e); using dark.',
          '$st');
      return ThemeMode.dark;
    }
  }

  /// Persists [mode] to the encrypted config cache. The UI updates
  /// optimistically; a persistence failure is logged, never surfaced.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    try {
      await _hive.cacheConfig({configKey: mode.name});
    } catch (e, st) {
      AppLogger.instance.warn('Theme mode persistence failed: $e', '$st');
    }
  }

  /// Unknown/absent values fall back to dark — the brand default. A future
  /// light theme would add a `'light'` mapping here, not in the UI.
  ThemeMode _modeFor(String? stored) => switch (stored) {
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
}
