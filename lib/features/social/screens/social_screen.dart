import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/screens/groups_tab_screen.dart';
import 'package:samay/features/social/screens/amigos_tab_screen.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_pill_tab_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// The Social tab root.
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
      backgroundColor: context.palette.background,
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
              bottom: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.screenHorizontal,
                  right: AppSpacing.screenHorizontal,
                  top: _kSegmentInsetTop,
                  bottom: _kSegmentInsetBottom,
                ),
                child: VPillTabBar(
                  key: const ValueKey('socialSegmentedTabBar'),
                  controller: _tabController,
                  labels: [l10n.socialTabGroups, l10n.socialTabFriends],
                ),
              ),
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

/// Top inset of the segment band — the gap between the page Header title row
/// and the switch.
const double _kSegmentInsetTop = AppSpacing.lg;

/// Bottom inset of the segment band (breathing room above the list content).
const double _kSegmentInsetBottom = AppSpacing.xs;

/// Height of the segmented band (track + top/bottom inset).
const double _kSegmentTabBarHeight =
    VPillTabBar.trackHeight + _kSegmentInsetTop + _kSegmentInsetBottom;

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
