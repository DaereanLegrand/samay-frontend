import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/screens/groups_tab_screen.dart';
import 'package:samay/features/social/screens/amigos_tab_screen.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The Social tab root (C-social, 2026-08-18): a Juega-style inner PILL
/// TabBar with two sub-tabs — "Grupos" (create-group + ranking + my groups)
/// and "Amigos" (friends + solicitudes + ranking + the top-right lupa).
///
/// White-only: the pill is a neutral `surfaceAlt` track with a white rounded
/// indicator; no violet accent anywhere in the Social/ranking surfaces. The
/// shell's Grupos pending badge (friend requests + group invites) rides the
/// Amigos pill tab while the user is elsewhere. The lupa (user search) is a
/// top-right AppBar action on BOTH sub-tabs (D-social-density).
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pendingCount = ref.watch(pendingCountsProvider);
    return Scaffold(
      // iOS-style collapsing header ('social' title + pill tab bar pin and
      // collapse over the tab content as it scrolls — shared mechanism).
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: VHeaderSliver(
              title: l10n.socialTitle,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.socialSearchTooltip,
                  onPressed: () => context.push(RoutePaths.userSearch),
                ),
              ],
            ),
          ),
          // The pill tab bar stays pinned under the collapsing title.
          SliverPersistentHeader(
            pinned: true,
            delegate: _PillBarDelegate(
              tabController: _tabController,
              pendingCount: pendingCount,
              l10n: l10n,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [GroupsTab(), AmigosTab()],
        ),
      ),
    );
  }
}

/// Pinned sliver holding the pill [TabBar] under the collapsing title.
class _PillBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final int pendingCount;
  final AppLocalizations l10n;

  _PillBarDelegate({
    required this.tabController,
    required this.pendingCount,
    required this.l10n,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _PillTabBar(
      controller: tabController,
      pendingCount: pendingCount,
      l10n: l10n,
    );
  }

  @override
  bool shouldRebuild(covariant _PillBarDelegate oldDelegate) {
    return tabController != oldDelegate.tabController ||
        pendingCount != oldDelegate.pendingCount ||
        l10n != oldDelegate.l10n;
  }
}

/// The Juega-style pill TabBar: a rounded `surfaceAlt` track wrapping a
/// TabBar whose indicator is a white pill (selected label flips to black).
/// The Amigos tab carries the shell's pending-count badge (R18) while the
/// user is elsewhere. Lives in the body (below the titled AppBar), never in
/// the AppBar `bottom` — so the sub-tab content clears the OS status bar.
///
/// Simple-density posture: a fixed 40px track with tight 2px vertical
/// margins (`fromLTRB(12,2,12,2)`), `labelMedium` labels and a rounded
/// white indicator. The outer container (incl. margins) measures ≤ 44px;
/// tests pin it via the `socialPillTabBar` key.
class _PillTabBar extends StatelessWidget {
  final TabController controller;
  final int pendingCount;
  final AppLocalizations l10n;

  const _PillTabBar({
    required this.controller,
    required this.pendingCount,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('socialPillTabBar'),
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.discoBlack,
        unselectedLabelColor: AppColors.white,
        labelStyle: Theme.of(context).textTheme.labelMedium,
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        tabs: [
          Tab(text: l10n.socialTabGroups),
          Tab(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(l10n.socialTabFriends, softWrap: false),
                if (pendingCount > 0 && controller.index != 1)
                  Positioned(
                    right: -10,
                    top: -2,
                    child: VCountBadge(count: pendingCount),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
