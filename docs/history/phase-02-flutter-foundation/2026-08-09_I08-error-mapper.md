# 2026-08-09 — I-08: Error-mapper hardening + ERR-09 test coverage (ERR-03 residual)

**Agent:** I-08 (error hierarchy + mapper)
**Status:** DONE
**Scope:** `lib/core/extensions/error_mapper.dart` (TimeoutException → NetworkError; user-safe
fallback), `lib/core/errors/app_error.dart` (ServerError.original — strictly needed),
`test/core/error_mapper_test.dart` (new, 37 tests), `test/widgets/show_app_error_test.dart`
(semantics update), `integration_test/error_flow_test.dart` (new) + `runner.sh` registration,
`docs/to-fix/TODO.md` note (M-12 / ERR-09 residual).

## What was built

1. **`error_mapper.dart`** — two residual fixes from I-07's flag:
   - `TimeoutException` → `NetworkError(this)` (was leaking raw `'TimeoutException after …'`
     via the fallback). `dart:async` import added.
   - Final fallback hardened: unknown errors → `ServerError('', this)` — generic user-safe
     message, **no raw `toString()`**; the original error is preserved in
     `ServerError.original` for logging (mirrors `NetworkError.original`).
   - Non-empty `String` errors still pass through verbatim (`ServerError(this as String)`) —
     required to preserve the pre-mapped-message display path (`showAppError` receives
     `auth.error` Strings; `login_screen.dart:41` depends on it) and `show_app_error_test`'s
     String-verbatim contract.
   - Every pre-existing mapping untouched: AuthException codes (rate-limit ×3, invalid_credentials,
     otp_expired, jwt/token/session, fallback), PostgrestException codes
     (PGRST301/23503/23505/42501/P0001/28*/42*/default), FormatException, Socket/Http.
2. **`app_error.dart`** — `ServerError` gains `final Object? original` + trailing optional
   positional ctor param `ServerError([this.detail = '', this.original])`. Fully
   backward-compatible (no existing call site breaks); additive so I-11 can extend later.
3. **Tests** — `test/core/error_mapper_test.dart` (new dir `test/core/`): 37 table-driven
   tests covering every AuthException code mapping, every PostgrestException code mapping
   (23503/23505/42501/P0001/28* ×3/42* ×3/unmapped/null-code), FormatException,
   SocketException + HttpException (original carried, identity check), **TimeoutException
   → NetworkError (NEW)** incl. no-internals-leak and with-duration variants, AppError
   passthrough (same-instance), unknown `Exception`/`StateError` → generic `ServerError`
   with assertions that the raw string is NOT in `message` and `original` carries it
   (identity), no type-name/stack-fragment leaks, String verbatim, empty-String generic,
   null-safe behavior (null codes on Auth/Postgrest exceptions), `original`-field defaults.
4. **`test/widgets/show_app_error_test.dart`** (I-06's file, required change — see
   Decisions): raw `Exception` now renders `ServerError().message` and the raw text is
   asserted ABSENT; String verbatim test unchanged; TimeoutException covered at unit +
   integration layers.
5. **`integration_test/error_flow_test.dart`** (new, hermetic) + registered in
   `runner.sh` `ORDERED_FLOWS` after `auth_flow_test.dart`: raw exception → generic
   message (no `sqlstate`/`supabase_service` leak), TimeoutException → network message,
   String verbatim — through the real app shell (`SamayApp`/login route).

## Decisions & rationale

1. **String passthrough branch** kept: without it, `login_screen.dart:41`'s
   `showAppError(context, msg, blocking: true)` (msg = already-mapped `auth.error` String)
   would render the generic server message and swallow the real error — a UX regression
   masked as "fix". Strings are developer-authored, already user-safe; passing them through
   preserves pre-existing behavior (`ServerError(toString())` on a String was the String
   itself).
2. **`ServerError('', this)`** — positional ctor; named+positional optional params can't
   mix in Dart. All existing `ServerError(e.message)` / `ServerError()` sites unaffected.
3. **`show_app_error_test.dart` updated under lock** (owner I-06 per FILE-OWNERSHIP;
   assignment requires it — the tests pinned the exact leak being removed). Coordination
   noted per AGENT-RULES §4. Category files (`03-ERROR-HANDLING.md`) are D-03-owned and
   left for D-03 re-verification (I-07 precedent).
4. **`test/core/`** new directory mirrors `lib/core/` layout (test-layout convention).
5. `TimeoutException` uses `NetworkError(this)` (original carried for logging), matching
   the Socket/Http pattern; the message stays the fixed user-safe copy.

## MISTAKE blocks

- **MISTAKE (test compile):** `TimeoutException()` without a message does not compile on
  this SDK (3.11.4): signature is `TimeoutException(this.message, [this.duration])` — the
  second positional is a `Duration`, not `reason`, and `message` is required. Fixed the
  "no-message" case to a with-duration construction. Verified directly in
  `dart-sdk/lib/async/future.dart:1144`.
- **MISTAKE (concurrency):** full-repo `dart analyze` shows 56 issues while I worked —
  ALL in other agents' in-flight files: `test/services/supabase_service_test.dart`
  (rewritten mid-session to reference `AuthService`/`ConfigService` — service-decomposition
  work, I-09/I-44/I-11 domain) and `lib/core/models/*` (I-10 freezed work). Zero issues in
  my files (`dart analyze` on the 5 touched paths → "No issues found!").

## Validation

```bash
flutter test test/core/error_mapper_test.dart        # 37/37 pass (red → compile errors on original → green)
flutter test test/widgets/show_app_error_test.dart   # 6/6 pass (updated semantics)
flutter test integration_test/error_flow_test.dart   # 3/3 pass
flutter test test/widgets/ test/utils/               # 67/67 pass
flutter test test/router/app_router_test.dart        # 62/62 pass (regression)
flutter test test/providers/                         # 1 pass / 3 fail = EXACT documented baseline
                                                    #   (auth_provider Supabase-not-initialized; I-47's set)
dart analyze (5 touched paths)                       # No issues found!
dart analyze (repo)                                  # 0 issues in my files; 56 transient issues in
                                                    #   concurrent agents' in-flight files (not mine)
```

## Commands run

```bash
export AGENT_NAME="I-08-error-mapper"
tools/agent_lock.sh acquire lib/core/extensions/error_mapper.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire lib/core/errors/app_error.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire test/core/error_mapper_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire test/widgets/show_app_error_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire docs/history/phase-02-flutter-foundation/2026-08-09_I08-error-mapper.md --owner "$AGENT_NAME"
tools/agent_lock.sh acquire integration_test/runner.sh --owner "$AGENT_NAME"
tools/agent_lock.sh acquire integration_test/error_flow_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire docs/to-fix/TODO.md --owner "$AGENT_NAME"   # awaited I-10-models release
# red → green → validate (see Validation) → release all
```

## Issues found / reported (not fixed — out of scope)

- **`AuthRetryableFetchException` (gotrue) maps to `UnauthorizedError()`**, not
  `NetworkError()`: it's a subclass of `AuthException` with no code and a message without
  jwt/token/session keywords, so it falls into the auth fallback. I-07's
  `defaultShouldRetry` already treats it as transient/retryable — so after retries are
  exhausted a user sees "Sesión expirada…" for what is really a network failure. Adding the
  mapping would be a behavior change beyond this mission's scope; flagged for I-11/I-78
  or the mapper owner.
- **`docs/to-fix/TODO.md` lock contention**: held by I-10-models for the whole session;
  TODO.md note applied when the lock became free (see report).
- **Concurrent in-flight analyzer errors** in `test/services/supabase_service_test.dart`
  (references `AuthService`/`ConfigService` that don't exist yet) and `lib/core/models/*`
  — service decomposition (I-11/I-44/I-09) and freezed models (I-10) mid-flight; transient.
