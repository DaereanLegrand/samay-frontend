import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/features/profile/providers/notification_prefs_provider.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Notification preferences (R2 — wires the settings Notificaciones row).
///
/// Each toggle maps to a persisted key in the encrypted local config cache
/// (see [NotificationPrefsNotifier]); the screen shows the current state and
/// flips it optimistically. There is no server-side preference table yet —
/// the footer says so honestly instead of pretending otherwise.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(notificationPrefsProvider);

    final tiles = [
      (
        Icons.event,
        l10n.notificationSettingsEventReminders,
        'notifications.event_reminders',
      ),
      (
        Icons.person_add,
        l10n.notificationSettingsFriendRequests,
        'notifications.friend_requests',
      ),
      (
        Icons.chat_bubble,
        l10n.notificationSettingsChatMessages,
        'notifications.chat_messages',
      ),
      (
        Icons.diamond,
        l10n.notificationSettingsShardsRank,
        'notifications.shards_rank',
      ),
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
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(tiles[i].$1),
                          title: Text(tiles[i].$2),
                          value: values[tiles[i].$3] ?? true,
                          onChanged: (value) => ref
                              .read(notificationPrefsProvider.notifier)
                              .set(tiles[i].$3, value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // R2: honest copy — the prefs live on-device only; the
              // remote push pipeline is a later step.
              Text(
                l10n.notificationSettingsLocalNote,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mutedStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
