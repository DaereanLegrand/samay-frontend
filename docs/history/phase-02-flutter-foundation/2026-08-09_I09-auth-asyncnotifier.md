# 2026-08-09 — I-09: Auth state → AsyncNotifier migration (SM-01..SM-04, SM-09; H-08..H-11)

**Agent:** I-09 (auth state architecture)
**Status:** done
**Scope:** `lib/core/providers/auth_provider.dart` (AsyncNotifier migration), all
`authStateProvider` consumers (router guard, auth screens, profile screens,
user provider), `test/providers/auth_provider_test.dart`, router test fakes,
integration-test support fakes, TODO.md H-08..H-11 statuses.

## Plan

1. PREP — this log file (locked).
2. RED — `test/providers/auth_provider_test.dart` rewritten around AsyncValue
   (initial loading → unauthenticated data; signIn success; signIn error; refresh
   invalidation) using a mocktail `Mock implements SupabaseService` injected via a
   provider override seam.
3. GREEN — `AuthNotifier extends AsyncNotifier<AuthState>` +
   `authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>`;
   data-only `AuthState` (loading/error removed); `refresh()` → `ref.invalidateSelf()`.
4. Consumers — auth_guard, app_router (listen type), auth screens, profile
   screens, user_provider, router/integration test fakes.
5. VALIDATE — `dart analyze` + `flutter test test/providers/ test/router/`
   (+ integration harness file check).
6. DOCUMENT — this log; update TODO.md H-08/H-10/H-11 → ✅, H-09 → partial.

## Research (sources at bottom)

- Installed (pubspec.lock): **flutter_riverpod 2.6.1 / riverpod 2.6.1**.
  `AsyncNotifier` (riverpod ≥ 2.1) IS available → full modern migration, no
  fallback needed (the mission's "closest supported pattern" branch was not taken).
- `AsyncNotifierProvider.overrideWith` takes a **zero-arg** `NotifierT Function()`
  (riverpod 2.6.1 `async_notifier/base.dart:151`) — the old `(ref) => ...` override
  form no longer compiles; test fakes must drop the `ref` parameter.
- `AsyncNotifier.state` setter is `@protected @visibleForTesting`
  (`async_notifier.dart:65`) — settable from subclasses; test files may use it
  via `@visibleForTesting`.
- `AsyncValue.copyWithPrevious` + `AsyncValue.guard` (riverpod 2.6.1 `common.dart`)
  drive the mutation pattern: `state = state.copyWithPrevious(const AsyncLoading())`
  → preserves the previous data so `.when()` (default `skipLoadingOnRefresh: true`)
  keeps rendering the form while the button spins.
- I-07's `resilient()` wiring (signIn/sendOtp/verifyOtp/createProfile) is
  preserved verbatim — only the state plumbing around it changes.

## Decisions

1. **Pattern: `AsyncNotifier<AuthState>` + `AsyncNotifierProvider`** — available in the
   pinned riverpod 2.6.1, matches Juega's reference architecture and SM-01/SM-09.
2. **`AuthState` becomes data-only** (authenticated / hasProfile / user); the
   `loading` + `error` fields are removed (SM-03). Loading/error now live in
   `AsyncValue`.
3. **Errors are stored typed**: `state = AsyncError(e.toAppError(), st)` (AppError).
   A small extension `AuthAsyncValueX.errorMessage` on `AsyncValue<AuthState>`
   (in auth_provider.dart) gives consumers the user-facing message.
4. **Mutations** set `state = state.copyWithPrevious(const AsyncLoading())` then
   `AsyncData(...)` on success / `AsyncError(...)` on failure — screens keep
   their form visible during submission and just reflect `isLoading`/`hasError`.
5. **Injection seam**: `supabaseServiceProvider = Provider<SupabaseService>(...)`
   defined in auth_provider.dart; `AuthNotifier` reads it via `ref.read`. Least
   invasive option: no constructor change, no SupabaseService edit (I-11 owns it),
   and I-44's later mocktail suite can override the same provider.
6. **Stream subscription moved from constructor → `build()`**, cancelled via
   `ref.onDispose` (and re-cancelled at the top of each build so `refresh()`
   never double-subscribes). This is the slot I-30's token-refresh wiring
   (tokenRefreshed event) will hook into.
7. **`refresh()` = `Future<void> refresh() async { ref.invalidateSelf(); }`** (SM-09).
8. Router/integration fakes override `build()` instead of setting `state` in the
   constructor (AsyncNotifier has no usable state until the element attaches —
   the old StateNotifier fake could not carry over verbatim).
9. `docs/to-fix/categories/*.md` untouched (D-03-owned); only TODO.md statuses.

## MISTAKE / gotcha (self)

- **`AsyncNotifierProvider.overrideWith` takes `NotifierT Function()`** — porting the
  old `(ref) => notifier` override verbatim fails to compile. Same for the
  integration `newTestContainer` helper.
- **Setting `state` in an AsyncNotifier constructor crashes** (late `_element` not
  yet attached) — fakes must override `build()` instead.
- **`ref.listen<AuthState>(authStateProvider, ...)` no longer typechecks** — the
  emitted type is now `AsyncValue<AuthState>`; drop the explicit type parameter.
- **H-09 is only partially closed by I-09**: `appConfigProvider`/`currentUserProvider`
  remain `FutureProvider`s (I-12/I-71 own the refresh migration) — TODO.md gets a
  partial annotation, not ✅.

## Built

- `lib/core/providers/auth_provider.dart` —
  - `AuthNotifier extends AsyncNotifier<AuthState>` + `authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>` (riverpod 2.6.1 — AsyncNotifier
    available since 2.1, so the full modern migration was possible).
  - `AuthState` is now data-only: `authenticated` / `hasProfile` / `user`;
    `loading` + `error` fields removed (SM-03).
  - Errors stored typed: `state = AsyncError(e.toAppError(), st)`; consumers read
    `auth.errorMessage` via the new `AuthAsyncValueX` extension (AppError→message).
  - Mutation pattern: `state = state.copyWithPrevious(const AsyncLoading())` →
    `AsyncData(...)` / `AsyncError(...)` (keeps previous data visible while a form
    submit is in flight; `.when()`'s default `skipLoadingOnRefresh` keeps the form
    rendered and the button spinning via `auth.isLoading`).
  - Auth-stream subscription moved from constructor into `build()`; each `build()`
    cancels the previous subscription and registers `ref.onDispose` cleanup —
    the hook I-30's token-refresh wiring (`tokenRefreshed` event) will extend.
  - `refresh()` → `ref.invalidateSelf()` (SM-09).
  - `supabaseServiceProvider = Provider<SupabaseService>(...)` — injection seam
    (defaults to the singleton); tests override it. I-07's `resilient()`
    wiring on signIn/sendOtp/verifyOtp/createProfile preserved verbatim.
- Consumers updated to the `AsyncValue` API:
  - `lib/core/router/auth_guard.dart` — `auth.isLoading` guard; authenticated/
    hasProfile via `auth.valueOrNull` (fallback = unauthenticated).
  - `lib/core/router/app_router.dart` — `ref.listen<AsyncValue<AuthState>>(...)`.
  - `lib/core/providers/user_provider.dart` — `auth.valueOrNull?.authenticated`.
  - `lib/features/auth/login_screen.dart`, `profile_setup_screen.dart`,
    `otp_verification_screen.dart`, `signup_contact_screen.dart` — error text via
    `auth.hasError` + `auth.errorMessage`, button busy via `auth.isLoading`;
    post-await reads via `valueOrNull`.
  - `lib/features/profile/profile_screen.dart` — user via `auth.valueOrNull?.user`.
  - `lib/features/profile/settings_screen.dart` + `delete_account_screen.dart` —
    read only `.notifier` methods (unchanged signatures); locked, verified, no edit.
- Tests:
  - `test/providers/auth_provider_test.dart` — rewritten: initial `AsyncLoading`
    while `build()` is in flight; initial unauthenticated / not-loading / null-user
    (keeps the 3 baseline intents); signIn success → `AsyncData` authenticated with
    user; signIn failure → `AsyncError` with mapped message
    ('Correo o contraseña inválidos') via mocktail `Mock implements SupabaseService`;
    `refresh()` invalidates (loading interlude observed + `build()` re-run proven by
    a state-changing `getCurrentUser` stub).
  - `test/router/app_router_test.dart` — `_FakeAuthNotifier` now pins identity by
    overriding `build()`, state setter deals in `AsyncValue<AuthState>`, override is
    zero-arg `overrideWith(() => ...)`; sign-out simulation sets
    `const AsyncData(AuthState())`.
  - `integration_test/support/fake_supabase.dart` + `test_app.dart` — `FakeAuthNotifier`
    resolves `initialState` from `build()`; zero-arg override.
  - `test/features/auth_screens_test.dart` — 3 render tests got
    `await tester.pumpAndSettle()` after `pumpWidget` (the AsyncNotifier's first
    frame is `AsyncLoading`, so buttons show spinners; the old harness crashed on
    Supabase-not-initialized instead). Failure set: 0 in this file (was 6).
- `docs/to-fix/TODO.md` — H-08/H-10/H-11 → ✅ (I-09, 2026-08-09); H-09 → ❌ with
  partial note (config/user providers still `FutureProvider`; I-12/I-71 own the
  refresh migration).

## Validation

- `dart analyze` → **0 errors / 0 warnings in I-09 files**. 13 errors present in
  `test/services/supabase_service_test.dart` are **I-11's in-flight refactor**
  (they hold its lock; file references `authService`/`configService`/… getters not
  yet on `SupabaseService`) — reported, not mine.
- `flutter test test/providers/ test/router/` → **124/124 pass** (7 providers +
  117 router; mission target: providers + router green).
- `flutter test integration_test/auth_flow_test.dart` → **3/3 pass** (hermetic
  harness still green with the fake-notifier build() override).
- `flutter test test/features/auth_screens_test.dart test/features/profile_screens_test.dart`
  → **17/17 pass**.
- `test/structure_test.dart` → 12 failures, unchanged documented baseline (I-47).
- Baseline diff: the 11 documented auth-harness failures
  (auth_provider 3, auth_screens 6, profile_screens 1, widget_test 1) are all
  **fixed by this migration** (0 new failures introduced); structure_test's 12
  remain for I-47.
- Full `flutter test` NOT run to completion: I-10/I-11/I-12 are mid-flight in the
  shared tree (I-11's `supabase_service_test.dart` currently fails to compile) —
  same precedent as I-07's log.

## Commands run

```bash
export AGENT_NAME="I-09-asyncnotifier"
# locks acquired (17 files, all exit 0): auth_provider, auth_guard, app_router,
# user_provider, 4 auth screens, 3 profile screens, auth_provider_test,
# app_router_test, fake_supabase, test_app, auth_screens_test, TODO.md, daily log
flutter test test/providers/auth_provider_test.dart        # red: 1 compile error → green: 7/7
dart analyze                                              # 0 errors in I-09 files
flutter test test/providers/ test/router/                 # 124/124 pass
flutter test integration_test/auth_flow_test.dart         # 3/3 pass
flutter test test/features/auth_screens_test.dart test/features/profile_screens_test.dart  # 17/17
flutter test test/widget_test.dart                        # 1/1 pass
flutter test test/structure_test.dart                     # +14 -12 (documented baseline, I-47)
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"  # all 18 files
```

## Sources

- Riverpod 2.6.1 installed source (`~/.pub-cache/hosted/pub.dev/riverpod-2.6.1/lib/src/`):
  `async_notifier/base.dart` (overrideWith zero-arg, state @protected/@visibleForTesting,
  FutureHandler element loading/data/error lifecycle), `async_notifier.dart`,
  `framework/element.dart` (flush → _performBuild on invalidate), `common.dart`
  (copyWithPrevious, guard).
- Riverpod AsyncNotifier docs: https://riverpod.dev/docs/providers/notifier_provider
- I-07 daily log (resilient wiring precedent) + H-01 harness doc (in-memory Supabase).
