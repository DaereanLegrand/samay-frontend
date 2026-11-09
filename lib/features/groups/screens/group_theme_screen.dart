import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/group_theme.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/theme/group_theme_colors.dart';
import 'package:samay/core/theme/app_palette.dart';
import 'package:samay/features/groups/theme/group_theme_theme.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// E4 group theme editor: preview, control mode (host only) and the palette
/// allowed by the host's tier. The server is the authority — the controls are
/// only shown for the actions `get_group_theme` marks as allowed.
class GroupThemeScreen extends ConsumerWidget {
  const GroupThemeScreen({super.key, required this.groupId});

  final String groupId;

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref, {
    String? background,
    String? control,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsRepositoryProvider).setGroupTheme(
            groupId,
            backgroundColor: background,
            controlMode: control,
          );
      ref.invalidate(groupThemeProvider(groupId));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupThemeSaved)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toAppError().localize(l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = ref.watch(groupThemeProvider(groupId)).valueOrNull;
    // The editor itself is part of the group surface: it paints the same
    // derived scale so the Swatches/Control chips are readable on the theme
    // (a black page made every unselected chip and divider vanish).
    final palette = theme == null ? null : groupThemePaletteOf(theme);
    final body = VHeaderBar(
      title: l10n.groupThemeTitle,
      child: ref.watch(groupThemeProvider(groupId)).when(
        loading: () => const VLoadingView(),
        error: (error, _) => ErrorView(
          message: error.toAppError().localize(l10n),
          onRetry: () => ref.invalidate(groupThemeProvider(groupId)),
        ),
        data: (theme) => _body(context, ref, theme),
      ),
    );
    if (palette == null) {
      return Scaffold(body: body);
    }
    // The editor is part of the group surface: GroupThemeSurface also remaps
    // canvas/chip/dialog defaults, so the chips and dividers follow the theme.
    return GroupThemeSurface(
      palette: palette,
      child: Scaffold(
        backgroundColor: palette.background,
        body: body,
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, GroupTheme theme) {
    final l10n = AppLocalizations.of(context);
    final palette = groupThemePaletteOf(theme);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _preview(context, l10n, theme),
        const SizedBox(height: AppSpacing.xl),
        if (theme.canChangeControl) ...[
          Text(l10n.groupThemeControl,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.foreground,
                  )),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final mode in const ['everyone', 'host_only', 'locked'])
                ChoiceChip(
                  label: Text(_modeLabel(l10n, mode)),
                  selected: theme.controlMode == mode,
                  onSelected: (selected) {
                    if (!selected || theme.controlMode == mode) return;
                    _apply(context, ref, control: mode);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Text(l10n.groupThemePalette,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.foreground,
                )),
        const SizedBox(height: AppSpacing.sm),
        if (!theme.canChangeColor)
          Text(
            theme.controlMode == 'locked'
                ? l10n.groupThemeLockedHint
                : l10n.groupThemePaletteFree,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.mutedForeground,
                ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final hex in theme.palette)
                _swatch(context, ref, theme, hex),
            ],
          ),
      ],
    );
  }

  Widget _preview(
    BuildContext context,
    AppLocalizations l10n,
    GroupTheme theme,
  ) {
    // Preview what the app actually paints (75% darker + complementary ink),
    // not the raw server hexes.
    final painted = groupThemePaletteOf(theme);
    final bg = painted.background;
    final fg = painted.foreground;
    final accent = painted.accent;
    final accentFg = painted.accentForeground;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: painted.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.groupThemePreview,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.groupThemeControlEveryone,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: accentFg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatch(
    BuildContext context,
    WidgetRef ref,
    GroupTheme theme,
    String hex,
  ) {
    final selected = theme.backgroundColor.toUpperCase() == hex.toUpperCase();
    // Each swatch shows what the app will PAINT for that pick: the colour
    // darkened 75%, with its complementary ink as the checkmark.
    final swatchBg = AppPalette.darken(
      groupThemeColor(hex),
      AppPalette.darkenAmount,
    );
    final checkColor = AppPalette.complement(swatchBg);
    final palette = groupThemePaletteOf(theme);
    return InkWell(
      onTap: selected ? null : () => _apply(context, ref, background: hex),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: swatchBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.foreground : palette.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: selected ? Icon(Icons.check, color: checkColor) : null,
      ),
    );
  }

  String _modeLabel(AppLocalizations l10n, String mode) {
    switch (mode) {
      case 'host_only':
        return l10n.groupThemeControlHostOnly;
      case 'locked':
        return l10n.groupThemeControlLocked;
      default:
        return l10n.groupThemeControlEveryone;
    }
  }
}
