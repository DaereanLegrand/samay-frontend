import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/router/page_insets.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// The Amigos segment of the Social tab.
///
/// Large-avatar rows — a 56px avatar beside the @username — replacing the old
/// action-tile row + dense ListTiles. Requests live in the Social header
/// (person-add with the pending badge); finding people lives in the header
/// search and in this list's empty state.
///
/// Body-only by design: the Social shell owns the Scaffold + pill TabBar.
class AmigosTab extends ConsumerWidget {
  const AmigosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.read(friendsListProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          ...ref
              .watch(friendsListProvider)
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
                      onRetry: () => ref.invalidate(friendsListProvider),
                    ),
                  ),
                ],
                data: (friends) {
                  if (friends.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: VEmptyView(
                          icon: Icons.person_search,
                          title: l10n.friendsNoneYet,
                          description: l10n.friendsSearchPrompt,
                          actionLabel: l10n.socialSearchTooltip,
                          onAction: () => context.push(RoutePaths.userSearch),
                        ),
                      ),
                    ];
                  }
                  return [
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.lg),
                    ),
                    SliverList.separated(
                      itemCount: friends.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: context.palette.hairline),
                      itemBuilder: (_, i) => _FriendRow(user: friends[i]),
                    ),
                  ];
                },
              ),
          // Clear the floating shell nav bar so the last row can scroll above
          // it (nav-bar height + 16).
          SliverToBoxAdapter(
            child: SizedBox(height: pageBottomInset(context)),
          ),
        ],
      ),
    );
  }
}

/// One friend: a large avatar + the @username. The whole row opens the
/// public profile.
class _FriendRow extends StatelessWidget {
  final UserProfile user;

  const _FriendRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(RoutePaths.userProfile(user.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.listRowVertical,
        ),
        child: Row(
          children: [
            ProfileAvatar(
              size: AppSpacing.avatarMedium,
              initials: _initials(user),
              imageUrl: user.avatarUrl,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                '@${user.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // an empty (non-null) username would RangeError on
  // substring — the '?' initial fallback.
  static String _initials(UserProfile user) {
    final username = user.username;
    return username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();
  }
}
