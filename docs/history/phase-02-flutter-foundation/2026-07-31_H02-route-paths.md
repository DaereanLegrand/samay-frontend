# 2026-07-31 — H-02: Extract Raw String Route Paths into `RoutePaths` Constants Class

## What was built

- **`lib/core/router/route_paths.dart`** — new `abstract final class RoutePaths`:
  - 24 `static const` path constants: `welcome` (`/`), `login` (`/login`), `signup`
    (`/auth/signup`), `verify` (`/auth/verify`), `ageGate` (`/auth/age-gate`),
    `privacyTerms` (`/auth/privacy-terms`), `profileSetup` (`/auth/profile-setup`),
    `authPrefix` (`/auth/` — keeps trailing slash for the guard's `startsWith`),
    `mainFeed`, `mainGroups`, `mainEvents`, `mainNotifications`, `mainProfile`,
    `groupCreate` (`/group/create`), `groupsLeaderboard`, `userSearch`,
    `friendsRequests`, `friendsList`, `blockedUsers`, `subscriptions`, `partyFinder`,
    `settings`, `deleteAccount`, `profileEdit`.
  - 15 `static String` builders: `eventDetail`, `eventEdit`, `eventInvite`,
    `eventPhotos`, `eventCollage`, `eventInviteToken`, `groupDetail`, `groupMembers`,
    `donateToGroup`, `createGroupEvent`, `inviteToGroup`, `chat`, `userProfile`, `qr`,
    `scanner` — each interpolates a single id/token into the exact path shape.
- **`lib/core/router/app_router.dart`** — every `GoRoute(path:)` now references
  `RoutePaths` (constants for static paths; for parameterized patterns the builder is
  called with the literal param name, e.g. `RoutePaths.eventDetail(':eventId')` →
  `/event/:eventId`). `initialLocation` → `RoutePaths.login`. The ShellRoute's
  `onTap` tab-switch `context.go(...)` calls also use the constants. Route order,
  builders, redirects, `pathParameters` unwraps, and `extra` casts untouched.
- **`lib/core/router/auth_guard.dart`** — `'/login'` → `RoutePaths.login`, `'/'` →
  `RoutePaths.welcome`, `startsWith('/auth/')` → `startsWith(RoutePaths.authPrefix)`,
  redirect targets → `RoutePaths.login` / `RoutePaths.signup` / `RoutePaths.mainFeed`.
  Behavior byte-identical (same values, same semantics).
- **28 call sites across 15 feature files** — all `context.push('/...')` /
  `context.go('/...')` replaced with `RoutePaths.*` references. Parameterized pushes
  pass an explicit cast: `RoutePaths.groupDetail(g['id'] as String)`,
  `RoutePaths.userProfile(u['id'] as String)`. `extra:` arguments untouched.
  Files: auth/welcome, auth/login, auth/signup_contact, auth/otp_verification,
  auth/age_gate, auth/privacy_terms, auth/profile_setup, profile/profile,
  profile/delete_account, profile/settings, groups/my_groups, groups/leaderboard,
  groups/group_detail, friends/search, friends/friends_list.
- **Tests (56 new, all passing)**:
  - `test/router/route_paths_test.dart` (18): every constant non-empty + starts
    with `/`; `authPrefix` == `'/auth/'`; all 15 builders interpolate to the exact
    strings from test plan §2.
  - `test/router/app_router_test.dart` (+38): new `RoutePaths coherence` group —
    all 24 statics + 15 builders pumped through the real router; asserts the
    expected screen type renders (never a go_router error, which would throw during
    `router.go` since the router has no `errorBuilder`). Public routes that redirect
    (`/`, `/login`) assert the redirect target (`FeedScreen`). Extra-requiring
    routes (`/auth/verify`, `/auth/privacy-terms`, `/auth/profile-setup`) are
    pumped with a valid `extra` map. Existing 16 tests updated to use `RoutePaths`
    (paths unchanged, so all assertions still hold).

## Decisions

- **`GoRoute` parameterized patterns use builders with the literal param name**
  (`RoutePaths.eventDetail(':eventId')`). This keeps one source of truth: the
  pattern string is produced by the same interpolation the call sites use, and the
  `path: '/` grep-proof holds.
- **`abstract final class`** with `static` members — Dart 3 idiom, matches the
  Juega reference in finding NAV-02 while preventing instantiation/subclassing.
- **Cast added at call sites**: `g['id'] as String` / `u['id'] as String` — the
  builders are `String`-typed, so raw-map call sites need an explicit cast (same
  cast semantics the `$g['id']` interpolation had).
- **Coherence tests reuse the H-01 harness untouched** (in-memory Supabase
  storages, `_FakeAuthNotifier` authenticated+hasProfile); only an optional `extra`
  parameter was added to `_pumpRoute`.
- **`/group/:groupId` pumped without `pumpAndSettle`**: with the mocked 400
  responses, `GroupDetailScreen._load` fails fast, `_group` stays `null`, and the
  screen shows an indeterminate spinner forever — `pumpAndSettle` would time out.
  The test pumps fixed frames and asserts `GroupDetailScreen` renders.
- **ShellRoute `tab.startsWith('/main/...')` index checks left as-is**: the spec
  explicitly forbade touching the ShellRoute structure, and the grep-proof patterns
  (`context.push/go('/`, `path: '/`) don't cover them. Converting them to
  `RoutePaths.mainGroups` etc. is a trivial future follow-up (NOTED below).
- **`authPrefix` keeps its trailing slash** so the auth guard's `startsWith` check
  behaves exactly as before (a bare `/auth` would match nothing).

## MISTAKE

- **MISTAKE (caught before commit)**: first draft of the coherence loop asserted
  `find.byType(VComingSoonScreen), findsWidgets` on every path — wrong for real
  screens (`FeedScreen`, `CreateGroupScreen`, …). Removed; the per-path widget-type
  assertion is the only assertion needed because an unresolvable route makes
  `router.go` throw during pump, failing the test automatically.
- **MISTAKE (caught before commit)**: initially planned to leave the 5 `context.go`
  calls in the ShellRoute `onTap` as raw strings because "builders" were listed as
  do-not-touch — but the grep-proof requires zero `context.go('/` in all of `lib/`.
  Resolved by replacing only the strings, not the builder logic.
- **MISTAKE (near-miss, verified instead)**: worried the uncommitted working-tree
  hunks in `search_screen.dart`, `donate_shards_screen.dart`, `edit_profile_screen.dart`
  (`e.toAppError().message` catch blocks) could be reverted by my edits. Verified via
  `git diff` before and after — hunks preserved byte-for-byte; the two files without
  route call sites were not edited at all.

## Pre-existing issues observed (NOT touched, out of scope)

- 23 pre-existing failing tests, identical set to the H-01 baseline:
  `auth_provider_test.dart` (3), `auth_screens_test.dart` (6), `profile_screens_test.dart`
  (1), `widget_test.dart` (1) — screens/notifiers touch `Supabase.instance` without
  init in the test env; `structure_test.dart` (12) — asserts directories that don't
  exist (finding L-13).
- `dart analyze` reports 19 info-level `use_build_context_synchronously` issues, all
  pre-existing; zero errors, zero warnings, none in new/modified files.
- ShellRoute `tab.startsWith('/main/...')` raw strings remain (see Decisions) —
  deferred; they are not navigation calls and not covered by the finding's greps.
- Test plan §2 said "23 static" constants; the spec lists 24 including `authPrefix`.
  Implemented all 24 per the spec; route_paths_test asserts 24.

## Commands Run

```bash
dart analyze                                   # 0 errors, 0 warnings, 19 pre-existing info
flutter test test/router/route_paths_test.dart test/router/app_router_test.dart
                                               # 72 passed (18 + 54)
flutter test                                   # 176 passed, 23 failed (all pre-existing baseline)
flutter test test/providers/auth_provider_test.dart test/features/auth_screens_test.dart \
  test/features/profile_screens_test.dart test/widget_test.dart test/structure_test.dart
                                               # 24 tests, 23 fail — confirms baseline set unchanged
rg -n "context\.(push|go)\('/" lib/            # no matches
rg -n "path: '/" lib/core/router/app_router.dart  # no matches
```

## Verification

- [x] `dart analyze` — zero errors; zero issues in new/modified files
- [x] `flutter test` — 176 passed (+56 new), 23 failed (all pre-existing, same set as H-01 baseline)
- [x] Grep-proof: zero `context.push('/` / `context.go('/` in `lib/`; zero `path: '/` in `app_router.dart`
- [x] Path VALUES identical before/after (constant → builder round-trips asserted in tests)
- [x] Auth guard behavior unchanged (same comparisons, same redirect targets)
- [x] Uncommitted `toAppError` hunks in 3 files preserved
- [x] Docs updated: `TODO.md` H-02 ✅
