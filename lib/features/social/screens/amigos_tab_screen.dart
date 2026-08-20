import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/social/widgets/social_action_tile.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_refreshable.dart';

/// The Amigos sub-tab of the Social screen (C-social, 2026-08-18): the
/// Solicitudes (requests, with the pending badge) + Ranking entries above the
/// friends list. The top-right lupa (user search) lives in the Social
/// shell's AppBar (visible on both sub-tabs).
///
/// White-only: the entries are the shared compact [SocialActionTile] row
/// (same widget as the Grupos sub-tab), the friends list rows are plain
/// hairline rows.
class AmigosTab extends ConsumerWidget {
  const AmigosTab({super.key});

  // U-26 (U-24 F3): an empty (non-null) username would RangeError on
  // substring — the '?' initial fallback.
  String _initials(UserProfile user) {
    final username = user.username;
    return username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // R12 (F5): the requests entry badge — total pending = received friend
    // requests + group invites, from the same providers the requests screen
    // shows. Zero renders nothing (VCountBadge).
    final pendingCount =
        (ref
                .watch(friendRequestsProvider)
                .valueOrNull
                ?.requests
                .where((r) => r.type == 'received')
                .length ??
            0) +
        (ref.watch(groupInvitesProvider).valueOrNull?.length ?? 0);
    return Column(
      children: [
        SocialActionsRow(
          children: [
            SocialActionTile(
              icon: Icons.person_add_outlined,
              label: l10n.groupsRequests,
              badge: pendingCount > 0 ? pendingCount : null,
              onTap: () => context.push(RoutePaths.friendsRequests),
            ),
            SocialActionTile(
              icon: Icons.leaderboard_outlined,
              label: l10n.groupsRanking,
              onTap: () => context.push(RoutePaths.userRanking),
            ),
          ],
        ),
        const Divider(),
        Expanded(
          child: ref
              .watch(friendsListProvider)
              .when(
                skipLoadingOnRefresh: true,
                loading: () => const VLoadingView(),
                error: (e, _) => ErrorView(
                  message: e.toAppError().message,
                  onRetry: () => ref.invalidate(friendsListProvider),
                ),
                data: (friends) {
                  // R13 (F3): pull-to-refresh on the list AND the empty state.
                  Future<void> onRefresh() =>
                      ref.read(friendsListProvider.notifier).refresh();
                  if (friends.isEmpty) {
                    return VRefreshable(
                      onRefresh: onRefresh,
                      child: VEmptyView(
                        icon: Icons.person_search,
                        title: l10n.friendsNoneYet,
                        description: l10n.friendsSearchPrompt,
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: friends.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final u = friends[i];
                        return ListTile(
                          dense: true,
                          leading: ProfileAvatar(
                            size: AppSpacing.avatar,
                            initials: _initials(u),
                            imageUrl: u.avatarUrl,
                          ),
                          title: Text('@${u.username}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push(RoutePaths.userProfile(u.id)),
                        );
                      },
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}
