# EF-02 — Analyzer cleanup: `dart analyze` to zero issues

**Date:** 2026-08-09 · **Agent:** EF-02 · **Role:** Flutter analyzer cleanup
**Baseline:** 15 issues (2 warnings + 13 info, 0 errors) · **Result:** `dart analyze` → **"No issues found!"**

---

## What was built

The user directive: fix ALL existing analyzer issues. The 15 issues were:

- **2 `unused_import` warnings** (lib + test)
- **13 `use_build_context_synchronously` infos** — all the same root cause: the
  guard `if (context.mounted)` was placed on the `BuildContext` instead of on
  the `State` (`if (mounted)`). The lint treats `context.mounted` as an
  "unrelated" guard because it cannot prove `context == State.context`; the two
  values are identical at runtime (`State.mounted` is literally the
  element's `mounted`), so swapping the guard target is a pure no-op behavior
  change while satisfying the lint.

## Sites fixed (13 infos)

| File | Line(s) | Fix |
|---|---|---|
| `lib/features/groups/create_group_screen.dart` | 106 (`_create` catch) | `if (context.mounted)` → `if (mounted)` |
| `lib/features/groups/donate_shards_screen.dart` | 42, 45, 49 (`_donate`) | `if (context.mounted)` → `if (mounted)` (×3) |
| `lib/features/groups/group_detail_screen.dart` | 320 (`_leaveGroup`) | `if (context.mounted)` → `if (mounted)` |
| `lib/features/profile/public_profile_screen.dart` | 70, 77 (`_sendRequest`) · 93, 100 (`_acceptRequest`) · 248, 255 (`_blockUser`) · 267, 274 (`_unblockUser`) | `if (context.mounted)` → `if (mounted)` (×8) |

Each site was re-read in context before editing; every method is a `State`
method using `State.context` only, so `mounted` is the correct guard. Zero
behavior change — the guards evaluate the same element flag.

## Sites intentionally NOT touched (correct as-is)

- `lib/shared/widgets/show_app_error.dart:19` — `if (!context.mounted)` in a
  **top-level function** (no State); `context.mounted` is the only valid guard.
- `lib/core/services/permission_service.dart:81` — same pattern in a non-State
  service class.
- `lib/features/profile/settings_screen.dart:60` — `context.mounted` in a
  `ConsumerWidget.build` closure (no State).

## Unused-import fixes (2 warnings)

- `lib/core/services/shards_service.dart:1` — removed
  `import 'package:samay/core/logging/app_logger.dart';` (AppLogger never used
  in the file).
- `test/services/secure_session_storage_test.dart:6` — removed
  `import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;`
  (the test only uses the samay storage classes + mocktail).

## Decisions made and why

- **Guard on the State, not the context**: the lint's recommended fix per
  Flutter docs (use_build_context_synchronously — "Guard a 'State.context' use
  with a 'mounted' check on the State"). Minimal diff, same semantics.
- **No `// ignore:` comments needed**: all 13 sites were fixable cleanly; no
  legitimately unfixable site existed.
- **Out-of-scope bugs found, reported only (see Issues):** unguarded
  `setState` in `create_group_screen.dart:_create` catch/finally paths and
  `group_members_screen.dart:_load` — pre-existing, not part of the analyzer
  cleanup (I-06 owns the catch-block sweep).

## MISTAKE / gotcha

- **`context.mounted` vs `mounted` subtlety**: the analyzer only flags
  `context.mounted` when the enclosing code is inside a `State`/`ConsumerState`
  method. Copy-pasting the same guard into a non-State function (like
  `show_app_error.dart`) is correct — do not "fix" those; the lint is happy
  with them.
- **`flutter test` flaky-frame warning**: the `secure_session_storage_test`
  run printed a `_WaitForOutstandingCallbacks` stack trace before the summary
  (a test-side pending-frame artifact), but the suite still reported
  `+17: All tests passed`. Not a regression; baseline behavior.

## Commands run (reproducibility)

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
dart analyze                                   # baseline: 15 issues → final: No issues found!
flutter test test/services/secure_session_storage_test.dart   # +17 All tests passed
flutter test test/features/                    # +91 All tests passed
flutter test test/router/app_router_test.dart test/services/permission_service_test.dart test/perf/list_view_builder_test.dart  # +78 All tests passed (extra safety: these pump the edited screens)
```

## Files modified (lock evidence)

| File | Lock acquired | Lock released |
|---|---|---|
| `lib/core/services/shards_service.dart` | `[lock] ACQUIRED 'lib/core/services/shards_service.dart' by EF-02` | `[lock] RELEASED … by EF-02` |
| `test/services/secure_session_storage_test.dart` | `[lock] ACQUIRED … by EF-02` | `[lock] RELEASED … by EF-02` |
| `lib/features/groups/create_group_screen.dart` | `[lock] ACQUIRED … by EF-02` | `[lock] RELEASED … by EF-02` |
| `lib/features/groups/donate_shards_screen.dart` | `[lock] ACQUIRED … by EF-02` | `[lock] RELEASED … by EF-02` |
| `lib/features/groups/group_detail_screen.dart` | `[lock] ACQUIRED … by EF-02` | `[lock] RELEASED … by EF-02` |
| `lib/features/profile/public_profile_screen.dart` | `[lock] ACQUIRED … by EF-02` | `[lock] RELEASED … by EF-02` |
| `docs/history/phase-02-flutter-foundation/2026-08-09_EF02-analyzer-clean.md` (new) | `[lock] ACQUIRED … by EF-02` | `[lock] RELEASED … by EF-02` |

No other agent held any of these locks during the work (`tools/agent_lock.sh list`
showed only EF-01 on its own files: `test/structure_test.dart`,
`test/pubspec_test.dart`, `docs/to-fix/TODO.md` — no overlap).

## Issues found / pre-existing bugs (reported, not fixed — out of scope)

- `create_group_screen.dart:103-107`: the `catch` runs `setState(...)` before
  the `mounted` check — a genuine unguarded-`setState` crash risk after
  unmount. Pre-existing; the catch-block sweep belongs to I-06.
- `group_members_screen.dart:26`: `_load()` calls `setState(() => _loading = true)`
  at method start without a guard; `initState` calls it synchronously so it is
  safe today, but a later re-entrant call would not be. Pre-existing.

## Sources consulted

- Flutter docs — `use_build_context_synchronously` lint: https://dart.dev/tools/linter-rules/use_build_context_synchronously
- Dart analyzer — unused_import lint: https://dart.dev/tools/linter-rules/unused_import
