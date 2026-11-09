import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/core/theme/app_theme_presets.dart';
import 'package:samay/core/theme/app_theme_provider.dart';
import 'package:samay/features/profile/providers/profile_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Settings → Apariencia → Color de la app.
///
/// Lists every [AppThemePreset] as a preview card — the painted page as a swatch
/// with its complementary ink — and selects one on tap. Presets above the
/// user's `subscription_tier` show a lock and cannot be selected (the paywall
/// seam; the backend owns the tier).
class AppThemeScreen extends ConsumerWidget {
  const AppThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected =
        ref.watch(appThemePresetProvider).valueOrNull ?? AppThemePreset.classic;
    final tier =
        ref.watch(myProfileProvider).valueOrNull?['subscription_tier']
            as String? ??
        'free';

    return Scaffold(
      body: VHeaderBar(
        title: l10n.appThemeTitle,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              l10n.appThemeSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final preset in AppThemePreset.values) ...[
              _PresetCard(
                preset: preset,
                selected: preset == selected,
                unlocked: isPresetUnlocked(preset, tier),
                onTap: () => ref
                    .read(appThemePresetProvider.notifier)
                    .select(preset, userTier: tier),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.appThemeGroupFollowsApp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.palette.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  final AppThemePreset preset;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final painted = preset.palette;
    final label = _label(l10n, preset);
    return InkWell(
      onTap: unlocked ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(
            color: selected
                ? context.palette.foreground
                : context.palette.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // The preview IS the painted result: page + its complementary ink,
            // so a card never promises a colour the app will not paint.
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: painted.background,
                border: Border.all(color: painted.border),
              ),
              child: Center(
                child: Text(
                  'Aa',
                  style: TextStyle(
                    color: painted.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.palette.foreground,
                    ),
                  ),
                  if (!unlocked) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      preset.tierRequirement == 'vip'
                          ? l10n.appThemeLockedVip
                          : l10n.appThemeLockedPro,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              unlocked
                  ? (selected ? Icons.check_circle : Icons.circle_outlined)
                  : Icons.lock_outline,
              color: selected
                  ? context.palette.foreground
                  : context.palette.mutedForeground,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  static String _label(AppLocalizations l10n, AppThemePreset preset) {
    return switch (preset) {
      AppThemePreset.classic => l10n.appThemeClassic,
      AppThemePreset.midnight => l10n.appThemeMidnight,
      AppThemePreset.forest => l10n.appThemeForest,
      AppThemePreset.violet => l10n.appThemeViolet,
      AppThemePreset.ember => l10n.appThemeEmber,
      AppThemePreset.teal => l10n.appThemeTeal,
      AppThemePreset.rose => l10n.appThemeRose,
    };
  }
}
