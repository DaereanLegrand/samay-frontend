# 2026-08-09 — I-03: Router Hardening (H-03 / H-04 / M-08 / M-09)

Agent: **I-03-router-hardening** — `lib/core/router/**`, auth extras call sites, router tests.

## What was built

- **`lib/core/router/route_extras.dart`** (new) — `sealed class RouteExtra` base + four typed,
  validated payloads with null-safe, type-safe extraction factories:
  - `VerifyExtra(email, password)` — `/auth/verify`
  - `PrivacyTermsExtra(email, dateOfBirth)` — `/auth/privacy-terms`
  - `ProfileSetupExtra(email, dateOfBirth)` — `/auth/profile-setup`
  - `AgeGateExtra(email)` — `/auth/age-gate`
  - `RouteParams.fromState/fromMap` — null-safe path-parameter access.
  - Every factory returns `null` on missing/invalid data — **never throws** (finding NAV-04/H-04,
    NAV-03/H-03). Factories tolerate the typed object AND the legacy map/String extra forms, so
    deep links or un-migrated callers degrade gracefully instead of crashing.
- **`lib/shared/widgets/route_error_screen.dart`** (new) — const-constructible `RouteErrorScreen`
  (`title`, `message` defaults) with AppBar + centered message + "Volver" button that
  `Navigator.maybePop()`s to the previous flow step.
- **`lib/core/router/auth_refresh_notifier.dart`** (new) — `AuthRefreshNotifier extends
  ChangeNotifier` with a `refresh()` method.
- **`lib/core/router/app_router.dart`** — rewritten builders:
  - `errorBuilder` → `RouteErrorScreen` (unknown routes render, never throw — M-08).
  - `refreshListenable` → `AuthRefreshNotifier` fed by `ref.listen(authStateProvider, ...)`,
    disposed via `ref.onDispose` (M-09).
  - All 15 parameterized routes use `_screenForId` (null-safe param → `RouteErrorScreen` on
    missing param). Zero `state.pathParameters[...]!` and zero `state.extra as ...` remain.
  - `/auth/verify`, `/auth/privacy-terms`, `/auth/profile-setup` render `RouteErrorScreen` on
    invalid/missing extra; `/auth/age-gate` tolerates missing extra (screen falls back to the
    signed-in user's email). `/group/:groupId/donate` keeps its `String?` groupName extra with a
    safe type-check cast (`is String ? as String : 'Grupo'`).
  - I-04's `MainShell` extraction preserved (ShellRoute builder delegates to it).
- **4 auth feature files** now push the typed extras:
  - `signup_contact_screen.dart` → `VerifyExtra(email, password)`
  - `otp_verification_screen.dart` → `AgeGateExtra(email)`
  - `age_gate_screen.dart` → `PrivacyTermsExtra(email, dateOfBirth)`
  - `privacy_terms_screen.dart` → `ProfileSetupExtra(email, dateOfBirth)`
- **Tests** (new/updated, all green):
  - `test/router/app_router_test.dart` — existing `with extra` tests moved to typed extras; new
    "route hardening" group (10 tests): missing path params (`/group/`, `/user/`), `/auth/verify`
    + privacy-terms + profile-setup without extra → `RouteErrorScreen`; age-gate with wrong-typed
    extra; unknown route → error screen; auth state change re-evaluates the redirect
    (refreshListenable).
  - `test/router/route_extras_test.dart` (new, 18 tests) — factory validation matrix:
    null/wrong-type/missing-field/empty-field/legacy-map/typed-object for all four extras +
    `RouteParams.fromMap`.

## Decisions

- **Fallback = `RouteErrorScreen`, "Volver" pops to the previous flow step** (signup → verify →
  age-gate → privacy-terms → profile-setup chain). Chosen over `context.go(login)` because a
  builder cannot safely navigate; the pop-based fallback returns the user to the exact previous
  step, and for deep links with no back stack `maybePop` is a no-op (no crash, no dead end).
  Documented here and in the category file.
- **Factories return `null` instead of throwing** — the "failure result" from the assignment.
  Nullable return keeps the API tiny (vs a Result wrapper) and reads naturally in builders.
- **Typed extras accept legacy forms** (map / String) in addition to the typed object: cheap
  tolerance (one `_stringField` helper) that protects any un-migrated push site or deep link.
- **Age-gate keeps null-email tolerance** — its screen already falls back to the signed-in
  user's email; a missing extra is not an error for this route.
- **`go_router` stays at `^14.8.1`** (I-24 owns upgrades) — solved with defensive code + typed
  wrapper classes instead of `TypedGoRoute` (finding NAV-09 is NOT closed by this work).
- **Test harness change (important)**: supabase/gotrue emits a **one-shot async
  `initialSession` (session=null) recovery event** shortly after `onAuthStateChange` subscription.
  `AuthNotifier._onAuthStateChange` handles it by resetting state to `AuthState()` (unauth).
  Pre-I-03 this was invisible (the redirect ran once at `router.go`); with `refreshListenable`
  the reset now correctly re-evaluates the redirect — which is the M-09 behavior — but it broke
  the existing `_FakeAuthNotifier` harness. Fix: the fake now pins its identity by overriding the
  `state` setter (drop unauthenticated states while pinned) and exposes `allowSignOut()` for the
  redirect test. Deterministic; verified across 3 consecutive full `test/router/` runs.

## MISTAKE

- **MISTAKE (caught and fixed)**: first attempt to fix the harness re-asserted the fake state
  inside `_pumpRoute` after `pumpAndSettle` — this races the (nondeterministic) delivery of
  gotrue's initialSession event and broke the unknown-route test (a late reset bounced the
  redirect to login and then to the feed, masking the error screen). Replaced with the
  state-setter pin described above; the pump-dance and its re-asserts were removed from
  `_pumpRoute`.
- **MISTAKE (caught and fixed)**: `GoRouterState` in go_router 14.8.1 cannot be constructed
  externally (private `RouteConfiguration` positional arg). Unit tests therefore target
  `fromObject`/`fromMap` primitives while `fromState` (the router-facing wrapper) is covered
  end-to-end by the widget tests in `app_router_test.dart`.
- **MISTAKE (noted)**: `login_screen.dart`'s test-local router in `auth_screens_test.dart` still
  uses the old unsafe casts — out of scope (pre-existing, I-47's file set); the 6 failures there
  are the documented baseline.
- **MISTAKE (noted, coordination)**: `integration_test/` exists (I-01's scaffold, currently
  LOCKED by I-01). Router-flow integration cases were NOT added to it to avoid clobbering I-01's
  in-flight locked files; the router behavior is covered by 116 widget/unit tests in
  `test/router/`.

## Pre-existing issues observed (NOT touched, out of scope)

- 23 documented baseline failures unchanged (`auth_provider_test` ×3, `auth_screens_test` ×6,
  `profile_screens_test` ×1, `widget_test` ×1, `structure_test` ×12) — I-47's scope.
- I-05/I-06 concurrent in-flight work (`pubspec.yaml`, `lib/main.dart`, error widgets,
  `docs/to-fix/*`) caused transient full-suite noise during my runs; the final full run matched
  the baseline exactly (272 pass / 23 fail).
- `docs/to-fix/categories/02-NAVIGATION-ROUTING.md` NAV-03/04/06/07 statuses updated by me with
  I-03 references (D-03's file, lock coordinated).

## Commands Run

```bash
export AGENT_NAME="I-03-router-hardening"
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME" --timeout 300   # 12 files + TODO.md
flutter test test/router/route_extras_test.dart                          # 18 passed
flutter test test/router/                                                # 116 passed (3×)
dart analyze                                                             # 0 errors, 0 warnings, 18 info (all pre-existing; 1 pre-existing info removed)
flutter test                                                             # 272 passed, 23 failed (documented baseline set)
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"                 # all 13 files
```

## Verification

- [x] `dart analyze` — 0 errors, 0 warnings; no issues in any new/modified file
- [x] `flutter test test/router/` — 116 passed, 3 consecutive runs (deterministic)
- [x] `flutter test` — 272 passed / 23 failed, exactly the documented baseline set (no regressions)
- [x] Missing path params render `RouteErrorScreen`; unknown routes render via `errorBuilder`
- [x] `/auth/verify` + privacy-terms + profile-setup without extra → fallback, no crash; with
      typed extras → the right screens
- [x] `refreshListenable` re-evaluates the redirect on auth state change (test proves login bounce)
- [x] Welcome/login redirect tests still green
- [x] Zero `state.pathParameters[...]!` / `state.extra as ...` in `lib/core/router/app_router.dart`
- [x] Docs updated: `TODO.md` H-03/H-04/M-08/M-09 ✅ (I-03 ref), category NAV-03/04/06/07 ✅
