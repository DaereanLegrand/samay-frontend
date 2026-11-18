import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/prompt_pack_service.dart' show tierRank;
import 'package:samay/core/services/storage_service.dart';
import 'package:samay/core/theme/app_palette.dart';
import 'package:samay/core/theme/app_theme_presets.dart';
import 'package:samay/features/profile/providers/profile_providers.dart';

/// The user's chosen app-wide theme preset (Settings → Apariencia).
///
/// Persisted in the encrypted `config_cache` Hive box under [configKey] as the
/// preset id, so the choice survives restarts without a backend round trip.
/// Unknown/absent values fall back to [AppThemePreset.classic] — the design
/// tokens — so an app with no stored choice is byte-identical to before.
///
/// The gate: a preset whose [AppThemePreset.tierRequirement] outranks the
/// user's `subscription_tier` is NOT painted (and the picker locks it). The
/// paywall is client-side for now; when the store ships, the same field drives
/// the upsell and the backend can enforce it.
final appThemePresetProvider =
    AsyncNotifierProvider<AppThemePresetNotifier, AppThemePreset>(
      AppThemePresetNotifier.new,
    );

class AppThemePresetNotifier extends AsyncNotifier<AppThemePreset> {
  /// Persistence key under `config_cache`. Value: an [AppThemePreset.id].
  static const configKey = 'theme.palette';

  HiveService get _hive => ref.read(hiveServiceProvider);

  /// Re-applies the gate whenever the tier changes: an expired subscription
  /// drops the painted theme back to classic instead of keeping a paid colour.
  void _watchTier() {
    ref.listen(myProfileProvider, (_, next) {
      final tier = next.valueOrNull?['subscription_tier'] as String?;
      if (tier != null) reconcileTier(tier);
    });
  }

  @override
  Future<AppThemePreset> build() async {
    _watchTier();
    try {
      final cached = _hive.getCachedConfig();
      return AppThemePreset.tryParse(cached?[configKey]) ?? AppThemePreset.classic;
    } catch (e, st) {
      AppLogger.instance.warn('App theme cache unreadable ($e); using classic.',
          '$st');
      return AppThemePreset.classic;
    }
  }

  /// Selects [preset]. Ignored when the user's tier does not include it, so a
  /// locked preset can never be painted by a stale claim.
  Future<void> select(AppThemePreset preset, {required String userTier}) async {
    if (!isPresetUnlocked(preset, userTier)) return;
    state = AsyncData(preset);
    try {
      await _hive.cacheConfig({configKey: preset.id});
    } catch (e, st) {
      AppLogger.instance.warn('App theme persistence failed: $e', '$st');
    }
  }

  /// Re-applies the gate after a tier change (e.g. a subscription lapses): if
  /// the stored preset is no longer allowed, drop back to classic.
  Future<void> reconcileTier(String userTier) async {
    final current = state.valueOrNull ?? AppThemePreset.classic;
    if (isPresetUnlocked(current, userTier)) return;
    await select(AppThemePreset.classic, userTier: userTier);
  }
}

/// Whether [preset] is available at [userTier] (`free < pro < vip`).
bool isPresetUnlocked(AppThemePreset preset, String userTier) =>
    tierRank(preset.tierRequirement) <= tierRank(userTier);

/// The palette to paint: the selected preset's scale, unless the user's tier
/// does not allow it (then classic). Never throws — the theme must never block
/// a frame.
///
/// While the profile is still loading (or signed out) the stored choice is
/// painted as-is: gating on an unknown tier would flash every paid preset back
/// to classic on each cold start.
final appPaletteProvider = Provider<AppPalette>((ref) {
  final preset =
      ref.watch(appThemePresetProvider).valueOrNull ?? AppThemePreset.classic;
  final profile = ref.watch(myProfileProvider).valueOrNull;
  if (profile == null) return preset.palette;
  final tier = profile['subscription_tier'] as String? ?? 'free';
  if (!isPresetUnlocked(preset, tier)) return AppPalette.standard;
  return preset.palette;
});
