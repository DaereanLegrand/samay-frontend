import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/profile/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_aurora.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_refreshable.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

class MyGroupsScreen extends ConsumerWidget {
  const MyGroupsScreen({super.key});

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
                .where((r) => r['type'] == 'received')
                .length ??
            0) +
        (ref.watch(groupInvitesProvider).valueOrNull?.length ?? 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: l10n.groupsTooltipFindFriends,
            onPressed: () => context.push(RoutePaths.userSearch),
          ),
        ],
      ),
      body: VAurora(
        gradients: const [AppGradients.violet],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // XL-17 (Gemma round 2, 09_groups: "reduce the violet
                  // everywhere"): one violet accent per screen — the primary
                  // CTA. The ranking entry drops to neutral outlined.
                  Expanded(
                    child: VButton.glowAccent(
                      filled: true,
                      gradient: AppGradients.violet,
                      label: l10n.groupsCreateGroup,
                      onPressed: () async {
                        await context.push(RoutePaths.groupCreate);
                        ref.invalidate(myGroupsProvider);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: VButton(
                      label: l10n.groupsRanking,
                      onPressed: () =>
                          context.push(RoutePaths.groupsLeaderboard),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // U-19: `Wrap` instead of a `Row` — at ≥1.5× text scale the two
              // icon buttons overflowed 320px-wide screens (§7.3: buttons grow;
              // they flow to a second line instead of clipping).
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => context.push(RoutePaths.friendsList),
                    icon: const Icon(Icons.people, size: 16),
                    label: Text(l10n.commonFriends),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(RoutePaths.friendsRequests),
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.groupsRequests),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 4),
                          VCountBadge(count: pendingCount),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ref
                  .watch(myGroupsProvider)
                  .when(
                    // U-22 (§5.8): the first load shows the avatar+lines skeleton
                    // instead of the bare spinner; pull-to-refresh keeps the list
                    // visible (skipLoadingOnRefresh — the skeleton only ever
                    // stands in when there is nothing on screen).
                    skipLoadingOnRefresh: true,
                    loading: () => const VSkeletonList(),
                    error: (e, _) => ErrorView(
                      message: e.toAppError().message,
                      onRetry: () => ref.invalidate(myGroupsProvider),
                    ),
                    data: (groups) {
                      // R13 (F3): pull-to-refresh on the groups list AND its
                      // empty state.
                      Future<void> onRefresh() =>
                          ref.read(myGroupsProvider.notifier).refresh();
                      if (groups.isEmpty) {
                        return VRefreshable(
                          onRefresh: onRefresh,
                          child: VEmptyView(
                            icon: Icons.group_outlined,
                            title: l10n.groupsNoneYet,
                            description: l10n.groupsNoneYetSubtitle,
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: onRefresh,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: groups.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final g = groups[i];
                            final name = g['name'] as String? ?? '';
                            final initials = name.isEmpty
                                ? null
                                : name.substring(0, 1);
                            // U-24: the role badge renders only when the row
                            // actually carries `my_role` — a row missing the
                            // key (or with a null value) previously crashed
                            // the tile with a null cast TypeError (U-22's
                            // report); the member default renders no badge.
                            final myRole = g['my_role'] as String?;
                            // XL-17: one hairline per row — the glass card
                            // and its glow are gone; the subtitle keeps role
                            // + shards only (the rank badge belongs to the
                            // leaderboard, not every tile).
                            return ListTile(
                              dense: true,
                              leading: ProfileAvatar(
                                size: AppSpacing.avatar,
                                initials: initials,
                                imageUrl: g['cover_url'] as String?,
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
                                  if (myRole != null &&
                                      myRole != 'member') ...[
                                    VBadge(label: myRole),
                                    const SizedBox(width: 4),
                                  ],
                                  const VShardIcon(size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${g['group_shards'] ?? 0}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(
                                RoutePaths.groupDetail(g['id'] as String),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
