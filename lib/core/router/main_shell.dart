import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';

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
    label: 'Grupos',
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    path: RoutePaths.mainGroups,
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
  if (location.startsWith(RoutePaths.mainEvents)) return 2;
  if (location.startsWith(RoutePaths.mainNotifications)) return 3;
  if (location.startsWith(RoutePaths.mainProfile)) return 4;
  return 0;
}

/// R18 (F5 DIRECT): the shell's Grupos-tab pending counter — received friend
/// requests + group invites, derived from the two root providers the Grupos
/// tab already feeds on (the same count as its "Solicitudes" button). The
/// shell only *watches*: nothing new is fetched by mounting it.
final pendingCountsProvider = Provider<int>((ref) {
  final requests =
      ref.watch(friendRequestsProvider).valueOrNull?.requests
          .where((r) => r['type'] == 'received')
          .length ??
      0;
  final invites = ref.watch(groupInvitesProvider).valueOrNull?.length ?? 0;
  return requests + invites;
});

class MainShell extends ConsumerWidget {
  final Widget child;
  final int currentIndex;

  const MainShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pendingCount = ref.watch(pendingCountsProvider);
    // R19 (F13 DIRECT): 150ms opacity fade-in on tab switch, keyed on the
    // tab index so every switch restarts it. No spatial motion (tabs have no
    // directional relationship — Juega's fadeIn, without flutter_animate).
    // Reduced motion (`disableAnimations`) → static, no animation (U-18's
    // contract; duration/curve from the U-18 token).
    final animate = !MediaQuery.disableAnimationsOf(context);
    final body = animate
        ? _ShellTabFade(key: ValueKey(currentIndex), child: child)
        : child;
    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(mainShellTabs[index].path),
        items: [
          for (var i = 0; i < mainShellTabs.length; i++)
            BottomNavigationBarItem(
              // R18: the Grupos tab icon carries the pending badge (U-16's
              // `VCountBadge` — tiny, accent-scale per §7.2). The badge shows
              // only while the user is NOT on the tab (Juega hides its feed
              // badge the same way) — the active tab renders `activeIcon`,
              // which never carries it.
              icon: _tabIcon(context, i, pendingCount),
              activeIcon: Icon(mainShellTabs[i].selectedIcon),
              label: _tabLabel(l10n, i),
            ),
        ],
      ),
    );
  }

  /// The unselected-tab icon; the Grupos one gains the R18 pending badge
  /// when there is something pending and the user is elsewhere.
  Widget _tabIcon(BuildContext context, int index, int pendingCount) {
    final icon = Icon(mainShellTabs[index].icon);
    if (index != 1 || pendingCount <= 0 || currentIndex == 1) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -6,
          top: -6,
          child: VCountBadge(count: pendingCount),
        ),
      ],
    );
  }

  /// Localized tab labels. The `TabItem.label` values in [mainShellTabs]
  /// stay as stable data keys (asserted by main_shell_test); the rendered
  /// text goes through ARB so it can be translated.
  static String _tabLabel(AppLocalizations l10n, int index) {
    return switch (index) {
      0 => l10n.shellFeed,
      1 => l10n.shellGroups,
      2 => l10n.shellEvents,
      3 => l10n.shellNotifications,
      4 => l10n.shellProfile,
      _ => mainShellTabs[index].label,
    };
  }
}

/// R19: one-shot 150ms easeOutCubic fade-in keyed on the shell tab index —
/// a new `State` per key restarts the animation. Deliberately NOT an
/// `AnimatedSwitcher`: the switcher keeps the outgoing tab in the tree
/// during the transition, and the go_router nested Navigator carries
/// GlobalKey'd route entries — two live Navigators collide (duplicate
/// GlobalKeys). A fade-in disposes the old tab immediately (Juega's
/// `fadeIn(...)` semantics).
class _ShellTabFade extends StatefulWidget {
  final Widget child;

  const _ShellTabFade({super.key, required this.child});

  @override
  State<_ShellTabFade> createState() => _ShellTabFadeState();
}

class _ShellTabFadeState extends State<_ShellTabFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.fast,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: SamayDurations.defaultCurve,
      ),
      child: widget.child,
    );
  }
}
