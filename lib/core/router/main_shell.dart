import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';

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

class MainShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const MainShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(mainShellTabs[index].path),
        items: [
          for (var i = 0; i < mainShellTabs.length; i++)
            BottomNavigationBarItem(
              icon: Icon(mainShellTabs[i].icon),
              label: _tabLabel(l10n, i),
            ),
        ],
      ),
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
