import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/screens/groups_tab_screen.dart';
import 'package:samay/features/social/screens/amigos_tab_screen.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The Social tab root (redesign 2026-09-20).
///
/// Minimal: the pill sub-tabs (Grupos | Amigos) stay, but the per-segment
/// button-tile rows are gone. The header carries search + the single shared
/// Rankings entry, plus ONE contextual action — "+" (create group) on Grupos,
/// the requests icon (with the pending count) on Amigos. The nav-bar Social
/// badge keeps requests visible whichever segment is active.
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _index = 0;

  static const int _groupsTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index != _index) {
      setState(() => _index = _tabController.index);
    }
  }

  /// Opens the create-group flow, then refreshes the list so a new group
  /// appears without waiting for the realtime listener.
  Future<void> _createGroup() async {
    await context.push(RoutePaths.groupCreate);
    ref.invalidate(myGroupsProvider);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pendingCount = ref.watch(pendingCountsProvider);
    return Scaffold(
      backgroundColor: AppColors.discoBlack,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: VHeaderSliver(
              // The page Header — the one verbatim/lowercase surface.
              title: l10n.socialTitle,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.socialSearchTooltip,
                  onPressed: () => context.push(RoutePaths.userSearch),
                ),
                if (_index == _groupsTab)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: l10n.groupsCreateGroupAction,
                    onPressed: _createGroup,
                  )
                else
                  _RequestsButton(count: pendingCount),
                IconButton(
                  icon: const Icon(Icons.emoji_events_outlined),
                  tooltip: l10n.socialRankingTitle,
                  onPressed: () => context.push(RoutePaths.rankings),
                ),
              ],
              bottomHeight: _kPillTabBarHeight,
              bottom: _PillTabBar(controller: _tabController, l10n: l10n),
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

/// Height of the pill tab-bar track (40 content + 2 top + 2 bottom margins).
const double _kPillTabBarHeight = 44;

/// The Juega-style pill TabBar: a rounded `surfaceAlt` track wrapping a
/// `TabBar` whose indicator is a white pill (selected label flips to black).
class _PillTabBar extends StatelessWidget {
  final TabController controller;
  final AppLocalizations l10n;

  const _PillTabBar({required this.controller, required this.l10n});

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
          Tab(text: l10n.socialTabFriends),
        ],
      ),
    );
  }
}

/// The requests action on the Amigos segment: a person-add icon carrying the
/// pending count (received friend requests + group invites) as a red circle.
class _RequestsButton extends StatelessWidget {
  final int count;

  const _RequestsButton({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.person_add_alt),
          tooltip: l10n.groupsRequests,
          onPressed: () => context.push(RoutePaths.friendsRequests),
        ),
        if (count > 0)
          Positioned(right: 4, top: 4, child: VCountBadge(count: count)),
      ],
    );
  }
}
