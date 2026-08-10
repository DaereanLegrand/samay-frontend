import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

class MyGroupsScreen extends ConsumerWidget {
  const MyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: VButton(
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
                    onPressed: () => context.push(RoutePaths.groupsLeaderboard),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => context.push(RoutePaths.friendsList),
                  icon: const Icon(Icons.people, size: 16),
                  label: Text(l10n.commonFriends),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => context.push(RoutePaths.friendsRequests),
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: Text(l10n.groupsRequests),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ref.watch(myGroupsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toAppError().message,
                onRetry: () => ref.invalidate(myGroupsProvider),
              ),
              data: (groups) {
                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.groupsNoneYet,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        Text(l10n.groupsNoneYetSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    return ListTile(
                      leading: g['cover_url'] != null
                          ? VNetworkImage(
                              imageUrl: g['cover_url'] as String,
                              width: 40,
                              height: 40,
                              borderRadius: BorderRadius.circular(20),
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.grey[800],
                              child: const Icon(Icons.group),
                            ),
                      title: Text(g['name'] as String? ?? ''),
                      subtitle: Row(
                        children: [
                          if (g['my_role'] != 'member')
                            Text(
                              '${(g['my_role'] as String).toUpperCase()} · ',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          const VShardIcon(size: 12),
                          const SizedBox(width: 4),
                          Text('${g['group_shards'] ?? 0}',
                              style: const TextStyle(fontSize: 12)),
                          if (g['rank_bracket'] != null) ...[
                            const SizedBox(width: 8),
                            RankBadge(bracket: g['rank_bracket'] as String),
                          ],
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(RoutePaths.groupDetail(g['id'] as String)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
