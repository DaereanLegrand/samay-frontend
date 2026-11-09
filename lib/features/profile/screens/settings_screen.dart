import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/theme_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/profile/screens/notification_settings_screen.dart';
import 'package:samay/features/profile/screens/privacy_info_screen.dart';
import 'package:samay/features/social/providers/social_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Sign-out goes through the confirm dialog (the same
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
              // The danger confirm uses the error semantic (glowPink,
              // 6.00:1 AA) — never raw red on black.
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

  /// SEC-033: explicit local wipe. Signs out, revokes the push token and
  /// removes every cache/E2EE secret on this device; the account is kept.
  Future<void> _confirmClearLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsClearLocalDataQuestion),
        content: Text(l10n.settingsClearLocalDataBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.settingsClearLocalData,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authStateProvider.notifier).clearLocalData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsClearLocalDataDone)));
    context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Persisted theme-mode choice (default dark).
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;
    return Scaffold(
      body: VHeaderBar(
        title: l10n.profileSettingsTitle,
        child: ListView(
          children: [
            // Flat section headers (uppercase `AppTypography.sectionLabel` —
            // Inter letter-spaced) with hairline row dividers.
            _SectionHeader(l10n.settingsSectionAppearance),
            VCard(
              // The transparent Material lets the ListTiles paint their ink
              // splashes above the glass face (the framework asserts when a
              // ListTile sits under a colored DecoratedBox without one).
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ThemeSection(
                      themeMode: themeMode,
                      onChanged: (mode) => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(mode),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
                    // The app-wide colour (paywalled). Opened as its own screen
                    // so the preview cards get room to be honest about the
                    // painted result.
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      label: l10n.appThemeTitle,
                      onTap: () => context.push(RoutePaths.appTheme),
                    ),
                  ],
                ),
              ),
            ),
            // The read-receipts privacy switch —
            // WhatsApp-style ✓/✓✓/read ticks. When off, the reader's device
            // never stamps `read_at`, so the peer never sees blue checks.
            _SectionHeader(l10n.settingsSectionChat),
            VCard(
              child: Material(
                type: MaterialType.transparency,
                child: Column(children: [_ReadReceiptsTile()]),
              ),
            ),
            // Minigames group (140_minigame_invites): the invite privacy
            // switch — when ON only accepted friends may invite this user to
            // a minigame (enforced server-side in create_minigame_session).
            _SectionHeader(l10n.settingsSectionGames),
            VCard(
              child: Material(
                type: MaterialType.transparency,
                child: Column(children: [_MinigameInvitePrivacyTile()]),
              ),
            ),
            _SectionHeader(l10n.settingsSectionAccount),
            VCard(
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    // Subscriptions ship dark (prod builds carry no RevenueCat
                    // key); when the flag is off the row is absent entirely.
                    if (ref
                        .watch(featureFlagsProvider)
                        .isEnabled(AppFeatureFlag.subscriptions)) ...[
                      _SettingsTile(
                        icon: Icons.subscriptions,
                        label: l10n.profileSubscription,
                        onTap: () => context.push(RoutePaths.subscriptions),
                      ),
                      Divider(height: 1, color: context.palette.hairline),
                    ],
                    // The notifications row opens the server-backed category screen
                    // (Q4a: users.notification_preferences).
                    _SettingsTile(
                      icon: Icons.notifications,
                      label: l10n.profileNotifications,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
                    _SettingsTile(
                      icon: Icons.person,
                      label: l10n.profileEditTitle,
                      onTap: () => context.push(RoutePaths.profileEdit),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
                    // The public-profile privacy
                    // switch — when ON the name/photo appear on the global
                    // user ranking (Social tab). Bound to users.profile_public
                    // via profilePublicProvider.
                    _PublicProfileTile(),
                    Divider(height: 1, color: context.palette.hairline),
                    // The privacy row opens the static privacy/terms info
                    // screen (the signup-funnel consent gate cannot render
                    // standalone — it requires email/dateOfBirth extras).
                    _SettingsTile(
                      icon: Icons.shield,
                      label: l10n.profilePrivacy,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyInfoScreen(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
                    // Data portability (Ley N° 29733): download a copy of the
                    // account's own data.
                    _SettingsTile(
                      icon: Icons.download_outlined,
                      label: l10n.profileExportData,
                      onTap: () => context.push(RoutePaths.exportData),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
                    _SettingsTile(
                      icon: Icons.block,
                      label: l10n.profileBlockedUsers,
                      onTap: () => context.push(RoutePaths.blockedUsers),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
                    _SettingsTile(
                      icon: Icons.volume_off,
                      label: l10n.profileMutedUsers,
                      onTap: () => context.push(RoutePaths.mutedUsers),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
                    _SettingsTile(
                      icon: Icons.gavel_outlined,
                      label: l10n.appealsTitle,
                      onTap: () => context.push(RoutePaths.appeals),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
                    // SEC-033: wipe messages/notifications/photos/prefs and
                    // local key material without touching the account.
                    _SettingsTile(
                      icon: Icons.cleaning_services,
                      label: l10n.settingsClearLocalData,
                      destructive: true,
                      onTap: () => _confirmClearLocalData(context, ref),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
                    // The danger pair closes the account section — delete +
                    // sign out, both in the danger semantic.
                    _SettingsTile(
                      icon: Icons.delete_forever,
                      label: l10n.profileDeleteMyAccount,
                      destructive: true,
                      onTap: () => context.push(RoutePaths.deleteAccount),
                    ),
                    Divider(height: 1, color: context.palette.hairline),
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
                ).textTheme.bodyMedium?.copyWith(color: context.palette.mutedForeground),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings section header — the `AppTypography.sectionLabel` overline voice.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xl,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: Text(label.toUpperCase(), style: AppTypography.sectionLabel),
    );
  }
}

/// The public-profile privacy switch:
/// `users.profile_public` via [profilePublicProvider]. When ON the name and
/// photo appear on the global user ranking. Optimistic — a persistence
/// failure rolls the switch back and surfaces a snackbar.
class _PublicProfileTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(profilePublicProvider).valueOrNull ?? false;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.public),
      title: Text(l10n.socialPublicProfileLabel),
      subtitle: Text(
        l10n.socialPublicProfileBody,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.palette.mutedForeground),
      ),
      value: enabled,
      onChanged: (value) async {
        try {
          await ref.read(profilePublicProvider.notifier).setEnabled(value);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.chatReadReceiptsSaveError)),
            );
          }
        }
      },
    );
  }
}

/// One settings row: icon, label and a chevron affordance when it navigates.
/// Destructive rows use the error semantic.
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
    final color = destructive ? AppColors.error : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: AppIconSizes.md, color: color ?? context.palette.foreground),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: color),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: AppIconSizes.md,
                color: context.palette.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}

/// Theme-mode picker. Dark is the brand default;
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsTheme,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: VChip(
                  label: l10n.settingsThemeDark,
                  selected: themeMode == ThemeMode.dark,
                  onSelected: () => onChanged(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: VChip(
                  label: l10n.settingsThemeSystem,
                  selected: themeMode == ThemeMode.system,
                  onSelected: () => onChanged(ThemeMode.system),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The read-receipts privacy switch: `users.read_receipts_enabled`
/// via [readReceiptsEnabledProvider]. Optimistic — a persistence failure
/// rolls the switch back and surfaces a snackbar.
class _ReadReceiptsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(readReceiptsEnabledProvider).valueOrNull ?? true;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.done_all),
      title: Text(l10n.chatReadReceipts),
      subtitle: Text(
        l10n.chatReadReceiptsBody,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.palette.mutedForeground),
      ),
      value: enabled,
      onChanged: (value) async {
        try {
          await ref
              .read(readReceiptsEnabledProvider.notifier)
              .setEnabled(value);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.chatReadReceiptsSaveError)),
            );
          }
        }
      },
    );
  }
}

/// The minigame-invite privacy switch (140_minigame_invites):
/// `users.minigame_invite_friends_only` via
/// [minigameInviteFriendsOnlyProvider]. When ON only accepted friends may
/// invite this user to a minigame; the gate is enforced server-side in
/// create_minigame_session. Optimistic — a persistence failure rolls the
/// switch back and surfaces a snackbar.
class _MinigameInvitePrivacyTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled =
        ref.watch(minigameInviteFriendsOnlyProvider).valueOrNull ?? false;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.sports_esports),
      title: Text(l10n.minigamesInviteFriendsOnly),
      subtitle: Text(
        l10n.minigamesInviteFriendsOnlyBody,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.palette.mutedForeground),
      ),
      value: enabled,
      onChanged: (value) async {
        try {
          await ref
              .read(minigameInviteFriendsOnlyProvider.notifier)
              .setFriendsOnly(value);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.minigamesInviteFriendsOnlySaveError)),
            );
          }
        }
      },
    );
  }
}
