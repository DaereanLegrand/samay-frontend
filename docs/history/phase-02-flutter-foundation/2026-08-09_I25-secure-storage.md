# I-25 — Secure session storage wired to auth (SEC-11 / M-33) (2026-08-09)

**Agent:** I-25-secure-storage | **Phase:** 02-flutter-foundation | **Status:** DONE

## What was built

Finding **SEC-11 / M-33** (`SecureStorageService` existed but nothing used it;
Supabase persisted its session via the SDK default) — closed:

1. **`lib/core/services/secure_session_storage.dart`** (new):
   - `SecureSessionStorage extends LocalStorage` — the `authOptions.localStorage`
     seam. The session JSON (access JWT + refresh token) is persisted under
     `samay.auth.session` via `flutter_secure_storage` (iOS Keychain / Android
     Keystore). Contract verified against supabase_flutter 2.12.4
     `SupabaseAuth.initialize()`: `initialize()` (probe) → `hasAccessToken()` /
     `accessToken()` (cold-start restore via `setInitialSession`) →
     `persistSession()` (every `SIGNED_IN`/`TOKEN_REFRESHED`) →
     `removePersistedSession()` (`SIGNED_OUT`).
   - `SecurePkceStorage extends GotrueAsyncStorage` — the `authOptions.pkceAsyncStorage`
     seam for GoTrue's PKCE code verifier (gotrue 2.20.0 stores it under
     `sb-<ref>-auth-token-code-verifier`; we namespace all keys under
     `samay.auth.`).
   - **Constructor injection:** both take `{FlutterSecureStorage? secureStorage}`,
     defaulting to the real plugin — tests inject a mocktail fake, no platform
     channels (same DI style as `HiveService`/`MediaService`).
   - **Graceful fallback (documented in the class docs):** every plugin call is
     wrapped; on the first `PlatformException` (missing/broken plugin) a
     `_FallbackAwareStore` flips **one-way** to an in-memory map and logs a
     warning via `AppLogger`. The user stays signed in for the app session; only
     cross-restart persistence is lost. Never crashes — the "recovered plugin"
     case is also memory-served so behavior is deterministic.

2. **`lib/main.dart`** — `Supabase.initialize` now passes
   `authOptions: FlutterAuthClientOptions(localStorage: SecureSessionStorage(),
   pkceAsyncStorage: SecurePkceStorage(), detectSessionInUri: false)`,
   mirroring the harness pattern in `test/router/app_router_test.dart`. I-05's
   `AppLogger` init and I-34's dotenv removal were preserved untouched (I re-read
   main.dart after acquiring its lock — I-34's changes were already in the tree).

3. **`docs/to-fix/TODO.md`** — M-33 flipped to ✅ with evidence summary.

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire/release <path> --owner I-25-secure-storage`:

| File | Action |
|---|---|
| `lib/core/services/secure_session_storage.dart` | created (lock `23ad92ec…`†, released after tests green) |
| `test/services/secure_session_storage_test.dart` | created (locked, released) |
| `lib/main.dart` | modified (locked after **I-34-env-dartdefine released it** — waited, then re-read the I-34-modified version before touching) |
| `docs/to-fix/TODO.md` | modified (locked after **I-33 released it** — waited; I-33's uncommitted changes to the file were preserved) |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I25-secure-storage.md` | created (this log) |

† Lock IDs printed by `tools/agent_lock.sh` are per-slot hashes; the acquire
output was `[lock] ACQUIRED <path> by I-25-secure-storage` for each of the five
files (no contention on the new files; waited on main.dart + TODO.md).

## Commands run (reproducibility)

```bash
export AGENT_NAME="I-25-secure-storage"
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
tools/agent_lock.sh list                       # main.dart held by I-34, TODO.md by I-33
tools/agent_lock.sh acquire <new files x3> --owner "$AGENT_NAME"
flutter test test/services/secure_session_storage_test.dart   # RED: compile error, class missing
# …implement lib/core/services/secure_session_storage.dart…
flutter test test/services/secure_session_storage_test.dart   # 16/17 → fixed 1 test → 17/17
tools/agent_lock.sh acquire lib/main.dart --owner "$AGENT_NAME"  # waited for I-34
# …wire authOptions in main.dart…
tools/agent_lock.sh release lib/main.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire docs/to-fix/TODO.md --owner "$AGENT_NAME"  # waited for I-33
# …flip M-33…
tools/agent_lock.sh release docs/to-fix/TODO.md --owner "$AGENT_NAME"
dart analyze                                        # 0 errors (see Test results)
flutter test test/services/secure_session_storage_test.dart   # 17/17
flutter test test/router/app_router_test.dart                  # green (regression gate)
tools/agent_lock.sh release <files> --owner "$AGENT_NAME"
```

## Test results

- `test/services/secure_session_storage_test.dart` — **17/17 pass**:
  LocalStorage contract (initialize, hasAccessToken false/true, accessToken
  null/value, persistSession under `samay.auth.session`, removePersistedSession
  clears, overwrite), GotrueAsyncStorage contract (setItem/getItem/removeItem
  with the `samay.auth.` prefix), and the fallback group (broken plugin: reads,
  writes, removes, PKCE all survive in-memory; one-way degradation proof).
- `dart analyze` — **0 errors** (pre-existing info lints only).
- `flutter test test/router/app_router_test.dart` — **green** (the wiring
  pattern my main.dart change mirrors; regression gate for Supabase init).

## Decisions made and why

- **New file `secure_session_storage.dart` instead of touching
  `storage_service.dart`** — I-26 (Hive encryption) owns that file's current
  shape; my mission brief also names the new file. `SecureStorageService` stays
  untouched (its generic read/write/delete API remains for non-auth secrets).
- **Keys under `samay.auth.`** — matches the mission brief and the repo's
  existing `samay.hive.key` namespace convention (I-26). The GoTrue PKCE key
  (`sb-<ref>-auth-token-code-verifier`) is namespaced as `samay.auth.<key>` so
  every auth secret lives under one prefix.
- **One-way fallback, engaged on first plugin failure** — a plugin that throws
  once and "recovers" would otherwise flip-flop between keychain and memory
  (deterministic-behavior requirement). Logged at WARN via `AppLogger` so the
  degradation is observable in `samay.log`.
- **`detectSessionInUri: false`** — mobile deep-link session recovery is not
  used (invite tokens are router/extra-driven, I-66 territory); mirrors the
  harness. PKCE code-verifier storage still works without it.
- **Mocktail fake instead of `flutter_secure_storage` platform-mock** — plugin
  is a MethodChannel; same approach as `test/services/storage_service_test.dart`
  (I-26) and `permission_service_test.dart` (I-28).

## MISTAKE

- **First fallback test asserted the wrong sequence.** The test had
  `persistSession()` run *before* any read, so the write went to the (working)
  plugin while the later `hasAccessToken()` read engaged the fallback —
  memory had nothing, `hasAccessToken` correctly returned false, and the test
  expected true. Fixed the test to the intended deterministic scenario:
  `initialize()` (the probe) engages the fallback first, then the write is
  served from memory and verified via `verifyNever` on the plugin's `write`.
  This also surfaced the design property that the probe in `initialize()` is
  what makes startup behavior deterministic.
- **`PlatformException` is not a const constructor** — first test draft used
  `const PlatformException(...)`; compile error, removed `const`.
- **mocktail named-argument matcher** — `verifyNever(... value: any())` throws
  an "argument matcher" error; must be `any(named: 'value')`.

## Issues found (out of scope, reported)

- **I-30 must still land**: with the session now persisted in the keychain,
  the *restore* path (`hasAccessToken` → `setInitialSession`) works at cold
  start, but the SDK's auto-refresh + explicit `refreshSession()` on
  `TOKEN_REFRESHED` (SEC-04/H-22, G-04) remain I-30's scope — the tokens we
  persist are only as fresh as the SDK keeps them.
- **`SecureStorageService` (generic API in storage_service.dart) is still
  unreferenced** by any caller — fine as a generic seam, but note for the
  final sweep (I-78): if nothing adopts it, it is dead code.
- **No `integration_test/` case** (AGENT-RULES §2): the modular suite is
  hermetic by contract and a Keychain-backed session flow needs a real
  platform channel. Unit coverage (17 tests) is the seam's boundary.
- `docs/to-fix/categories/08-SECURITY.md` SEC-11 row and
  `docs/security/SECURITY.md` §2.3/G-04 still read "open"/"I-25" — D-03/V-02
  and D-06/V-06 owned (same convention as I-26's log).

## Sources consulted

- supabase_flutter 2.12.4 source (pub cache): `lib/src/local_storage.dart`
  (`LocalStorage` contract, `SharedPreferencesLocalStorage` reference impl),
  `lib/src/supabase_auth.dart` (initialize/recoverSession/persist flow),
  `lib/src/flutter_go_true_client_options.dart` (`FlutterAuthClientOptions`
  shape) — the resolved lockfile version (pubspec declares `^2.8.4`).
- supabase 2.10.6 (pub cache): `lib/src/supabase_client.dart`
  (`gotrueAsyncStorage: authOptions.pkceAsyncStorage` wiring).
- gotrue 2.20.0 (pub cache): `lib/src/types/gotrue_async_storage.dart`
  (`GotrueAsyncStorage` contract), `lib/src/gotrue_client.dart`
  (`${Constants.defaultStorageKey}-code-verifier` key used for PKCE).
- flutter_secure_storage 9.2.4 API: https://pub.dev/packages/flutter_secure_storage
- OWASP MASTG — data storage & key handling (MASTG-BEST-0004):
  https://mas.owasp.org/MASTG/0x05d-Testing-Data-Storage/
- SEC-11/M-33 findings: `docs/to-fix/categories/08-SECURITY.md:200-214`
- SECURITY.md §2.3 (auth/session handling, G-04): `docs/security/SECURITY.md:121-137`
