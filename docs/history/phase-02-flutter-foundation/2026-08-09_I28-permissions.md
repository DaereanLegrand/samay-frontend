# 2026-08-09 — I-28: Runtime Permission Checks (SEC-07 / M-29 / DEP-11)

**Agent:** I-28 (permission service + permission_handler wiring)
**Status:** DONE
**Scope:** `permission_handler` dependency, `PermissionService` + prompt UX
(rationale SnackBar on deny, settings dialog on permanent deny), Android/iOS
manifest entries, group-cover picker wiring, tests, TODO/category statuses.

---

## 1. What was built

### `pubspec.yaml`
- Added `permission_handler: ^12.0.3` (dependencies).

### `lib/core/services/permission_service.dart` (new)
- `enum PermissionOutcome { granted, denied, permanentlyDenied }` — the
  three states UI code acts on (SEC-07 fix spec).
- `class PermissionService` — the **single seam** for every OS permission
  (camera/photo-library today, QR scanner I-57 and photo uploads I-59 later):
  - `Future<PermissionOutcome> ensure(Permission)` — pure mapping of the
    plugin's six statuses: granted/limited/provisional → `granted`;
    permanentlyDenied → `permanentlyDenied`; denied/restricted → `denied`.
  - `Future<bool> openSettings()` — wraps `ph.openAppSettings()`.
  - `Future<bool> ensureWithPrompt(BuildContext, …)` — the full UX:
    granted → `true`; denied → rationale `SnackBar` → `false`;
    permanentlyDenied → `AlertDialog` with "Abrir ajustes" (opens app
    settings) / "Cancelar" → `false`.
- Both plugin calls are **injectable** (`PermissionRequester` function +
  `openSettings` function). `permission_handler` is a MethodChannel plugin
  that cannot run in widget tests, so tests fake these seams (thin wrapper,
  no mocktail needed — see decisions).

### `lib/features/groups/create_group_screen.dart`
- `_pickImage()` now requests `Permission.photos` **before** `ImagePicker`
  opens the gallery; rationale SnackBar on deny, settings dialog on permanent
  deny (localized via new ARB keys). Picker flow otherwise untouched.
- `CreateGroupScreen({…, this.permissions})` — optional injected
  `PermissionService` for tests; defaults to the real service.

### Platform config
- `android/app/src/main/AndroidManifest.xml`: `CAMERA`,
  `READ_MEDIA_IMAGES` (API 33+), `READ_EXTERNAL_STORAGE` with
  `android:maxSdkVersion="32"` (API ≤ 32) — current Android best practice.
- `ios/Runner/Info.plist`: `NSCameraUsageDescription` +
  `NSPhotoLibraryUsageDescription` (Spanish, es-first app).
- `ios/Podfile`: `PERMISSION_CAMERA=1` + `PERMISSION_PHOTOS=1` in
  `GCC_PREPROCESSOR_DEFINITIONS` — permission_handler 8.0.0+ disables every
  iOS permission by default; without the macros the plugin throws
  `MissingPluginException` at runtime (the exact SEC-07 bug class). Podfile
  is ⚙️ M-28's file — required by this mission, noted in the final report.

### l10n
- 5 new ARB keys (es + en with metadata): `permissionsPhotoRationale`,
  `permissionsCameraRationale` (prepared for I-57), `permissionsSettingsTitle`,
  `permissionsSettingsBody`, `permissionsOpenSettings`; regenerated via
  `flutter gen-l10n`.

### Tests — `test/services/permission_service_test.dart` (new)
TDD-first: written before the service existed (RED: "Method not found:
PermissionService"), green after. **14 tests**:
- `ensure()` mapping: granted/limited/provisional → granted; denied →
  denied; permanentlyDenied → permanentlyDenied; restricted → denied;
  passes the exact `Permission` through.
- `openSettings()` delegates to the injected function.
- `ensureWithPrompt()` widget tests (fake service via injected seams):
  granted → true + no SnackBar/dialog; denied → rationale SnackBar + false;
  permanentlyDenied + cancel → dialog closes, settings NOT opened, false;
  permanentlyDenied + "Abrir ajustes" → `openSettings()` invoked, false.
- `CreateGroupScreen` wiring: denied photo permission → requests
  `Permission.photos` + localized rationale SnackBar; permanentlyDenied →
  localized settings dialog with the settings/cancel actions.

Validation results (2026-08-09):
```
flutter pub get                                    # clean (permission_handler 12.0.3 resolved)
flutter test test/services/permission_service_test.dart        # 14/14
flutter test test/features/groups_screens_test.dart            # 19/19
flutter test test/l10n/ test/pubspec_test.dart                 # green
flutter test test/services/                                   # 29/29
dart analyze                                                 # 0 errors; only pre-existing info lints (14 total, none in I-28 files — the one create_group info at line 106 is pre-existing code, was line 79 before my edit)
```

### Docs
- `docs/to-fix/categories/11-DEPENDENCY-MANAGEMENT.md` — DEP-11 → ✅.
- `docs/to-fix/categories/08-SECURITY.md` — SEC-07 → ✅.
- `docs/to-fix/TODO.md` — M-29 → ✅.

---

## 2. Decisions & rationale

1. **`permission_handler: ^12.0.3`, not 13.0.0.** Research (pub.dev, 2026-08-09):
   latest is **13.0.0** (published 9 days ago) but its `permission_handler_android`
   requires **compileSdk 37**; the repo builds with `flutter.compileSdkVersion`
   (36) in `android/app/build.gradle` and forcing a bump there is M-27's
   domain. 12.0.3 needs only compileSdk 35 → works with 36, zero gradle
   changes. Mission said "verify latest compatible" — 12.0.3 is it.
2. **Thin-wrapper injection instead of mocktail.** `permission_handler` is a
   platform plugin; mocking its Dart surface via mocktail would couple tests
   to plugin internals. `PermissionService` accepts
   `Future<PermissionStatus> Function(Permission)` + `openSettings` — tests
   pass closures (pattern already proven by `test/services/supabase_service_test.dart`).
3. **`ensure()` (pure) + `ensureWithPrompt()` (UX) split.** The mission
   describes `ensure(Permission)` returning the status enum AND showing
   SnackBar/dialog. SnackBars need a `BuildContext`; splitting keeps `ensure()`
   testable without widgets while `ensureWithPrompt()` owns the UX. I-57 can
   use either.
4. **Prompt strings passed as parameters, not resolved inside the service.**
   Keeps the service decoupled from l10n (callers pass `AppLocalizations`
   values) and makes widget tests independent of the ARB.
5. **`limited`/`provisional` count as granted** — iOS photo-library partial
   access still lets `ImagePicker` work; hard-blocking it would be a UX bug.
6. **Spanish usage descriptions in Info.plist** — the app is es-first
   (`locale: es`, all ARB es); the OS shows these strings to users.
7. **Integration suite not extended.** Hermetic integration flows can't fake
   the permission plugin (real `CreateGroupScreen` → real
   `PermissionService` → MethodChannel). The permission UX is covered at the
   widget layer; on-device permission flows are I-57's scanner domain.

## MISTAKE blocks

- **MISTAKE (locks):** first lock batch hung the shell for 5 minutes — the
  macOS box has no `timeout`/`gtimeout` binary, and `tools/agent_lock.sh`
  without `--timeout` waits up to 1800s per file. Use
  `acquire <file> --owner $AGENT_NAME --timeout <s>` and pass a larger tool
  timeout to the shell instead.
- **MISTAKE (wait strategy):** `pubspec.yaml`/`create_group_screen.dart`/
  `08-SECURITY.md` were held by I-27-sanitizer and `TODO.md` by
  I-22-image-processor for 45+ minutes. Per AGENT-RULES §1 I did all
  non-conflicting work first (platform files, ARB, service, tests, DEP-11
  doc) and only then blocked on the remaining locks.

## Concurrency notes

- Held locks while writing: pubspec.yaml, pubspec.lock,
  create_group_screen.dart, docs/to-fix/TODO.md,
  docs/to-fix/categories/08-SECURITY.md were acquired once the holders
  (I-22/I-27) released; all edits re-read immediately before modification.

## Commands run (reproducibility)

```
export AGENT_NAME=I-28-permissions
tools/agent_lock.sh acquire <each file> --owner "$AGENT_NAME" --timeout 1500
flutter gen-l10n
flutter test test/services/permission_service_test.dart   # RED → GREEN (14/14)
flutter test test/features/groups_screens_test.dart       # 19/19
flutter test test/l10n/ test/pubspec_test.dart            # green
flutter test test/services/                              # 29/29
dart analyze                                            # 0 errors, no new infos
tools/agent_lock.sh release <each file> --owner "$AGENT_NAME"
```
