import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/social/widgets/social_action_tile.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

/// The Grupos sub-tab of the Social screen (C-social, 2026-08-18): the
/// create-group + ranking actions and the user's groups list. White-only —
/// the actions are the shared compact [SocialActionTile] row (same widget as
/// the Amigos sub-tab, D-social-density); no violet accent (product: the
/// Social/ranking surfaces drop the purple).
///
/// Body-only by design: the Social shell owns the Scaffold + pill TabBar, so
/// this widget renders its column (the find-friends action and the
/// friends/requests shortcut row moved into the Amigos sub-tab).
class GroupsTab extends ConsumerWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.read(myGroupsProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverToBoxAdapter(
            child: SocialActionsRow(
              children: [
                SocialActionTile(
                  icon: Icons.group_add_outlined,
                  label: l10n.groupsCreateGroup,
                  onTap: () async {
                    await context.push(RoutePaths.groupCreate);
                    ref.invalidate(myGroupsProvider);
                  },
                ),
                SocialActionTile(
                  icon: Icons.leaderboard_outlined,
                  label: l10n.groupsRanking,
                  onTap: () => context.push(RoutePaths.groupsLeaderboard),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          ...ref
              .watch(myGroupsProvider)
              .when(
                skipLoadingOnRefresh: true,
                loading: () => const [
                  SliverToBoxAdapter(child: VSkeletonList()),
                ],
                error: (e, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                      message: e.toAppError().message,
                      onRetry: () => ref.invalidate(myGroupsProvider),
                    ),
                  ),
                ],
                data: (groups) {
                  if (groups.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: VEmptyView(
                          icon: Icons.group_outlined,
                          title: l10n.groupsNoneYet,
                          description: l10n.groupsNoneYetSubtitle,
                        ),
                      ),
                    ];
                  }
                  return [
                    SliverList.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final group = groups[i];
                        final name = group.name;
                        final initials = name.isEmpty
                            ? null
                            : name.substring(0, 1);
                        final myRole = group.myRole;
                        final myStatus = group.myStatus;
                        return ListTile(
                          dense: true,
                          leading: ProfileAvatar(
                            size: AppSpacing.avatar,
                            initials: initials,
                            imageUrl: group.coverUrl,
                          ),
                          title: Text(
                            name,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          subtitle: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (myStatus == 'invited') ...[
                                VBadge(label: l10n.groupsInvitePending),
                                const SizedBox(width: 4),
                              ],
                              if (myRole != null && myRole != 'member') ...[
                                VBadge(label: myRole),
                                const SizedBox(width: 4),
                              ],
                              const VShardIcon(size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${group.groupShards}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push(RoutePaths.groupDetail(group.id)),
                        );
                      },
                    ),
                  ];
                },
              ),
        ],
      ),
    );
  }
}
