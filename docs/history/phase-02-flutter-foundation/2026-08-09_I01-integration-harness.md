# 2026-08-09 — I-01: Modular Flutter Integration Test Suite (harness)

**Agent:** I-01 (integration-harness) · **Phase:** 02 Flutter Foundation (campaign 4.2)
**Directive:** *"A FULLY WORKING INTEGRATION TEST WHICH SHOULD BE AS MODULAR AS POSSIBLE
TESTING FOR ALL FUNCTIONALITIES."*

---

## What was built

- **`integration_test/`** — the modular Flutter integration suite (owned by I-01,
  `FILE-OWNERSHIP.md`), landing the scaffold other I-agents (I-44/I-45, U-28/U-29)
  build their flow files on:
  - `integration_test/README.md` — modular philosophy (each file self-contained and
    runnable alone), prerequisites (hermetic mode needs nothing; on-device mode needs
    a device/emulator; live flows need the self-hosted stack on approved ports
    54386/54382/…), run instructions, dart-define contract, new-file template.
  - `integration_test/runner.sh` — whole-suite orchestrator. Runs existing flow files
    in **dependency-safe order** (auth → profile → friends → groups → events → chat → …),
    skips files not yet written, prints per-file pass/fail + summary, exits 0/1.
    Hermetic by default; `-d <device-id>` for on-device runs.
  - `integration_test/support/fake_supabase.dart` — in-memory Supabase harness:
    `MemoryLocalStorage` (extends `LocalStorage`), `MemoryAsyncStorage` (extends
    `GotrueAsyncStorage`), idempotent `initFakeSupabase()`, and `FakeAuthNotifier`
    (extends `AuthNotifier`, deterministic sync state). Pattern lifted from
    `test/router/app_router_test.dart` (H-01) and made shared.
  - `integration_test/support/test_app.dart` — boots the **real app** (`SamayApp`:
    real `routerProvider`, real `SamayTheme`, real screens) inside a fresh
    `ProviderContainer` whose only override is the fake auth notifier:
    `newTestContainer({initialState})`, `pumpTestApp(tester, container, path)`,
    `goTo(...)`. Documents hermetic vs live usage.
  - `integration_test/support/test_users.dart` — OPT-IN real-stack helpers:
    `isLocalStackUp()` (Kong probe, `http://127.0.0.1:54386`), `createTestUser()`
    (auth admin API → `public.users` row → password grant JWT, mirroring
    `test/opt-001-rls-security.sh`), `deleteTestUser()` (trap-safe). Config via
    `--dart-define`; placeholder keys by default (no secrets).
  - `integration_test/auth_flow_test.dart` — **working hermetic example flow** that
    passes with NO live server (in-memory Supabase + fake auth notifier). Covers:
    welcome screen renders (VIVE, tagline, both CTAs) → tap "Iniciar sesión" →
    login screen renders (Correo electrónico / Contraseña / Olvidé mi contraseña),
    plus direct `/login` reachability. Deterministic: no timers.
- **`test/run_all_backend.sh`** — now detects `integration_test/` as a **separate
  step**: prints presence + count of flow files + how to run the suite, does NOT
  execute Flutter tests, exit semantics unchanged (exit code covers only opt-*).
- **`docs/process/DEVELOPMENT-WORKFLOW.md` §3.2** — rewritten from "planned/I-01 will
  create" to the landed layout, run commands, and per-file rules.
- **`docs/history/phase-02-flutter-foundation/2026-08-09_I01-integration-harness.md`**
  — this log.

## Decisions

- **Hermetic-by-default design.** Every flow file runs against the in-memory harness;
  the suite is CI-safe and never depends on a running stack. Live-stack flows opt in
  via `test_users.dart` and self-skip when the stack is down (`isLocalStackUp()`).
  Rationale: the 23 pre-existing failures exist because tests touched an
  un-initialized `Supabase.instance`; the integration suite must not repeat that class
  of flakiness.
- **Real app, one override.** `SamayApp` (MaterialApp.router + SamayTheme + real
  routerProvider) is pumped as-is; only `authStateProvider` is overridden with
  `FakeAuthNotifier`. This mirrors `app_router_test.dart` exactly and keeps the flows
  honest (they exercise the real router, guard, and screens).
- **`AuthState()` default = unauthenticated.** `const AuthState()` (not the notifier's
  `loading: true` default) so the AuthGuard deterministically renders public routes;
  `AuthState(authenticated: true, hasProfile: true)` opts flows into the main shell.
- **Spanish UI strings asserted verbatim** (`'Iniciar sesión'`, `'Contraseña'`,
  `'Olvidé mi contraseña'`) — same convention as `test/features/auth_screens_test.dart`;
  localization (I-14/I-15) will change these.
- **No `integration_test` package import in flow files (for now).** `flutter test`
  host runs use the default deterministic binding. The `integration_test:
  sdk: flutter` dev dependency WAS added to `pubspec.yaml` (additive; the Flutter
  tool refuses to run any file under `integration_test/` without it). Flow files
  don't import the package yet; U-29 can add the binding import for
  `flutter drive`/device reportData workflows when ui_smoke_test lands.
- **On-device semantics.** With the dep present, `flutter test
  integration_test/<file>.dart` (no `-d`) targets the first available desktop
  device (macOS here) — the run is still hermetic (in-memory harness, no server).

## MISTAKE

- **MISTAKE (caught at verification):** first `flutter test integration_test/…` run
  failed with `cannot run without a dependency on "package:integration_test"` — the
  Flutter tool hard-requires the dev dependency for any file under `integration_test/`
  even when the file never imports it. Verification therefore blocks on pubspec.yaml.
- **MISTAKE (design constraint):** initially considered `IntegrationTestWidgetsFlutterBinding
  .ensureInitialized()` in the flow file; dropped it — under host `flutter test` the
  live binding is less deterministic than the default automated binding, and the
  hermetic pattern (like `app_router_test.dart`) needs neither it nor the package import.

## BLOCKER (resolved)

- **BLOCKED on `pubspec.yaml` by I-05-logging** (claimed 05:56:23Z, released
  ~06:01Z). Required edit (additive): `dev_dependencies: integration_test:
  sdk: flutter`. Waited via `agent_lock.sh acquire --timeout 840` until I-05
  released, then acquired, added the one line, ran `flutter pub get`, released.
  The Flutter tool hard-requires this dependency for ANY file under
  `integration_test/` ("cannot run without a dependency on
  package:integration_test") — even without importing the package.

## Commands run

```bash
mkdir -p integration_test/support
tools/agent_lock.sh acquire <file> --owner I-01-integration-harness   # 9 files (see report)
bash -n integration_test/runner.sh                                    # OK
bash -n test/run_all_backend.sh                                       # OK
chmod +x integration_test/runner.sh
flutter pub get                                                        # after pubspec dep line
flutter test integration_test/auth_flow_test.dart                     # 3/3 PASS (no live server)
bash integration_test/runner.sh                                       # 1 flow pass, 5 skipped, exit 0
bash test/run_all_backend.sh                                          # detection block OK; exit 1 (opt-001 vs no stack, pre-existing)
dart analyze                                                          # integration_test/: 0 issues
```

## Verification status

- [x] `bash -n` both scripts
- [x] `flutter test integration_test/auth_flow_test.dart` — **3/3 PASS, no live
      server** (in-memory Supabase + fake auth notifier)
- [x] `bash integration_test/runner.sh` — runs auth_flow, skips unbuilt flows,
      summary + exit 0
- [x] `dart analyze` — `integration_test/`: 0 issues; no new issues repo-wide
- [x] `test/run_all_backend.sh` — integration suite detected + linked; exit code
      unchanged (1 = opt-001 vs absent stack, pre-existing)
- [ ] Full `flutter test` — NOT run per assignment (23 pre-existing failures are
      I-47's scope)

## Notes for downstream agents

- I-44/I-45, U-28/U-29: copy `auth_flow_test.dart` as your template; keep flows
  hermetic; use `RoutePaths.*`; register new flows in `runner.sh` after their deps.
- U-29 (`ui_smoke_test.dart`): will need the `integration_test` package import for
  device reportData — add the dev dependency then (or have I-23/I-24 land it earlier).
- The full-suite baseline will shift once flow files land (`flutter test` picks up
  `integration_test/*`); hermetic files are additive-passing, so the failure set
  (23) is unaffected.
