import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
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
      // LUXE v2 (XL-08): settings is a flat utility screen — no hero; the
      // flat glass groups carry the gold family.
      body: ListView(
          children: [
            // U-15 R6 (F18 ADAPTED): Juega's grouped settings (VISUAL/ACCOUNT/
            // LEGAL cards) → Samay's flat section headers (uppercase
            // `AppTypography.sectionLabel` — Inter letter-spaced) + sharp
            // glass groups with hairline row dividers (LUXE v2: the U-15
            // grouping structure now wears liquid glass).
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
                  ],
                ),
              ),
            ),
            // Chat group (2026-08-15): the read-receipts privacy switch —
            // WhatsApp-style ✓/✓✓/read ticks. When off, the reader's device
            // never stamps `read_at`, so the peer never sees blue checks.
            _SectionHeader(l10n.settingsSectionChat),
            VCard(
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    _ReadReceiptsTile(),
                  ],
                ),
              ),
            ),
            // Minigames group (140_minigame_invites): the invite privacy
            // switch — when ON only accepted friends may invite this user to
            // a minigame (enforced server-side in create_minigame_session).
            _SectionHeader(l10n.settingsSectionGames),
            VCard(
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    _MinigameInvitePrivacyTile(),
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
                    // R2: the notifications row opens the real
                    // notification-preferences screen (persisted toggles,
                    // local Hive config cache — no more disabled placeholder).
                    _SettingsTile(
                      icon: Icons.notifications,
                      label: l10n.profileNotifications,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      ),
                    ),
                    const Divider(),
                    _SettingsTile(
                      icon: Icons.person,
                      label: l10n.profileEditTitle,
                      onTap: () => context.push(RoutePaths.profileEdit),
                    ),
                    const Divider(),
                    // C-social (2026-08-18): the public-profile privacy
                    // switch — when ON the name/photo appear on the global
                    // user ranking (Social tab). Bound to users.profile_public
                    // via profilePublicProvider.
                    _PublicProfileTile(),
                    const Divider(),
                    // R2: the privacy row opens the static privacy/terms info
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
                    const Divider(),
                    _SettingsTile(
                      icon: Icons.block,
                      label: l10n.profileBlockedUsers,
                      onTap: () => context.push(RoutePaths.blockedUsers),
                    ),
                    const Divider(),
                    // U-15 R7: the danger pair closes the account section —
                    // delete + sign out, both in the error semantic (LUXE:
                    // danger stays semantic, the gold family never touches it).
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

/// U-15 R6: settings section header — the §3.3 overline voice
/// (`AppTypography.sectionLabel`: uppercase Inter w600 12, 2.0 tracking,
/// mutedStrong 7.37:1 AA). The grouping voice, flat — LUXE v2 (XL-08).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(label.toUpperCase(), style: AppTypography.sectionLabel),
    );
  }
}

/// The public-profile privacy switch (C-social, 2026-08-18):
/// `users.profile_public` via [profilePublicProvider]. When ON the name and
/// photo appear on the global user ranking. Optimistic — a persistence
/// failure rolls the switch back and surfaces a snackbar.
class _PublicProfileTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled =
        ref.watch(profilePublicProvider).valueOrNull ?? false;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.public),
      title: Text(l10n.socialPublicProfileLabel),
      subtitle: Text(
        l10n.socialPublicProfileBody,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.mutedStrong),
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

/// Settings menu row (PERF-08/CQ-05: the repeated ListTile shapes are
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
      // The tiles live inside VGlassCard groups (R6 — LUXE v2), which
      // already carry the 16px glass padding — zero content padding keeps
      // the row metrics identical to the pre-grouping flat list.
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
      // The chevron is the "navigates elsewhere" affordance — a row with no
      // destination must not show it.
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
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
              // §5.4 chip treatment is theme-owned since U-27 (the
              // `segmentedButtonTheme` in app_theme.dart): transparent +
              // white unselected, white fill + black text selected, white
              // side, sharp. Labels resolve the theme's labelLarge (Inter
              // w700) — token-clean.
            ),
          ),
        ],
      ),
    );
  }
}

/// The read-receipts privacy switch (2026-08-15): `users.read_receipts_enabled`
/// via [readReceiptsEnabledProvider]. Optimistic — a persistence failure
/// rolls the switch back and surfaces a snackbar.
class _ReadReceiptsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled =
        ref.watch(readReceiptsEnabledProvider).valueOrNull ?? true;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.done_all),
      title: Text(l10n.chatReadReceipts),
      subtitle: Text(
        l10n.chatReadReceiptsBody,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.mutedStrong),
      ),
      value: enabled,
      onChanged: (value) async {
        try {
          await ref.read(readReceiptsEnabledProvider.notifier).setEnabled(value);
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
        ).textTheme.bodySmall?.copyWith(color: AppColors.mutedStrong),
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
