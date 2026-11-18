import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/features/profile/providers/notification_prefs_provider.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Notification preferences — Q4a server-backed categories.
///
/// Every toggle is persisted through `set_notification_preferences`; the
/// server also enforces the defaults and the always-delivered categories.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(notificationPrefsProvider);

    final toggleTiles = [
      (
        Icons.person_add,
        l10n.notificationSettingsFriendRequests,
        'friends',
        true,
      ),
      (Icons.casino, l10n.notificationCategoryMinigames, 'minigames', true),
      (
        Icons.campaign_outlined,
        l10n.notificationCategoryMarketing,
        'marketing',
        false,
      ),
    ];

    final lockedTiles = [
      (Icons.shield_outlined, l10n.notificationCategorySecurity, 'security'),
      (Icons.gavel_outlined, l10n.notificationCategoryModeration, 'moderation'),
      (Icons.description_outlined, l10n.notificationCategoryLegal, 'legal'),
    ];

    return Scaffold(
      body: VHeaderBar(
        title: l10n.notificationSettingsTitle,
        child: prefs.when(
          loading: () => const VLoadingView(),
          error: (_, _) => VEmptyView(
            icon: Icons.notifications_off_outlined,
            title: l10n.notificationsLoadError,
          ),
          data: (values) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              VCard(
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      for (var i = 0; i < toggleTiles.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(toggleTiles[i].$1),
                          title: Text(toggleTiles[i].$2),
                          value: values[toggleTiles[i].$3] ?? toggleTiles[i].$4,
                          onChanged: (value) async {
                            try {
                              await ref
                                  .read(notificationPrefsProvider.notifier)
                                  .set(toggleTiles[i].$3, value);
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.notificationSettingsSaveError,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.notificationCategoryAlwaysOnTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              VCard(
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      for (var i = 0; i < lockedTiles.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(lockedTiles[i].$1),
                          title: Text(lockedTiles[i].$2),
                          trailing: Text(
                            l10n.notificationCategoryAlwaysOn,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.palette.mutedForeground),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.notificationSettingsServerNote,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.palette.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
