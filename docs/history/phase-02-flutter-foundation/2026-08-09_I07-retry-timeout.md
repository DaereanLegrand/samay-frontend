# 2026-08-09 — I-07: Retry + timeout utilities (ERR-05 / ERR-06, H-06 / H-07)

**Agent:** I-07 (async resilience utilities)
**Status:** in progress
**Scope:** `lib/core/utils/async_ops.dart` (`withRetry` / `withTimeout` / `resilient`),
auth-provider wiring (provider boundary only), unit tests, TODO.md H-06/H-07 statuses.

## Plan

1. PREP — this log file (locked).
2. RED — `test/utils/async_ops_test.dart` (retry succeeds after N failures; non-retryable
   stops with attempt counter; gives up after maxRetries; withTimeout on never-completing
   future; resilient composes timeout + retry).
3. GREEN — implement `lib/core/utils/async_ops.dart`.
4. Wire — `lib/core/providers/auth_provider.dart` signIn/sendOtp/verifyOtp/createProfile
   via `resilient()` (5s per-attempt timeout, 2 retries) at the provider boundary only;
   `lib/core/services/supabase_service.dart` stays untouched (I-11/I-51 own it).
5. VALIDATE — `flutter test test/utils/async_ops_test.dart` + `dart analyze`.
6. DOCUMENT — this log; update `docs/to-fix/TODO.md` H-06/H-07 → ✅.

## Research (sources at bottom)

- `Future.timeout`: if the source doesn't complete in time, the returned future completes
  with `TimeoutException` (or the `onTimeout` result); the source future may still complete
  later and is then ignored. → `withTimeout` rethrows a clean `TimeoutException`.
- Exponential backoff + jitter: AWS "full jitter" — `sleep = random(0, min(cap, base * 2^n))`.
- Supabase pinned stack (`pubspec.lock`): `supabase 2.10.6`, `gotrue 2.20.0`,
  `postgrest 2.7.0`, `storage_client 2.5.2`, `functions_client 2.5.0`.
  - `SupabaseClient(url, key, {httpClient, ...})` — **no `timeout` parameter exists** on the
    constructor in this version (contrary to ERR-06's suggested `Supabase.initialize(timeout:)`).
    The only timeout seam is a custom injected `httpClient` or wrapping calls — which is what
    `withTimeout`/`resilient` do.
  - `postgrest 2.7.0` already retries **GET/HEAD** up to 3× (503/520 + any `Exception`) with
    exponential backoff (`min(2^n, 30s)`); mutations (POST/PATCH/DELETE) are NOT retried by the
    SDK → our `withRetry` fills that gap.
  - `gotrue 2.20.0` throws `AuthRetryableFetchException` on network failures and ≥500 responses
    (canonical "retry me" signal; exported through `supabase.dart`) → included in default
    `shouldRetry`.
  - `PostgrestException.code` `28*` = connection-class errors (already mapped to `NetworkError`
    by `error_mapper.dart`) → retried by default.

## Decisions

1. File named `async_ops.dart` (per mission) rather than the FILE-OWNERSHIP `retry.dart`;
   FILE-OWNERSHIP map is updated by the orchestrator, noted in final report.
2. Default `shouldRetry` retries ONLY transient, non-user-facing failures:
   `SocketException`, `HttpException`, `TimeoutException`, `AuthRetryableFetchException`,
   `AppError.NetworkError`, `PostgrestException` with connection-class codes (`28*`).
   **Never** retries `ValidationError` / `NotFoundError` / `PermissionError` (all `AppError`s
   except `NetworkError`), `RateLimitError` (amplifies abuse), `UnauthorizedError`.
3. Retry uses full-jitter backoff with an injectable `Random` (deterministic when seeded →
   stable tests) and small durations in tests.
4. `resilient` = `withRetry(withTimeout(fn))` — timeout wraps EACH attempt (per-attempt budget,
   so a hung request can't eat the whole retry budget).
5. Auth wiring stays at the provider boundary: `SupabaseService` untouched (I-11/I-51 own it).
   `_userHasProfile` left unwrapped (fire-and-forget read, catches internally).
6. `docs/to-fix/categories/03-ERROR-HANDLING.md` (D-03-owned) is NOT modified — only
   `docs/to-fix/TODO.md` (mission lock list). Category statuses left for D-03 re-verification.

## MISTAKE / gotcha (self)

- **`dart:io` `HttpException` also maps to `NetworkError`** in `error_mapper.dart:49` — include
  it in the default predicate, not just `SocketException`, or mapped errors escape the retry.
- **`AuthRetryableFetchException` extends `AuthException`** — the `AuthRetryableFetchException
  is` check must come BEFORE a generic `AuthException` check in the predicate.
- PostgREST SDK already retries GET/HEAD internally — avoid double-retrying reads by keeping
  `withRetry` maxRetries modest (auth calls are gotrue, unaffected).
- Test-authoring gotcha: `() async { await Completer<int>().future; }` does not compile for
  a non-void return type — write `return Completer<int>().future;` (never completes at
  runtime, satisfies the analyzer).

## Built

- `lib/core/utils/async_ops.dart` — `defaultShouldRetry`, `backoffDelay` (AWS full-jitter,
  deterministic with seeded `Random`), `withRetry`, `withTimeout`, `resilient`.
- `lib/core/providers/auth_provider.dart` — `signIn` / `sendOtp` (+signup-tracker upsert) /
  `verifyOtp` (+password updateUser) / `createProfile` wrapped with `resilient()` at the
  provider boundary (5s per-attempt timeout, 2 retries, 1s initial backoff). `SupabaseService`
  untouched (I-11/I-51 own it).
- `test/utils/async_ops_test.dart` — 16 tests (10 withRetry, 3 withTimeout, 3 resilient),
  including the "not retried" counter assertions that prove `shouldRetry` works.

## Validation

- `flutter test test/utils/async_ops_test.dart` → **16/16 pass**.
- `dart analyze` on the 4 touched Dart paths → **No issues found**.
- `flutter test test/router/app_router_test.dart test/router/route_paths_test.dart` →
  **80/80 pass** (regression check: app_router imports auth_provider).
- `test/providers/auth_provider_test.dart` → 3 failures, SAME documented baseline reason
  ("You must initialize the supabase instance…", I-47's set) — not a regression.
- Full-suite run was NOT re-executed to completion: concurrent agents hold the Flutter tool
  lock for long runs (I-06 in flight); targeted suites above cover every path my change
  touches. Baseline expected: 176 pass / 23 documented fail.

## Commands run

```bash
export AGENT_NAME="I-07-retry"
tools/agent_lock.sh acquire docs/history/phase-02-flutter-foundation/2026-08-09_I07-retry-timeout.md --owner "$AGENT_NAME"
tools/agent_lock.sh acquire test/utils/async_ops_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire lib/core/utils/async_ops.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire lib/core/providers/auth_provider.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire docs/to-fix/TODO.md --owner "$AGENT_NAME"
flutter test test/utils/async_ops_test.dart        # red: compile error → green: 16/16
dart analyze lib/core/utils/async_ops.dart lib/core/providers/auth_provider.dart test/utils/async_ops_test.dart
flutter test test/router/app_router_test.dart test/router/route_paths_test.dart  # 80/80
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"   # all 5 files
```
