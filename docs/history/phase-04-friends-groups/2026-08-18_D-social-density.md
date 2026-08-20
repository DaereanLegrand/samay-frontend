# 2026-08-18 — D-social-density

## What was built
- New shared `SocialActionTile` + `SocialActionsRow` in
  `lib/features/social/widgets/social_action_tile.dart` (created the
  `widgets/` subdir). One compact white-only hairline tile (height 40,
  radius 10, `Border.all(AppColors.hairline)`, icon 20 + `labelLarge`,
  optional `badge` → `VCountBadge`) used by BOTH Social sub-tabs.
- `lib/features/social/screens/social_screen.dart`: slimmed the `_PillTabBar`
  (margin `fromLTRB(12,2,12,6)`, padding `all(2)`, `Tab(height: 18)` +
  `labelPadding` zero + `labelMedium` labels) so the outer pill (incl.
  margins, keyed `socialPillTabBar`) measures **32.0px** (was ~68px); the
  lupa (`Icons.search`) is now ALWAYS in the AppBar actions (both sub-tabs).
  Dropped the now dead `_onTabChanged` listener.
- `lib/features/groups/screens/my_groups_screen.dart`: replaced the
  `VButton.dark` + outlined `VButton` row with `SocialActionsRow` +
  `SocialActionTile` ("Crear grupo" `Icons.group_add_outlined` →
  `RoutePaths.groupCreate` + myGroups invalidation; "Ranking"
  `Icons.leaderboard_outlined` → `RoutePaths.groupsLeaderboard`).
- `lib/features/social/screens/amigos_tab.dart`: replaced `_EntryTile` with
  the shared tile ("Solicitudes" `Icons.person_add_outlined` + pending
  badge → `RoutePaths.friendsRequests`; "Ranking" → `RoutePaths.userRanking`).
  Removed the now-private `_EntryTile` and its unused imports.

## Decisions
- One shared tile + row widget so Grupos/Amigos entry rows are byte-identical
  (requirement 3) and compact (measured **40.0px** vs 64px tiles / taller
  VButton row).
- Pill sized to 32.0px total (margin 8 + padding 4 + TabBar 20) — comfortably
  under the 34px ceiling while keeping `labelMedium` (12px) legible.
- Reused existing ARB keys only (`groupsCreateGroup`, `groupsRanking`,
  `groupsRequests`) — `lib/l10n/**` untouched.
- `test/features/groups/groups_screens_test.dart` does not exist; the real
  `test/features/groups_screens_test.dart` MyGroupsScreen group has no
  VButton assertions — untouched. `test/features/friends/flow_test.dart`
  badge tests keep working via `VCountBadge` in the shared tile — untouched.

## MISTAKE / gotchas
- **This Flutter's `TabBar` has NO `height` param** (checked `tabs.dart`
  ~line 1008) — passing `height: 20` to the TabBar fails to compile. The
  shrink must come from `Tab(height: ...)` (each Tab's `SizedBox`), else each
  tab falls back to `kTabHeight` 46. Also, the default `indicatorWeight` 2
  adds a bottom Padding to every tab — with `Tab(height:18)` + padding 2 that
  made the bar 22, so the first build measured 34.0 (at the ceiling); zeroing
  `labelPadding` landed the final 32.0.
- Measured the outer keyed Container (its render object is the margin
  `Padding`), so `getSize` includes margins — matches the requirement.

## Commands
```
tools/agent_lock.sh acquire <path> --owner D-social-density  (7 paths)
flutter test test/features/social/social_screen_test.dart test/features/groups/restyle_test.dart  # RED → GREEN
flutter test test/features/social/social_screen_test.dart test/features/groups/restyle_test.dart test/features/groups_screens_test.dart test/features/friends/flow_test.dart  # 95 pass
flutter test  # full suite 2484/2484
dart analyze  # 0 issues
dart format lib/features/social/widgets/social_action_tile.dart lib/features/social/screens/social_screen.dart lib/features/groups/screens/my_groups_screen.dart lib/features/social/screens/amigos_tab.dart test/features/social/social_screen_test.dart test/features/groups/restyle_test.dart
```
