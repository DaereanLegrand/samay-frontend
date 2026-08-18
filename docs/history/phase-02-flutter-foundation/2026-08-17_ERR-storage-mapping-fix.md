# ERR-MAP-FIX — StorageException mapping in error_mapper (2026-08-17)

Agent: `ERR-MAP-FIX` · Phase 02 (Flutter foundation) · No commits (working tree only).

## What was built

Added a `StorageException` branch to `ObjectX.toAppError()`
(`lib/core/extensions/error_mapper.dart`) so supabase storage failures
(`uploadBinary`, `upload`, signed-URL paths) surface truthful, user-safe
messages instead of the generic fallback.

Mapping added (before the `FormatException` branch, after the
`PostgrestException` branch):

| Storage failure shape | AppError |
|---|---|
| HTTP 401, or `error`/message contains `jwt`/`token`/`session` | `UnauthorizedError()` |
| HTTP 403 / `42501` / `error` `AccessDenied` / `InvalidKey` | `PermissionError()` |
| HTTP 404 / `error` `ObjectNotFound` | `NotFoundError()` |
| anything else | `ServerError(e.message)` — the storage message is preserved, never replaced by the generic text |

Existing branches (`AppError`, `AuthException`, `PostgrestException`,
`FormatException`, `TimeoutException`, `SocketException`/`HttpException`,
`String`) are untouched.

## Why StorageException was unmapped

`toAppError()` had an else/fall-through of `return ServerError('', this)` at
the end. `StorageException` — the type thrown by supabase storage client calls
such as `uploadBinary` — matched none of the typed branches, so every storage
failure collapsed into `ServerError('')` → message "Error del servidor. Intenta
de nuevo." The real cause (e.g. a 42501 RLS denial on avatar/cover uploads) was
masked from the user and only recoverable from logs.

## Import decision (no new dependency)

Step 0 confirmed the type resolves through the EXISTING import
`package:supabase_flutter/supabase_flutter.dart` — no new pubspec dependency
and no new import line needed:

- `supabase_flutter` (locked 2.12.4) → `export 'package:supabase/supabase.dart'`
- `supabase` (locked 2.10.6) → `export 'package:storage_client/storage_client.dart'`
- `storage_client` (locked 2.5.2; the package is `storage_client`, not
  `storage_dart`) → `export 'src/types.dart' hide FetchOptions, ToSnakeCase, ToQueryParams;`

`StorageException` lives in `storage_client-2.5.2/lib/src/types.dart`:

```dart
class StorageException implements Exception {
  final String message;
  final String? error;       // error CODE from the server JSON body
  final String? statusCode;  // STRING, e.g. '400', '404'

  const StorageException(this.message, {this.error, this.statusCode});
}
```

Note: the field is `error` (the code, e.g. `AccessDenied`, `InvalidKey`,
`ObjectNotFound`) and `statusCode` is a `String?` — there is no `errorCode`
field. The RED tests use the real constructor fields. `StorageException.fromJson`
reads `json['error']` and `json['statusCode']` (falling back to the HTTP
status string), so `Fetch._handleError` populates `error` with codes and
`statusCode` with e.g. `'400'`.

## Tests

Added `group('StorageException mappings', ...)` to
`test/core/error_mapper_test.dart` (7 tests, all `const StorageException(...)`):

1. `AccessDenied` + 400 → `PermissionError` (message "No tienes permiso para realizar esta acción.")
2. `InvalidKey` + 403 → `PermissionError`
3. 42501 status → `PermissionError` (Postgres RLS code surfaced by storage)
4. JWT-expired + 401 → `UnauthorizedError`
5. `ObjectNotFound` + 404 → `NotFoundError`
6. 500 → `ServerError` with detail AND message EQUAL to the storage message
   (not the generic text)
7. no statusCode/error → `ServerError` preserving the message

## MISTAKE (generic "Error del servidor" masked the real 42501)

During user testing, avatar/cover uploads that hit a Postgres RLS denial
(42501) surfaced only "Error del servidor. Intenta de nuevo." because
`StorageException` fell through to the generic `ServerError('', this)`. The
real cause was invisible to the user and recoverable only via logs. This
mapper branch is the fix: storage failures now keep their user-safe server
message and map the classic denial/auth/missing-object shapes to their proper
AppError categories.

MISTAKE (test construction): the assignment sketch said `statusCode: 400` and
`errorCode: 'AccessDenied'`; the real storage_client constructor takes a
**String** `statusCode` and names the code field **`error`** (no `errorCode`).
Writing the tests against the imagined signature would not compile — Step 0
(read the cached source) avoided that trap. `prefer_const_constructors` was
also flagged on the new assertions; the constructor is `const`, so the fix was
`const StorageException(...)`.

## Commands run

```bash
# Step 0 — type/inspection (read-only)
rg -i "storage" pubspec.lock        # storage_client 2.5.2 (transitive)
cat ~/.pub-cache/hosted/pub.dev/storage_client-2.5.2/lib/storage_client.dart
cat ~/.pub-cache/hosted/pub.dev/storage_client-2.5.2/lib/src/types.dart   # StorageException shape
cat ~/.pub-cache/hosted/pub.dev/supabase_flutter-2.12.4/lib/supabase_flutter.dart   # re-exports supabase
cat ~/.pub-cache/hosted/pub.dev/supabase-2.10.6/lib/supabase.dart          # re-exports storage_client

# baseline (before edits): 43/43 pass
flutter test test/core/error_mapper_test.dart

# RED
flutter test test/core/error_mapper_test.dart
#   → 43 pass + 7 fail (7 StorageException tests fall through to ServerError)

# GREEN
flutter test test/core/error_mapper_test.dart   # 50/50 pass
dart analyze lib/core/extensions/error_mapper.dart test/core/error_mapper_test.dart
#   → 13 infos, all pre-existing (mapper 78/88/97 prefer_const; test 16-40 & 466-467
#     — the shifted original AppError-passthrough + ServerError-defaults groups).
#     ZERO new issues in the added lines.
```

Full suite deliberately NOT run (per assignment).