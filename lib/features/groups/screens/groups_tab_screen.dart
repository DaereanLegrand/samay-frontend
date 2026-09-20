import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

/// The Grupos segment of the Social tab (redesign 2026-09-20).
///
/// Big-image group cards — the group cover leads, the name and shard count
/// follow with no button chrome — replacing the old action-tile row + dense
/// ListTiles. The whole card is tappable. Creating a group lives in the
/// Social header ("+") and in this list's empty state.
///
/// Body-only by design: the Social shell owns the Scaffold + pill TabBar.
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
                          actionLabel: l10n.groupsCreateGroupAction,
                          onAction: () async {
                            await context.push(RoutePaths.groupCreate);
                            ref.invalidate(myGroupsProvider);
                          },
                        ),
                      ),
                    ];
                  }
                  return [
                    SliverList.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, i) => _GroupCard(group: groups[i]),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.lg),
                    ),
                  ];
                },
              ),
        ],
      ),
    );
  }
}

/// One group: a full-bleed cover (or an icon placeholder), then the name and
/// shard count. The whole card opens the group.
class _GroupCard extends StatelessWidget {
  final Group group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasCover = group.coverUrl != null && group.coverUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: InkWell(
        onTap: () => context.push(RoutePaths.groupDetail(group.id)),
        child: VCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasCover)
                VNetworkImage(
                  imageUrl: group.coverUrl!,
                  height: 160,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  height: 160,
                  color: AppColors.surfaceAlt,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.group,
                    size: AppIconSizes.xl,
                    color: AppColors.muted,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const VShardIcon(size: AppIconSizes.xs),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${group.groupShards}',
                          style: const TextStyle(
                            color: AppColors.mutedStrong,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (group.myStatus == 'invited') ...[
                      const SizedBox(height: AppSpacing.sm),
                      VBadge(label: l10n.groupsInvitePending),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
