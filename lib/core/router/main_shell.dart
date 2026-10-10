import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/chat/providers/inbox_realtime_listener.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/friends/providers/friendships_realtime_listener.dart';
import 'package:samay/features/groups/providers/group_memberships_realtime_listener.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/minigames/providers/minigame_invites_realtime_listener.dart';
import 'package:samay/features/minigames/providers/minigame_sessions_realtime_listener.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/notifications/providers/push_notification_listener.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_tab_fade.dart';

class TabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;

  const TabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });
}

const mainShellTabs = <TabItem>[
  TabItem(
    label: 'Feed',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
    path: RoutePaths.mainFeed,
  ),
  TabItem(
    label: 'Social',
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    path: RoutePaths.mainGroups,
  ),
  TabItem(
    label: 'Games',
    icon: Icons.sports_esports_outlined,
    selectedIcon: Icons.sports_esports,
    path: RoutePaths.mainGames,
  ),
  TabItem(
    label: 'Eventos',
    icon: Icons.event_outlined,
    selectedIcon: Icons.event,
    path: RoutePaths.mainEvents,
  ),
  TabItem(
    label: 'Notis',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    path: RoutePaths.mainNotifications,
  ),
  TabItem(
    label: 'Perfil',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    path: RoutePaths.mainProfile,
  ),
];

int shellIndexFor(String location) {
  if (location.startsWith(RoutePaths.mainGroups)) return 1;
  if (location.startsWith(RoutePaths.mainGames)) return 2;
  if (location.startsWith(RoutePaths.mainEvents)) return 3;
  if (location.startsWith(RoutePaths.mainNotifications)) return 4;
  if (location.startsWith(RoutePaths.mainProfile)) return 5;
  return 0;
}

/// The Social tab's pending counter — received friend requests + group
/// invites. Minigame invites moved to the Games tab badge, so
/// each tab owns the red circle for its own slice.
final pendingCountsProvider = Provider<int>((ref) {
  final requests = ref.watch(
    friendRequestsProvider.select(
      (v) =>
          v.valueOrNull?.requests
              .where((r) => r.type == 'received')
              .length ??
          0,
    ),
  );
  final invites = ref.watch(
    groupInvitesProvider.select((v) => v.valueOrNull?.length ?? 0),
  );
  return requests + invites;
});

class MainShell extends ConsumerWidget {
  final Widget child;
  final int currentIndex;

  const MainShell({super.key, required this.child, required this.currentIndex});

  /// Bottom inset for shell-tab bodies (the reference app's `navBarInset` pattern,
  /// Premium pill): the tab content clears the floating nav bar
  /// instead of scrolling beneath it — `extendBody` draws the body under
  /// the bar, so every tab pads its bottom by this much.
  static double navBarInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + AppSpacing.md + 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final socialCount = ref.watch(pendingCountsProvider);
    final gamesCount = ref.watch(pendingMinigameInvitesProvider);
    // 150ms opacity fade-in on tab switch, keyed on the
    // tab index so every switch restarts it. No spatial motion (tabs have no
    // directional relationship — the reference app's fadeIn, without flutter_animate).
    // The shared `VTabFade` owns the reduced-motion contract
    // (`disableAnimations` → static) + the duration/curve tokens.
    final body = VTabFade(key: ValueKey(currentIndex), child: child);
    // Friendships + inbox + group memberships + minigame-invite + minigame-
    // session realtime: the listeners are mounted for the shell's lifetime —
    // invalidates the root providers on remote row events, so badges update
    // without pull.
    return Stack(
      children: [
        const FriendshipsRealtimeListener(),
        const InboxRealtimeListener(),
        const GroupMembershipsRealtimeListener(),
        const MinigameInvitesRealtimeListener(),
        const MinigameSessionsRealtimeListener(),
        const PushNotificationListener(),
        Scaffold(
          extendBody: true,
          body: body,
          // Premium floating pill: a rounded
          // liquid-glass bar with safe-area padding + a bottom inset so the
          // tab content never hides under it. Behavior is untouched: index,
          // taps, badge, fade.
          bottomNavigationBar: _FloatingNavBar(
            selectedIndex: currentIndex,
            badges: {1: socialCount, 2: gamesCount},
            onTap: (index) => context.go(mainShellTabs[index].path),
            l10n: l10n,
          ),
        ),
      ],
    );
  }
}

/// Premium floating pill nav bar — a faithful port of the reference app's Premium pill.
///
/// Geometry is identical to the reference app: a `SafeArea` → `Padding` (24,0,24,20) →
/// glass pill (blur 20, `surface` α0.1 fill, white α0.15 sheen, radius 14,
/// inner padding 6×6) → a
/// `spaceAround` `Row` of `AnimatedContainer` tabs (padding 8×8, radius 16).
/// The selected tab carries a 4×4 dot under the icon; because exactly one
/// tab is ALWAYS selected, the pill's height and width are constant — they
/// never change on tab switch.
class _FloatingNavBar extends ConsumerWidget {
  final int selectedIndex;

  /// Per-tab red-circle counts, keyed by tab index (absent = no badge).
  final Map<int, int> badges;
  final void Function(int) onTap;
  final AppLocalizations l10n;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.badges,
    required this.onTap,
    required this.l10n,
  });

  /// Compact pill radius so six tabs fit comfortably.
  static const double _radius = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                // the reference app's `PremiumCard` glass: the SAME recipe — a backdrop
                // blur with a nearly-transparent `surface` fill (alpha 0.1)
                // and a faint 0.15 white sheen. The earlier 0.85 alpha was a
                // mis-port and read as a solid black bar.
                color: AppColors.surface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < mainShellTabs.length; i++)
                    _tabItem(context, i),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One tab — compact anatomy for six tabs: `GestureDetector`
  /// (opaque hit) → `AnimatedContainer` (8×6 padding) → `Column` [icon stack,
  /// selected dot]. A tab with a pending [badges] count gains the red circle
  /// while the user is elsewhere.
  Widget _tabItem(BuildContext context, int index) {
    final selected = index == selectedIndex;
    final label = _tabLabel(l10n, index);
    final badge = badges[index] ?? 0;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: label,
          child: AnimatedContainer(
            duration: SamayDurations.standard,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected
                          ? mainShellTabs[index].selectedIcon
                          : mainShellTabs[index].icon,
                      color: selected ? AppColors.white : AppColors.muted,
                      size: 22,
                    ),
                    if (badge > 0 && selectedIndex != index)
                      Positioned(
                        right: -7,
                        top: -4,
                        child: VCountBadge(count: badge),
                      ),
                  ],
                ),
                // Selected indicator — the white icon + the 4×4 dot below it.
                if (selected)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Localized tab labels. The `TabItem.label` values in [mainShellTabs]
  /// stay as stable data keys (asserted by main_shell_test); the rendered
  /// text goes through ARB so it can be translated.
  static String _tabLabel(AppLocalizations l10n, int index) {
    return switch (index) {
      0 => l10n.shellFeed,
      1 => l10n.shellSocial,
      2 => l10n.shellGames,
      3 => l10n.shellEvents,
      4 => l10n.shellNotifications,
      5 => l10n.shellProfile,
      _ => mainShellTabs[index].label,
    };
  }
}
