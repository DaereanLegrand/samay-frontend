# I-70 — Crash reporter: Sentry placeholder seam, global-handler wiring, scrubbed user context

**Agent:** I-70-crash-reporter · **Date:** 2026-08-09/10 · **Phase:** 02 (flutter foundation) / LOG-05 + ERR-10/L-10
**Spec inputs:** `docs/to-fix/categories/15-LOGGING-OBSERVABILITY.md` (LOG-05 — no crash reporting SDK), `docs/to-fix/categories/03-ERROR-HANDLING.md` (ERR-10 — Sentry integration), `docs/to-fix/TODO.md` (L-10), `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (placeholder philosophy — no real DSN anywhere), `docs/process/DEVELOPMENT-WORKFLOW.md` (locks, no commits, no Juega), I-68 seam pattern (`lib/core/services/telemetry_service.dart` — `TelemetrySink`/stub-mode precedent), I-05 flow (`lib/main.dart` handlers — AppLogger + crash marker + presentError).

---

## What was built

### 1. `lib/core/services/crash_reporter.dart` (new — FILE-OWNERSHIP I-70 ✅)

The Sentry seam, mirroring the I-68 telemetry pattern (`posthogApiKey` → `TelemetrySink`):

- `sentryDsn` — `const String.fromEnvironment('SENTRY_DSN', defaultValue: '')` build-time define (I-34 dart-define convention). Placeholders only; a real DSN is deploy-time (DEPLOYMENT-PLACEHOLDER.md-style — reported for D-03/M-13 to register a `SENTRY_DSN` row).
- `CrashSink` — abstract delivery endpoint (`reportError`/`setUser`/`addBreadcrumb`). The future sentry_flutter wiring implements it; tests inject a recording fake; stub mode never touches it.
- `CrashReporter` — injectable seam:
  - `isEnabled` is **true only when `SENTRY_DSN` is non-empty** (per the mission seam spec).
  - `reportError(Object error, StackTrace stack, {Map<String, String>? context})` — no-op when disabled; when enabled, delegates to the injected sink. **Never throws**: a throwing sink is caught and logged via `AppLogger.error` (fire-and-forget contract — the global handlers call this unawaited, so a sink failure must never crash the error path).
  - `setUser(String? userId)` — **scrubbed**: the sink receives only `sha256(userId)` (hex, via `package:cryptography` — already a dependency), never the raw id. Documented: the auth layer passes the Supabase user `id` (a UUID), but the hash also guarantees that even an email-shaped value never reaches the crash backend (SECURITY.md §2.8 data-minimization contract). Null/empty → no-op.
  - `addBreadcrumb(String message)` — appends to the sink when enabled; silent no-op in stub mode (breadcrumbs are high-volume; logging each at error level would spam `samay.log` — decision below).
  - Stub mode (per the mission directive): `reportError` logs the crash via `AppLogger.error` (loud in debug, survives release — it is an error-level entry, not compiled out like debug/info).
- `crashReporterProvider` — defined in this file (keeps I-11's `service_providers.dart` untouched, I-68 precedent). Resolves to a disabled stub-mode reporter in tests (no `SENTRY_DSN` define).

### 2. `lib/main.dart` wiring (I-05-owned — mission-granted lock)

- `main()` constructs `final crashReporter = CrashReporter();` after `AppLogger.instance.init()` and passes it to the two extracted handler functions.
- **Extracted** the two global handlers into testable top-level functions (the mission's "call the handler function directly if extractable" path):
  - `handleFlutterError(FlutterErrorDetails details, CrashReporter reporter)`
  - `handlePlatformError(Object error, StackTrace stack, CrashReporter reporter) -> bool`
- **I-05's exact flow preserved** — `reportError` is added AFTER `AppLogger.error` + `markCrash`, and BEFORE `FlutterError.presentError(details)` / `return true`:
  1. `knownBenignError` filter — benign errors are downgraded and `return` **early** (they never reach the reporter);
  2. `AppLogger.instance.error(message, stack)`;
  3. `unawaited(AppLogger.instance.markCrash(...))`;
  4. **NEW (I-70):** `unawaited(reporter.reportError(exception, stack))` — fire-and-forget;
  5. `FlutterError.presentError(details)` / `return true`.
- Minimal additive diff: the two closures became two top-level functions of identical body + one added `reportError` line each.

### 3. `lib/core/providers/auth_provider.dart` setUser wiring (I-09-owned — mission-granted, ONE line)

One line in `_authStateForUser` (the single seam every authenticated transition flows through — initial restore, signIn, verifyOtp, signUp-via-auth-event, tokenRefreshed):

```dart
unawaited(ref.read(crashReporterProvider).setUser(user['id'] as String?));
```

- Covers sign-in **and** restore with one line (the mission's "ONE line via ref").
- `setUser` is a no-op in stub mode (every test build), so existing `auth_provider_test.dart` scenarios are untouched.
- Never PII: `user['id']` is the Supabase UUID; the reporter hashes it before the sink sees it.

### 4. Tests (TDD — RED first, all failed on missing symbols, then GREEN)

`test/services/crash_reporter_test.dart` (new):

| Group | Cases |
|---|---|
| Stub mode (no SENTRY_DSN) | `isEnabled` false; `reportError` never touches the sink; `setUser` no-op (null + non-null); `addBreadcrumb` no-op |
| Enabled path (dsn present + injected sink) | `isEnabled` true; `reportError` forwards error+stack+context; null context forwarded; sink throwing → `reportError` still completes (never rethrows); `setUser` scrubs — sink receives a 64-hex `^[0-9a-f]{64}$` value, deterministic, raw id never sent; `setUser(null|'')` no-op; `addBreadcrumb` appends |
| `hashUserId` (pure scrub) | 64 lowercase hex chars; deterministic; different inputs → different hashes; never equals the input |
| Enabled but no sink (SDK wiring pending) | `reportError` logs and completes; `setUser`/`addBreadcrumb` silent no-ops |
| Provider | `crashReporterProvider` resolves to a disabled stub-mode reporter in tests |
| main.dart wiring (via the extracted handlers) | `handleFlutterError` reports a real error after the benign filter; benign Flutter error never reaches the reporter; `handlePlatformError` reports + returns true; benign platform error returns true without reporting |

## Verification (validation gate)

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter test test/services/crash_reporter_test.dart      # RED: fails (no crash_reporter.dart) → GREEN: all pass
flutter test test/logging/                               # 13/13 (I-05 intact)
flutter test test/providers/auth_provider_test.dart      # all green (setUser line inert in stub mode)
flutter test test/widget_test.dart                       # green
flutter test                                            # FULL SUITE — 0 failures
dart analyze                                            # 0 errors
```

## Decisions made and why

- **Seam + placeholder, no `sentry_flutter` dep** (mission directive): sentry_flutter would add heavy native deps; the `CrashSink` seam + `SENTRY_DSN` gating is the foundation. The real SDK wiring is an S-18/security-adoption decision (handoff noted in the final report).
- **`setUser` hashes via `package:cryptography` SHA-256** (already a dependency — zero new deps, no pubspec churn): a non-reversible, deterministic identifier scrub. The crash backend can correlate a user's crashes across reports without ever receiving PII.
- **Stub `reportError` logs via `AppLogger.error`** (mission literal): devs see crash-path activity loudly; unlike telemetry's info-level stub log, this survives release builds (error level is not compiled out).
- **Stub `addBreadcrumb` is a silent no-op** (not `AppLogger.error`): breadcrumbs are per-action context — logging each at error level would flood `samay.log` in debug. Documented as a deviation-from-literal reading of "stub mode logs via AppLogger.error" (that sentence applies to the crash-report path).
- **Handlers extracted to top-level functions** in main.dart: makes the global-handler path directly testable with an injected reporter (the mission's "if extractable" branch) without pumping the app.
- **`reportError` never throws**: the handlers call it unawaited; a throwing sink must not trigger the global error handler it is reporting from (recursion).

## Mistakes / gotchas

> **MISTAKE (avoided, documented):** calling the sink inside `reportError` without a catch would let a sink failure escape into the very global error handlers that invoke it unawaited — the unhandled async error would loop back through `handleFlutterError`. The sink calls are wrapped and logged.
> **GOTCHA:** `FlutterError.presentError` in the wiring test re-invokes whatever `FlutterError.onError` is currently set (the test framework's recorder). The wiring test stubs `FlutterError.onError` to a no-op around the call and restores it after.

## Files created/modified (locks held/released by I-70-crash-reporter)

- `lib/core/services/crash_reporter.dart` (new) — acquire 2026-08-10T16:41:39Z / release
- `lib/main.dart` — acquire / release (I-05-owned; mission-granted)
- `lib/core/providers/auth_provider.dart` — acquire / release (I-09-owned; mission-granted, 1 line)
- `test/services/crash_reporter_test.dart` (new) — acquire / release
- `docs/to-fix/TODO.md` (L-10 status) — acquire / release (D-03-owned; mission-granted)
- `docs/history/phase-02-flutter-foundation/2026-08-09_I70-crash-reporter.md` (this log) — acquire / release

## Issues found (pre-existing — NOT fixed, per AGENT-RULES §0.6)

1. **`SENTRY_DSN` has no placeholder row** in `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` §6 registry nor a `.env.example` key (D-10/M-13 scope) — the seam keys off the dart-define alone; the release pipeline needs the registry row before any real DSN exists (S-18/M-13 handoff).
2. **`docs/to-fix/categories/15-LOGGING-OBSERVABILITY.md` (LOG-05) and `03-ERROR-HANDLING.md` (ERR-10)** still read "planned → I-70" — category files are D-03-owned; the mission locked only `docs/to-fix/TODO.md` (L-10 flipped ✅ here). Flagged for D-03/V-02.
3. **No crash reporter in the modular integration suite** (`integration_test/`): the seam has no UI surface and the global handlers are exercised by the extracted-handler unit tests; a hermetic integration flow would only re-pump what the unit test calls directly (documented in this log; runner.sh untouched).

## Commands run (reproducibility)

```bash
export AGENT_NAME=I-70-crash-reporter
for f in lib/core/services/crash_reporter.dart lib/main.dart lib/core/providers/auth_provider.dart \
  test/services/crash_reporter_test.dart docs/to-fix/TODO.md \
  docs/history/phase-02-flutter-foundation/2026-08-09_I70-crash-reporter.md; do
  tools/agent_lock.sh acquire "$f" --owner "$AGENT_NAME" --timeout 600
done
# RED: write test/services/crash_reporter_test.dart → flutter test test/services/crash_reporter_test.dart (fails: missing symbols)
# GREEN: write lib/core/services/crash_reporter.dart; edit lib/main.dart + lib/core/providers/auth_provider.dart
flutter test test/services/crash_reporter_test.dart
flutter test test/logging/ && flutter test test/providers/auth_provider_test.dart && flutter test test/widget_test.dart
flutter test
dart analyze
for f in <the 6 files>; do tools/agent_lock.sh release "$f" --owner "$AGENT_NAME"; done
```

## Sources consulted

- https://docs.sentry.io/platforms/dart/ (Flutter SDK shape: init, captureEvent, configureScope setUser/addBreadcrumb — the seam's method names mirror the Sentry API)
- https://docs.sentry.io/concepts/data-management/ (user context + PII scrubbing rationale)
- Repo patterns: `lib/core/services/telemetry_service.dart` (I-68 seam: `String.fromEnvironment` gating, sink interface, stub logging, provider in-file), `lib/core/services/revenuecat_service.dart` (I-61 driver seam), `lib/core/logging/app_logger.dart` (I-05), `lib/crypto/e2ee_primitives.dart` (package:cryptography usage precedent)
