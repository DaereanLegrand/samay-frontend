# 2026-08-17 — Avatar display + member-row navigation fix (AVATAR)

## What was built

Wired avatar photos into every screen that was fetching `avatar_url` but
never rendering it, and made group member rows navigate to the member's
public profile.

### Root causes

1. **Perfil-tab hero** — `lib/features/profile/screens/profile_screen.dart`
   called `ProfileAvatar(initials:)` with only initials. The own-row select
   already fetches `avatar_url` (`user_service.getUserProfile`), and the
   provider returns it (`profile?['avatar_url']`) — it was just never passed
   as `imageUrl`.
2. **Group member lists** — two gaps:
   - `GroupService.getGroupMembers` selected only
     `users:user_search_view!inner(username)` — `avatar_url` was never
     fetched from the barrier view (it exposes `avatar_url`, added in
     `20260815000001_user_view_bio.sql`).
   - Both consumer UIs (standalone `GroupMembersScreen` and the detail
     members tab `_MemberTile`) fed only initials to `ProfileAvatar`.
3. **Member-row click did nothing for non-admins** — the standalone screen's
   `onTap` was `null` unless `_canAct`; admins got the manage sheet. Nobody
   navigated to the member's profile, even though
   `RoutePaths.userProfile(userId)` exists and friends/search/notifications/
   party-finder reach it.

### Fixes (TDD — RED first, 11 files)

- `profile_screen.dart` — hero `ProfileAvatar` now passes
  `imageUrl: profile?['avatar_url']`.
- `public_profile_screen.dart` — same-class fix: hero avatar passes the
  already-fetched `p?['avatar_url']`.
- `group_service.dart` — `getGroupMembers` select joins
  `users:user_search_view!inner(username, avatar_url)`.
- `shards_service.dart` — `getGroupContributions` select joins
  `...!inner(username, avatar_url)` so the contributors subsection renders
  photos too.
- `group_members_screen.dart` — tile avatar passes the joined `avatar_url`;
  **row tap always navigates** to `RoutePaths.userProfile(userId)`; the
  admin manage sheet moves to a trailing `more_horiz` `IconButton` (shown
  only when `_canAct`).
- `group_detail_screen.dart` — `_MemberTile`/`_RowMember`/`_ContributorTile`
  carry `avatarUrl`; row tap navigates to the profile; trailing ellipsis
  opens the sheet for admins; the sheet's `users` map carries `avatar_url`.
- `member_actions_sheet.dart` — sheet avatar renders the member photo from
  `member['users']['avatar_url']`.

### Tests (added/updated, all green)

- `test/services/group_service_test.dart` — getGroupMembers mock + exact
  select-string verify include `avatar_url` (`_avatarUrl` const added).
- `test/services/shards_service_test.dart` — getGroupContributions mock now
  carries `avatar_url`.
- `test/features/groups/flow_test.dart` — 5 R17 admin/non-admin tests now
  tap the trailing `more_horiz` IconButton instead of the row text; new
  `_pumpGroupMembers` router harness; 2 new tests assert a member row tap
  lands on `/user/:userId` (standalone + detail members tab).
- `test/features/groups/restyle_test.dart` — members-tab + standalone
  screens assert `VNetworkImage` renders when `users.avatar_url` present.
- `test/features/profile/restyle_test.dart` — `_profileOverrides` accepts a
  profile map; ProfileScreen hero and PublicProfileScreen hero assert the
  stored photo renders via `VNetworkImage`.

## Decisions

- **Row tap = navigation; ellipsis = admin actions** (user-confirmed):
  row tap opens the member's public profile for everyone; the trailing
  `more_horiz` icon (admin rows only) opens the R17 manage sheet. Matches
  the friends/search list convention (`friends_list_screen` pumps
  `RoutePaths.userProfile` on row tap).
- No DB migration needed — `user_search_view` already exposes `avatar_url`.

## Commands run

```bash
flutter test test/services/group_service_test.dart test/services/shards_service_test.dart   # 46 pass
flutter test test/features/groups/flow_test.dart test/features/groups/restyle_test.dart     # 40 pass
flutter test test/features/profile/restyle_test.dart test/features/profile/avatar_flow_test.dart  # 31 pass
flutter test                                                            # 2472 pass / 0 failures (baseline 2440 + new tests)
dart analyze                                                           # no issues in touched files
go test ./...                                                          # ok (5 pkgs, cached)
```

## MISTAKE / gotcha

- The `_MemberTile`/members tests previously tapped `find.text('lucas')` to
  open the sheet. After moving sheet access behind the ellipsis, those taps
  now trigger navigation — and a plain `MaterialApp(home:)` harness throws
  "no GoRouter in context". The admin tests had to switch to
  `find.byIcon(Icons.more_horiz)`, and the navigation assertions need a real
  router (`_pumpGroupMembers`). Web-search-able if a future change reverts
  the interaction.

## Lint cleanup (same day)

The repo's `dart analyze` was 32 issues (baseline claim 0). All were
pre-existing, split 10 warnings (`unused_element`/`unused_import`) + 22
`prefer_const_constructors` infos across 13 files. All fixed:

- **Warnings** — removed unused `_event()` map builders in
  `integration_test/events_flow_test.dart` + `photos_flow_test.dart`; unused
  `material` imports in `friends_flow_test.dart`/`groups_flow_test.dart`;
  unused `dart:async` + `_MockNavigatorKey` in `deep_link_handler_test.dart`;
  unused `event.dart` imports in `create_event_test.dart` +
  `event_service_test.dart`; unused `_MutableGroupMembersNotifier` +
  `_StubGroupDetailCombinedNotifier` stubs in `group_detail_refresh_test.dart`.
- **Infos** — `const` added to already-const-constructible `UnauthorizedError`,
  `ServerError`, `NotFoundError` invocations in `error_mapper.dart`,
  `error_mapper_test.dart`, `show_app_error_test.dart`, `async_ops_test.dart`,
  `integration_test/error_flow_test.dart`.

Final gate: `dart analyze` → **No issues found**, `flutter test` → **2472
pass / 0 failures**.