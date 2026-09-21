import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/models/group_member.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/feed/widgets/avatar_physics_cluster.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// The Grupos segment of the Social tab (redesign 2026-09-20).
///
/// A row list: the text block (name + member count) leads on the left, the
/// group cover (or an icon placeholder) sits right-aligned as a thumbnail.
/// No card chrome and no per-row buttons — the whole row opens the group.
/// Creating a group lives in the Social header ("+") and in the empty state.
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
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: VLoadingView(),
                  ),
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
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.lg),
                    ),
                    SliverList.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.hairline),
                      itemBuilder: (_, i) => _GroupRow(group: groups[i]),
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

/// Group cover thumbnail side as a FRACTION of the row's content width, so it
/// scales with the viewport instead of a fixed dp. 1.5× the previous fixed
/// 112px thumbnail against the ~354px content width (112/354 × 1.5 ≈ 0.475).
const double _kGroupThumbFraction = 0.475;

/// Height of the members bubble cluster under a group row's text.
const double _kGroupClusterHeight = 68;

/// One group row: the name + member count on the left, the cover thumbnail
/// (or an icon placeholder) right-aligned. Under the text block, the active
/// members render as a downward-gravity bubble cluster of their profile pics
/// (2026-09-20 directive). The whole row opens the group.
class _GroupRow extends ConsumerWidget {
  final Group group;

  const _GroupRow({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final members =
        ref.watch(groupMembersProvider(group.id)).valueOrNull ??
        const <GroupMember>[];
    final avatars = [
      for (final member in members)
        ClusterAvatar(
          id: member.userId,
          username: member.username ?? '',
          avatarUrl: member.avatarUrl,
        ),
    ];
    return InkWell(
      onTap: () => context.push(RoutePaths.groupDetail(group.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.listRowVertical,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Width-dependent thumbnail: it is a fraction of the row's content
            // width, never a fixed size.
            final thumbSize = constraints.maxWidth * _kGroupThumbFraction;
            return Row(
              children: [
                Expanded(
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
                          const Icon(
                            Icons.group_outlined,
                            size: AppIconSizes.sm,
                            color: AppColors.mutedStrong,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l10n.groupsMembersCountShort(group.memberCount),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.mutedStrong),
                          ),
                          if (group.myStatus == 'invited') ...[
                            const SizedBox(width: AppSpacing.sm),
                            VBadge(label: l10n.groupsInvitePending),
                          ],
                        ],
                      ),
                      if (avatars.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AvatarPhysicsCluster(
                          participants: avatars,
                          height: _kGroupClusterHeight,
                          gravity: ClusterGravity.down,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                _GroupThumbnail(coverUrl: group.coverUrl, size: thumbSize),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The group cover as a right-aligned thumbnail (or a muted `surfaceAlt`
/// square with a group glyph when the group has no cover). Slightly rounded
/// and clipped, with its left edge dissolving into the black background.
class _GroupThumbnail extends StatelessWidget {
  final String? coverUrl;
  final double size;

  const _GroupThumbnail({this.coverUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final hasCover = coverUrl != null && coverUrl!.isNotEmpty;
    return SizedBox(
      width: size,
      height: size,
      child: _dissolveLeftEdge(
        hasCover
            ? VNetworkImage(imageUrl: coverUrl!, fit: BoxFit.cover)
            : Container(
                color: AppColors.surfaceAlt,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.group,
                  size: AppIconSizes.xxl,
                  color: AppColors.muted,
                ),
              ),
      ),
    );
  }

  /// Slightly rounds + clips [child] and fades its LEFT edge to transparent so
  /// it dissolves into the black background (`BlendMode.dstIn` keeps the
  /// opaque right side; only the left ~8% fades out — narrowed 2026-09-20).
  static Widget _dissolveLeftEdge(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.white, Colors.white],
          stops: [0, 0.08, 1],
        ).createShader(rect),
        child: child,
      ),
    );
  }
}
