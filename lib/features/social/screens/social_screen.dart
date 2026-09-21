import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
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
              bottomHeight: _kSegmentTabBarHeight,
              bottom: _SegmentedTabBar(controller: _tabController, l10n: l10n),
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

/// Segmented tab-bar track height (transparent tap band; no fill).
const double _kSegmentTrackHeight = 40;

/// Top inset of the segment band — the gap between the page Header title row
/// and the switch.
const double _kSegmentInsetTop = AppSpacing.lg;

/// Bottom inset of the segment band (breathing room above the list content).
const double _kSegmentInsetBottom = AppSpacing.xs;

/// Fully-rounded outline radius of the selected segment (half the track).
const double _kSegmentRadius = _kSegmentTrackHeight / 2;

/// Height of the segmented band (track + top/bottom inset).
const double _kSegmentTabBarHeight =
    _kSegmentTrackHeight + _kSegmentInsetTop + _kSegmentInsetBottom;

/// The Social segmented control: no fills at all — the active segment is
/// marked by a full pill outline, every other segment is a plain white label.
class _SegmentedTabBar extends StatelessWidget {
  final TabController controller;
  final AppLocalizations l10n;

  const _SegmentedTabBar({required this.controller, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('socialSegmentedTabBar'),
      margin: const EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        top: _kSegmentInsetTop,
        bottom: _kSegmentInsetBottom,
      ),
      height: _kSegmentTrackHeight,
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          border: Border.all(color: AppColors.white),
          borderRadius: BorderRadius.circular(_kSegmentRadius),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.white,
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
          Positioned(
            right: AppSpacing.xs,
            top: AppSpacing.xs,
            child: VCountBadge(count: count),
          ),
      ],
    );
  }
}
