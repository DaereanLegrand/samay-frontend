import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/theme_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// U-15 R7: sign-out now goes through the F8 confirm dialog (the same
  /// dialog discipline as the delete-account flow) — a stray tap can no
  /// longer drop the session. Confirmed → signOut + login; cancel → stay.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileSignOutQuestion),
        content: Text(l10n.profileSignOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.profileSignOut,
              // §5.2 (U-09): the danger confirm uses the error semantic
              // (glowPink, 6.00:1 AA) — never raw red on black. Mirrors the
              // delete-account dialog precedent.
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).signOut();
      if (context.mounted) context.go(RoutePaths.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // UI-05 / L-16 (I-65): persisted theme-mode choice (default dark).
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileSettingsTitle)),
      body: ListView(
        children: [
          // U-15 R6 (F18 ADAPTED): Juega's grouped settings (VISUAL/ACCOUNT/
          // LEGAL cards) → Samay's flat section headers (uppercase labelSmall
          // mutedStrong) + sharp VCard groups with hairline row dividers —
          // the grouping structure transfers, the glass does not (N2).
          _SectionHeader(l10n.settingsSectionAppearance),
          VCard(
            // The transparent Material lets the ListTiles paint their ink
            // splashes above the card surface (the framework asserts when a
            // ListTile sits under a colored DecoratedBox without one).
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ThemeSection(
                    themeMode: themeMode,
                    onChanged: (mode) =>
                        ref.read(themeModeProvider.notifier).setThemeMode(mode),
                  ),
                ],
              ),
            ),
          ),
          _SectionHeader(l10n.settingsSectionAccount),
          VCard(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.subscriptions,
                    label: l10n.profileSubscription,
                    onTap: () => context.push(RoutePaths.subscriptions),
                  ),
                  const Divider(),
                  _SettingsTile(
                    icon: Icons.notifications,
                    label: l10n.profileNotifications,
                    onTap: () {},
                  ),
                  const Divider(),
                  _SettingsTile(
                    icon: Icons.person,
                    label: l10n.profileEditTitle,
                    onTap: () => context.push(RoutePaths.profileEdit),
                  ),
                  const Divider(),
                  _SettingsTile(
                    icon: Icons.shield,
                    label: l10n.profilePrivacy,
                    onTap: () {},
                  ),
                  const Divider(),
                  _SettingsTile(
                    icon: Icons.block,
                    label: l10n.profileBlockedUsers,
                    onTap: () => context.push(RoutePaths.blockedUsers),
                  ),
                  const Divider(),
                  // U-15 R7: the danger pair closes the account section —
                  // delete + sign out, both in the error semantic.
                  _SettingsTile(
                    icon: Icons.delete_forever,
                    label: l10n.profileDeleteMyAccount,
                    destructive: true,
                    onTap: () => context.push(RoutePaths.deleteAccount),
                  ),
                  const Divider(),
                  _SettingsTile(
                    icon: Icons.logout,
                    label: l10n.profileSignOut,
                    destructive: true,
                    onTap: () => _confirmSignOut(context, ref),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.profileVersion,
              // §2.4: the version string is informational text below the
              // muted threshold — mutedStrong (7.37:1 AA).
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedStrong),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// U-15 R6: settings section header — uppercase `labelSmall` (the §3.3
/// overline role) in mutedStrong (§2.4 AA). The grouping voice, flat.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.mutedStrong),
      ),
    );
  }
}

/// Settings menu row (PERF-08/CQ-05: the seven repeated ListTile shapes are
/// one const sub-widget; only the data that changes is passed in).
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // The tiles live inside VCard groups (R6), which already carry the
      // 16px card padding — zero content padding keeps the row metrics
      // identical to the pre-grouping flat list.
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        // §5.2 (U-09): danger rows use the error semantic — glowPink
        // 6.00:1 AA at normal size; glowPinkDeep is AA-large-only and
        // banned as a sole text color (§2.5 rule 6).
        color: destructive ? AppColors.error : null,
      ),
      title: Text(
        label,
        style: destructive ? const TextStyle(color: AppColors.error) : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// UI-05 / L-16 (I-65): theme-mode picker. Dark is the brand default;
/// 'system' is the future seam (it resolves to the disco dark theme on most
/// devices — both app themes are dark by design).
class _ThemeSection extends StatelessWidget {
  const _ThemeSection({required this.themeMode, required this.onChanged});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      // Inside the R6 appearance VCard: the card carries the 16px horizontal
      // padding; only the vertical rhythm stays here.
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsTheme,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.settingsThemeDark),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.settingsThemeSystem),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) => onChanged(selection.first),
              // §5.4 chip treatment (U-09): transparent + white unselected,
              // white fill + black text selected, white side, sharp. Labels
              // resolve the theme's labelLarge (Inter w700) — token-clean.
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.white,
                selectedBackgroundColor: AppColors.white,
                selectedForegroundColor: AppColors.discoBlack,
                side: const BorderSide(color: AppColors.white),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.sharp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
