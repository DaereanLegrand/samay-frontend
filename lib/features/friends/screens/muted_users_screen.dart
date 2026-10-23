import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_refreshable.dart';

/// Users the current user muted. Mute is one-way and weaker than block: the
/// muted user can still DM/invite, but their activity disappears from the
/// muter's feed, rankings and notifications.
class MutedUsersScreen extends ConsumerWidget {
  const MutedUsersScreen({super.key});

  String _initials(UserProfile user) {
    final username = user.username;
    return username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mutedAsync = ref.watch(mutedUsersProvider);
    final muted = mutedAsync.valueOrNull;
    Future<void> onRefresh() => ref.read(mutedUsersProvider.notifier).refresh();

    return Scaffold(
      body: VHeaderBar(
        title: l10n.profileMutedUsers,
        child: VStateView(
          loading: mutedAsync.isLoading,
          error: mutedAsync.error,
          errorMessage: mutedAsync.hasError
              ? mutedAsync.error!.toAppError().message
              : null,
          onRetry: onRefresh,
          empty: VRefreshable(
            onRefresh: onRefresh,
            child: VEmptyView(
              icon: Icons.volume_off,
              title: l10n.friendsNoneMuted,
            ),
          ),
          child: muted == null || muted.isEmpty
              ? null
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: muted.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final u = muted[i];
                      return VCard(
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            leading: ProfileAvatar(
                              size: AppSpacing.avatar,
                              initials: _initials(u),
                              imageUrl: u.avatarUrl,
                            ),
                            title: Text('@${u.username}'),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref
                                    .read(friendshipServiceProvider)
                                    .unmuteUser(u.id);
                                ref.invalidate(mutedUsersProvider);
                              },
                              child: Text(l10n.friendsUnmute),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
