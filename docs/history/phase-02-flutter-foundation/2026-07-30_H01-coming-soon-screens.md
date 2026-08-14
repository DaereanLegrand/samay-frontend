# 2026-07-30 — H-01: Replace Blank `Scaffold()` Placeholder Routes with Coming-Soon Screens

## What was built

- **`lib/shared/widgets/v_coming_soon.dart`** — reusable `VComingSoonScreen` widget:
  `VComingSoonScreen({required String title, required String description, bool showBackButton = true, IconData icon = Icons.construction})`.
  Renders a black `Scaffold` with an `AppBar` showing the feature `title`, a centered column with the
  `icon` (grey[800], size 56), the "Próximamente" headline, the feature `description`, and (when
  `showBackButton`) a `VButton.outlined` "Volver" that pops the navigator. Const-constructible.
- **`lib/core/router/app_router.dart`** — all 15 `const Scaffold()` builders replaced:
  - 14 with `const VComingSoonScreen(...)` (Spanish titles/descriptions per test plan table)
  - `/group/:groupId/members` with the real read-only `GroupMembersScreen(groupId: ...)`
  - Path shapes, route order, and parameter names untouched; only the import block grew.
- **`lib/features/groups/group_members_screen.dart`** — `GroupMembersScreen(groupId)`:
  loads `SupabaseService.instance.getGroupMembers(groupId)` in `initState`, shows
  `CircularProgressIndicator` while loading, then a `ListView.builder` of members (username from
  `users.username`, role subtitle, grey[800] avatar with initials — mirrors
  `group_detail_screen.dart` members tab), or "No hay miembros" when empty.
- **Tests** (22 new, all passing):
  - `test/widgets/v_coming_soon_test.dart` (4) — title/headline/description, default icon, Volver pops, hidden when `showBackButton: false`.
  - `test/router/app_router_test.dart` (+15) — every placeholder path navigated through the real `routerProvider`; asserts `VComingSoonScreen` (not a bare Scaffold); shell routes also assert `BottomNavigationBar`; members route asserts `GroupMembersScreen`.
  - `test/features/groups_screens_test.dart` (+3) — `GroupMembersScreen` loading state, empty state, title.

## Decisions

- **Headline string**: `'Pr\u00f3ximamente'` (title case, matching the test plan's example string) —
  not uppercase `PRÓXIMAMENTE`, so widget and router tests can assert the exact rendered text.
- **Router test harness** (the tricky part): `Supabase.initialize` cannot be avoided because
  `AuthGuard` → `authStateProvider` → `AuthNotifier()` touches `SupabaseService.instance.auth`
  synchronously in its constructor. `Supabase.initialize` is safe in `testWidgets` **only** if both
  storages are overridden (the default `SharedPreferencesLocalStorage` and
  `SharedPreferencesGotrueAsyncStorage` constructors call `SharedPreferences.getInstance()`, which
  throws `MissingPluginException` in tests). Harness used:
  - `setUpAll`: `Supabase.initialize(url: 'http://localhost:54321', anonKey: 'test-anon-key',
    authOptions: FlutterAuthClientOptions(localStorage: _MemoryStorage(),
    pkceAsyncStorage: _MemoryAsyncStorage(), detectSessionInUri: false))` — pure in-memory
    implementations of `LocalStorage` and `GotrueAsyncStorage`; zero network, zero plugins
    (verified: supabase 2.10.6 does no openid-config fetch at init).
  - `_FakeAuthNotifier extends AuthNotifier` — sets
    `state = const AuthState(authenticated: true, hasProfile: true)` after `super()` so the
    `AuthGuard` redirect lets every route render. Safe because (a) `_checkInitialSession()` runs
    synchronously (no awaits before `state = ...` when unauthenticated) and (b) the
    `initialSession` event emitted by `SupabaseAuth.initialize` fires during `setUpAll`, before the
    notifier subscribes, and gotrue's `BehaviorSubject` has no seed so it never replays.
  - Fresh `ProviderContainer(overrides: [authStateProvider.overrideWith(...)])` per test,
    `router.go(path)` then `UncontrolledProviderScope` + `MaterialApp.router` + `pumpAndSettle`.
- **Description strings** in the router use `\uXXXX` escapes for accented chars (repo convention in
  `group_detail_screen.dart`); tests assert the same compiled code points.
- **`/main/events` assertion**: "Eventos" appears twice (AppBar + bottom-nav label), so shell tests
  assert the unique description text + `BottomNavigationBar` instead of the bare title.

## MISTAKE

- **MISTAKE (caught before commit)**: first probe initialized Supabase with default
  `FlutterAuthClientOptions` and the harness failed in `setUpAll` with
  `MissingPluginException(No implementation found for method getAll on channel
  plugins.flutter.io/shared_preferences)` — `SharedPreferencesGotrueAsyncStorage`'s **constructor**
  calls `SharedPreferences.getInstance()` (not just `initialize()`). Fix: pass in-memory
  `pkceAsyncStorage` alongside in-memory `localStorage`.
- **MISTAKE (caught before commit)**: `AuthState` name collision — `supabase_flutter` re-exports
  gotrue's `AuthState`; must import with `hide AuthState` (same as `auth_provider.dart` does).

## Pre-existing issues observed (NOT touched, out of scope)

- **`/event/:inviteToken` never matches**: `/event/:eventId` is registered first, so
  `/event/<token>` always resolves to the Evento route. Documented in test plan §Out of Scope;
  router test asserts the actual behavior ('Evento' renders). Belongs to Phase 05 (ECRT/EINV).
- **23 pre-existing failing tests** (baseline before this work: 98 pass / 23 fail — identical
  failure set after this work; 120 pass / 23 fail now). Causes:
  - `test/providers/auth_provider_test.dart` (3), `auth_screens_test.dart` (6),
    `profile_screens_test.dart` (1), `widget_test.dart` (1): screens/notifiers touch
    `Supabase.instance` without initialization in the test env. The same harness used here
    (in-memory storages + `Supabase.initialize` in `setUpAll`) would fix them — deferred, not part
    of H-01 scope.
  - `test/structure_test.dart` (12): asserts directories that don't exist
    (`lib/features/events`, `chat`, `qr`, `photos`, `notifications`, `shards`, `cosmetics`,
    `minigames`, `party_finder`, `subscriptions`, `video_souvenir`, `lib/shared/models`) —
    brittle per finding L-13; creating empty dirs to satisfy it would be misleading.
- `dart analyze` reports 19 info-level issues, all pre-existing (`use_build_context_synchronously`
  in `public_profile_screen.dart` and others); zero errors, zero warnings, none in new files.

## Commands Run

```bash
flutter test test/widgets/v_coming_soon_test.dart test/router/app_router_test.dart test/features/groups_screens_test.dart
flutter test                      # 120 passed, 23 failed (all pre-existing)
flutter test --concurrency=1      # same counts (confirms no cross-file interference)
dart analyze                      # 0 errors, 0 warnings, 19 pre-existing info
grep -rn "const Scaffold()" lib/core/router/app_router.dart   # no matches
```

## Verification

- [x] `flutter test` — 120 passed (+22 new), 23 failed (all pre-existing, unchanged from baseline)
- [x] `dart analyze` — zero errors; zero issues in new/modified files
- [x] `grep -rn "const Scaffold()" lib/core/router/app_router.dart` → no matches
- [x] All 15 placeholder builders replaced (14 × `VComingSoonScreen` + 1 × `GroupMembersScreen`)
- [x] No route path strings, order, or parameter names changed
- [x] Docs updated: `TODO.md` H-01 ✅, `cross-references.md` known-issues row ✅
