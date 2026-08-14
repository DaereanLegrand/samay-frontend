# I-26 — Hive encryption at rest (SEC-10 / M-32) (2026-08-09)

**Agent:** I-26-hive-encryption | **Phase:** 02-flutter-foundation | **Status:** DONE

## What was built

Findings **SEC-10 / M-32** (Hive boxes `config_cache`, `photo_cache`,
`message_cache`, `notification_cache` stored as unencrypted plaintext on disk)
— closed:

1. **`lib/core/services/storage_service.dart`** — `HiveService` reworked for
   AES-256 at rest:
   - `init()` now obtains the encryption key from `flutter_secure_storage`
     under `samay.hive.key` (`_obtainEncryptionKey`): reads it; if absent or
     not a decodable 32-byte key, generates one via `Hive.generateSecureKey()`
     (CSPRNG `Random.secure()`, hive-2.2.3 source) and persists it **base64**.
     The key therefore lives in iOS Keychain / Android Keystore — never on
     disk beside the data (SEC-10 fix guidance; MASTG-BEST-0004).
   - Every box is opened with `encryptionCipher: HiveAesCipher(key)`
     (AES-256-CBC + PKCS7, hive's built-in cipher — the deprecated
     `encryptionKey` param is avoided so `dart analyze` stays clean).
     Box names/schemas unchanged (`config_cache`, `photo_cache`,
     `message_cache`, `notification_cache`).
   - `crashRecovery: false` on every open — hive's default recovery silently
     truncates a key-mismatched box; disabling it surfaces the mismatch as a
     `HiveError` so degradation is explicit and logged (see MISTAKE).
   - **Graceful degradation:** if the stored key no longer matches the boxes
     (fresh install after backup restore that did not carry the keychain
     entry), open throws → the box file is deleted (`deleteBoxFromDisk`) and
     re-created empty with the current key. Trade-off is documented in the
     class doc: these are disposable caches rebuilt from the backend.
   - **Zone guard:** every open runs inside `runZonedGuarded` because hive
     2.2.3 double-reports failed opens (see MISTAKE); the leaked duplicate
     error is absorbed and logged instead of reaching the app's global error
     handlers in `main.dart`.
   - Constructor now injectable: `HiveService({FlutterSecureStorage?
     secureStorage, HiveInterface? hive})` defaults to the real plugins.
     `init({bool initializeFlutter = true})` allows tests to init Hive on a
     temp dir and skip path_provider. No production callers exist yet (wiring
     is I-25/I-71 territory) — API is backward-compatible.
   - `SecureStorageService` untouched (I-25's file territory, same file).

2. **`test/services/storage_service_test.dart`** — rewritten from the
   no-op class-existence tests (TST-04 / H-17) into 7 real behavioral tests
   using Hive on a temp dir (`Hive.init(tempDir)`) + an in-memory
   `FlutterSecureStorage` (mocktail `Mock implements FlutterSecureStorage`):
   - `init` opens all four boxes with an encryption key (key persisted,
     32 bytes after base64 decode, written exactly once);
   - config `putAll`/`get` roundtrip;
   - empty config cache → `null`;
   - key generated once and reused across two `init()` calls
     (`writeCount == 1`, same stored key);
   - opening a box with a **wrong key throws `HiveError`** (proves encryption
     is active; `crashRecovery: false` + zone guard to absorb hive's
     duplicate-error leak);
   - on-disk `config_cache.hive` contains **no plaintext** (sentinel string
     absent from the raw file bytes — at-rest encryption proof);
   - lost-key recovery: after wiping the secure-storage key, a fresh
     `HiveService` re-creates all four boxes empty (data-loss trade-off).

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire/release <path> --owner I-26-hive-encryption`:

| File | Action |
|---|---|
| `lib/core/services/storage_service.dart` | modified (locked `d828670f…`, reworked, released) |
| `test/services/storage_service_test.dart` | rewritten (locked `3b78ec92…`, released) |
| `docs/to-fix/TODO.md` | modified (locked `b802f899…`, M-32 status, released) |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I26-hive-encryption.md` | created (locked `1b5b6a79…`, this log, released) |

No other agent held these locks (checked `tools/agent_lock.sh list` before
acquiring; I-25 was not mid-write on `storage_service.dart`).

## Commands run (reproducibility)

```bash
export AGENT_NAME="I-26-hive-encryption"
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
tools/agent_lock.sh acquire <file> --owner "$AGENT_NAME"   # per file, all 4
flutter test test/services/storage_service_test.dart        # RED: 0/7 (no-ops compile)
# …implement…
flutter test test/services/storage_service_test.dart        # 6/7 → 7/7 green
dart analyze                                                # 0 errors / 14 info (pre-existing)
flutter test test/services/storage_service_test.dart \
  test/services/supabase_service_test.dart                  # 17/17
flutter test                                                # 564 pass / 13 fail (all pre-existing structure_test, L-13 → I-48)
flutter test test/services/storage_service_test.dart ×5     # 7/7 ×5 (flake smoke)
rg "Hive\." lib/                                            # only storage_service.dart (media_service.dart mentions it in a doc comment only)
tools/agent_lock.sh release <file> --owner "$AGENT_NAME"
```

## Test results

- `test/services/storage_service_test.dart` — **7/7 pass**, stable across 5
  consecutive runs and in full-suite runs. (Baseline for this file was 2
  no-op "is a class" tests; this closes H-17 for the storage service.)
- `dart analyze` — **0 errors**, 14 info, all pre-existing
  (`use_build_context_synchronously` in `public_profile_screen.dart`).
- Full `flutter test` — **564 pass / 13 fail**; the 13 are all
  `test/structure_test.dart` (pre-existing brittle future-dir asserts,
  L-13 → I-48). Not regressions.
- `rg "Hive\." lib/` — **no other lib file opens Hive boxes**; all Hive
  access is centralized in `HiveService` (gate passed).

## Decisions made and why

- **Key in `flutter_secure_storage` as base64, key name `samay.hive.key`** —
  per SEC-10 fix guidance and MASTG-BEST-0004 (keys never beside data).
  The mission brief said "64 bytes base64"; hive's `generateSecureKey()`
  actually returns **32 bytes** (hive-2.2.3 `hive_impl.dart:246`,
  `Random.secure().nextBytes(32)`), and `HiveAesCipher` rejects any key that
  is not exactly 32 bytes (`aes_cbc_pkcs7` → `HiveAesCipher` constructor).
  32 bytes = AES-256, which is what hive encrypts with; base64 of 32 bytes
  is 44 chars. Deviation from the brief documented here.
- **`encryptionCipher: HiveAesCipher(key)` instead of deprecated
  `encryptionKey`** — same behavior, zero analyzer noise.
- **`crashRecovery: false`** — hive's default would silently truncate the
  box on key mismatch and *appear* to "work" while wiping data without a
  log trace. Disabled, the mismatch throws `HiveError` → we delete +
  re-create, and both events are logged via `AppLogger`.
- **Zone guard around every open** — hive 2.2.3's `HiveImpl._openBox` does
  `completer.completeError(error) + rethrow` on failure, leaking an
  unhandled async error into the app zone on **every failed open** (not just
  ours — any failed open anywhere). Absorbed + logged. This is also why the
  wrong-key raw-hive test wraps `openBox` in `runZonedGuarded`.
- **Injectable constructor + `initializeFlutter: false`** — lets tests use a
  real Hive on a real temp dir (real encryption path, real files) without
  path_provider/secure-storage platform channels. Matches the codebase's
  existing DI style (`MediaService({required this.client})`).
- **Remained on `hive: ^2.2.3`** — the pinned version already ships the
  full encryption API. Upstream is abandoned (last release 2021); the
  maintained continuation is `hive_ce` (drop-in import change). Switching
  packages touches `pubspec.yaml` (owned ⚙️ I-14/I-23/I-25) and the app has
  zero Hive users today — logged as a follow-up (see Issues), not done here.
- **No `integration_test/` case** (AGENT-RULES §2): the modular suite is
  hermetic by contract and a Hive+Keychain flow needs real platform
  channels. Coverage is at unit level (7 tests) against real Hive files.

## MISTAKE

- **Wrong-key open does NOT throw with hive defaults.** First draft relied on
  `Hive.openBox(name, encryptionCipher: …)` throwing on a wrong key; instead
  hive's `crashRecovery: true` default printed `Recovering corrupted box.`
  and **silently truncated + reopened empty** — the wrong-key test failed
  ("expected throw, got BoxImpl") and, worse, the degradation path would
  have silently destroyed data in production. Fixed with
  `crashRecovery: false` (mismatch → `HiveError`) + explicit delete/re-create.
- **hive 2.2.3 double-reports failed opens.** Even with the throw surfaced,
  the test then failed with an unhandled async `HiveError`/`PathNotFoundException`
  (lock-file delete in `_closeInternal` after a failed `initialize`). Root
  cause: `HiveImpl._openBox` catch block runs `completer.completeError(error,
  stackTrace); rethrow;` — the completer's future has no listener → the error
  is re-reported to the zone (confirmed with a standalone dart probe). Fix:
  `runZonedGuarded` around every open, absorbing the duplicate. This is a
  real hive-2.2.3 bug affecting production `init()` (would surface as a
  spurious crash report in `main.dart` handlers), not just tests.
- **`runZonedGuarded` nullability trap**: the SDK signature is `R?
  runZonedGuarded<R>(…)` — `result` is nullable; the first two drafts
  produced analyzer errors (async closure vs `Box<String> Function()`, and a
  `Box<String>?` return). Final shape: `runZonedGuarded<Future<Box<String>>>`
  + null-check → `StateError` (unexpected open failures are surfaced, not
  swallowed).
- **One flaky run of the lost-key test under full-suite load** (first full
  `flutter test` run only; 3 subsequent full runs + 5 isolated runs green).
  Mechanism is believed deterministic (the duplicate-error microtask always
  fires while the guarded body is still awaiting); if it ever re-flakes, the
  knob is the `Future.delayed(Duration.zero)` that keeps the guard zone alive
  one extra turn.

## Issues found (out of scope, reported)

- **`hive` upstream is abandoned; `hive_ce` is the maintained fork**
  (same API, drop-in import swap, bug fixes incl. error paths, WASM,
  DevTools inspector). Recommend a follow-up (I-23/I-25 ⚙️ pubspec) to
  migrate `hive`+`hive_flutter` → `hive_ce`+`hive_ce_flutter`.
- `HiveService.init()` has **no production caller yet** (wiring is I-25
  SecureStorage session persistence + I-71 config-provider Hive cache).
  When I-71 starts calling it, `init()` must run before the first box read;
  callers should treat the returned empty-after-loss state as "cache miss".
- `docs/to-fix/categories/08-SECURITY.md` SEC-10 row still reads
  "planned → I-26" — D-03/V-02 owned; TODO.md M-32 is flipped here
  (same convention as I-19's log).
- `docs/security/SECURITY.md` §3.1 + G-10 reference "I-26 (future)" —
  D-06/V-06 owned; may want a status touch.

## Sources consulted

- hive 2.2.3 encryption API (AES-256, `generateSecureKey`, `encryptionKey` →
  `encryptionCipher`): https://pub.dev/packages/hive
- hive source (pub cache `hive-2.2.3`): `hive_impl.dart` (openBox error
  path, generateSecureKey = 32 bytes), `crypto/hive_aes_cipher.dart`
  (AES-256-CBC PKCS7, 32-byte key requirement), `backend/vm/storage_backend_vm.dart`
  (crashRecovery truncation semantics, CRC check on wrong key)
- hive_ce (maintained community continuation): https://pub.dev/packages/hive_ce
- flutter_secure_storage 9.2.4 API: https://pub.dev/packages/flutter_secure_storage
- OWASP MASTG — data storage & key handling (MASTG-BEST-0004):
  https://mas.owasp.org/MASTG/0x05d-Testing-Data-Storage/
- SEC-10/M-32 findings: `docs/to-fix/categories/08-SECURITY.md:188-211`
- SECURITY.md §3.1 (approved primitive: Hive-at-rest AES-256, key in
  flutter_secure_storage): `docs/security/SECURITY.md:205`
- Juega reference (read-only): `flutter_secure_storage` for sensitive data +
  Hive with encryption (`08-SECURITY.md` §reference)
