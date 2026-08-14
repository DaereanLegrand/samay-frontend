# 2026-08-09 — I-13: Profile feature providers (SM-07 / CQ-11 / M-06)

**Agent:** I-13 (profile screens → Riverpod migration)
**Status:** DONE
**Scope:** ProfileScreen + EditProfileScreen migrated off `setState` onto feature providers, pull-to-refresh, provider + widget + integration tests, TODO.md statuses.

## What was built

### Screens (`lib/features/profile/`)
- `profile_screen.dart` — `ConsumerStatefulWidget`+`setState` → **`ConsumerWidget`** (SM-07/CQ-11/M-06).
  - Watches `myProfileProvider` + `myGroupsProvider` via `.when`-style `AsyncValue` handling (spinner while first load is in flight, `ErrorView` with retry on first-load failure, data otherwise).
  - **Pull-to-refresh** (`RefreshIndicator` → `notifier.refresh()` on both providers; `AlwaysScrollableScrollPhysics` so short content still pulls).
  - All UI preserved 1:1: avatar initials, username, `_BalanceCard` (shards/preshards), bio block, groups list, settings action, 'Perfil' title.
  - Error presentation uses I-06's shared `ErrorView` + `error.toAppError().message` (I-08 mapper).
- `edit_profile_screen.dart` — plain `StatefulWidget` → `ConsumerStatefulWidget` (still needs a `TextEditingController`, so `ConsumerState` is justified):
  - Bio prefill from `myProfileProvider` (via `ref.listenManual` in `initState` + `_load()` fast path); **falls back to the old direct `users.select('bio')` query when the provider is not ready**.
  - `_save()` invalidates `myProfileProvider` so the profile tab shows the new bio (required to preserve the old "refetch on return" behavior with the now-cached provider).

### Providers
- **I-12's `lib/features/profile/profile_providers.dart` used as-is** (coordinated via lock — see below): `myProfileProvider` (`AsyncNotifierProvider<MyProfileNotifier, Map<String,dynamic>?>`) + `myGroupsProvider` (`AsyncNotifierProvider<ProfileGroupsNotifier, List<Map<String,dynamic>>>`), both with `refresh()`. No changes by me; my screens/tests were written against that API.

### Tests
- `test/providers/profile_providers_test.dart` (6) — `myProfileProvider`/`myGroupsProvider`: AsyncData on success, AsyncError on failure, `refresh()` re-runs the fetch. Stub notifiers (`extends MyProfileNotifier/ProfileGroupsNotifier` with call-counting fetchers that survive provider recreation on invalidation) injected via `ProviderContainer` overrides; in-memory Supabase harness (`MemoryLocalStorage`/`MemoryAsyncStorage`, mirrors `test/router/app_router_test.dart`).
- `test/features/profile_screens_test.dart` (12) — kept all existing tests, added: loading→data render, error state (`ErrorView`), pull-to-refresh re-fetches, edit-screen bio prefill from provider. Added `setUpAll` fake-Supabase harness — **fixes the pre-existing 1 baseline failure in this file**.
- `integration_test/profile_flow_test.dart` (2, hermetic) — real app boots, authenticated user lands on ProfileScreen via `RoutePaths.mainProfile`; settles out of loading (error view with no session). Runner slot already present in `integration_test/runner.sh` (auth → **profile** → friends → groups).

### Docs
- `docs/to-fix/TODO.md` — M-06 → ✅ (I-13, 2026-08-09). (SM-07/CQ-11 rows live in the D-03-owned category files, still marked "planned → I-13" — awaiting D-03's re-verification pass.)

## Decisions & rationale

1. **No service seam added to I-12's providers.** I-12's design calls `SupabaseService.instance` directly; the test seam is subclassing the notifiers (`overrideWith(() => _StubNotifier(fetcher))`) with fetchers whose counters live outside the notifier (Riverpod recreates the notifier on invalidation — an instance counter would reset).
2. **`ref.listenManual` for the bio prefill** — riverpod 2.6 asserts `ref.listen` outside `build`; the edit screen needs to react to a provider that resolves after `initState`.
3. **Loading/error gating preserves data during refresh**: `showLoading` only when `isLoading && !hasValue`; error only when `hasError && !hasValue` — a failed pull-to-refresh keeps showing the last data (RefreshIndicator swallows the error, which surfaces in provider state).
4. **`ref.invalidate(myProfileProvider)` after save** — mandatory: the old screen refetched on every visit; the cached provider would otherwise show a stale bio forever.

## MISTAKE blocks

- **MISTAKE (API):** `AsyncNotifierProvider.overrideWith` in riverpod 2.6.1 takes a **zero-arg** builder (`NotifierT Function()`), not `(Ref) => Notifier`. My `(ref) => _Stub...` closures didn't compile; fixed to `() => _Stub...`.
- **MISTAKE (async state):** asserting `AsyncError` immediately after reading a provider is racy — `build()` errors land in state asynchronously. Must `await container.read(provider.future).catchError(...)` first.
- **MISTAKE (harness):** `Supabase.initialize` in `setUpAll` of a pure `test` file needs `TestWidgetsFlutterBinding.ensureInitialized()` ("Binding has not yet been initialized").
- **MISTAKE (error mapping):** asserting `Exception('boom')` text on screen — I-08's mapper (landed mid-session) deliberately maps raw exceptions to `ServerError('')` → "Error del servidor. Intenta de nuevo." (no internals leaked). Assert the generic message instead.
- **Concurrency gotcha:** I-09's `authStateProvider` AsyncNotifier migration and I-11's service decomposition landed *while I was working* — `ref.watch(authStateProvider)` now returns `AsyncValue<AuthState>` (`auth.user` → `authState.valueOrNull?.user`). Adapted. Also `overrideWith` signature and error-mapper behavior above.
- **Concurrency gotcha (integration flow):** the hermetic harness has no real Supabase session, so `getMyGroups()` throws and the profile screen settles into `ErrorView`, not the empty-groups text — assert `ErrorView` + no spinner instead. 'Perfil' appears twice (AppBar + bottom-nav tab) — use `findsWidgets`.

## Coordination notes

- `profile_providers.dart` was **created by I-12 while I waited on its lock** (I-12 holds locks across the state-audit set: groups/friends providers, screens, tests, TODO.md earlier). Per mission ("if it exists when you acquire its lock, use it"), I used I-12's file unchanged; my background acquire was cancelled and never taken.
- No edits to `docs/to-fix/categories/*.md` (D-03-owned) — TODO.md only, per assignment.

## Commands run

```
dart analyze                                              # 0 errors / 14 issues (13 pre-existing infos + 1 I-11 warning; none from I-13 files)
flutter test test/providers/profile_providers_test.dart   # 6 passed
flutter test test/features/profile_screens_test.dart      # 12 passed (was 11 pass / 1 baseline fail)
flutter test integration_test/profile_flow_test.dart      # 2 passed
flutter test                                              # 411 pass / 12 fail — remaining 12 = structure_test.dart brittle asserts (documented baseline, I-47/I-48)
```
