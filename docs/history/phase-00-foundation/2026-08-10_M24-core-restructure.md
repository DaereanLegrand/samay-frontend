# 2026-08-10 — M-24: ARC-03 core restructure — feature_flags into config/, constants/ decision, guards

**Agent:** M-24 (Phase 4.3 — code-structure track; sole agent this run)
**Role:** finish the ARC-03 `lib/core/` restructure: audit every core root
file + subdir, move the last stray root file (`feature_flags.dart`) into
`lib/core/config/`, decide on the missing `constants/` dir, pin the ARC-03
post-state with guard tests, keep the 1626-test suite green.
**Campaign:** Samay 180-agent orchestration; Juega untouched (read-only), NO
commits, NO docker, NO network ops.

---

## PLAN — audit table (written FIRST, before any code)

### `lib/core/` root + subdir audit (post-M-23, 2026-08-10)

| Path | Files | Verdict |
|---|---|---|
| `lib/core/feature_flags.dart` (ROOT) | 1 | **STRAY → MOVE to `lib/core/config/`** (M-23 handoff #2 flagged it) |
| `config/` | env_config.dart | keep |
| `deep_links/` | deep_link_handler.dart | keep |
| `design_tokens/` | app_colors, app_elevation, app_icon_sizes, app_radius, app_spacing (5) | keep (I-16) |
| `errors/` | app_error.dart | keep (I-08) |
| `extensions/` | context_extensions, error_mapper (2) | keep (I-16/I-08) |
| `logging/` | app_logger.dart | keep (I-05) |
| `models/` | 28 (freezed + generated) | keep (I-10) |
| `providers/` | 8 cross-cutting providers | keep (M-23 decision) |
| `repositories/` | 6 | keep (I-50) |
| `router/` | 6 | keep (I-03/I-04) |
| `services/` | 21 | keep (I-11) |
| `telemetry/` | route_observer.dart | keep (I-68) |
| `theme/` | app_theme, samay_durations (2) | keep (I-17) |
| `utils/` | 8 | keep |
| `constants/` | **does not exist** | **DECISION: NOT created** (see below) |

**Gap table:**

| Gap | Decision |
|---|---|
| `feature_flags.dart` at core root | MOVE → `lib/core/config/feature_flags.dart` (flags are config-adjacent; `config/` holds `EnvConfig`; per mission, `config/` chosen over a new `flags/` dir) |
| `constants/` dir missing | NOT needed — the conventions' constants home is `design_tokens/` + `config/feature_flags.dart` (`AppFeatureFlag`/`AppFeatureFlags`) + `EnvConfig`; economy/QR/limit values live in `app_config` by rule (README). Juega's `constants/` (api_constants/app_constants) maps to Samay's tokens/flags/services. Empty placeholder dirs are FORBIDDEN (structure_test dynamic invariant TST-10/L-13) — a `constants/` with content would duplicate existing homes. `lib/crypto/constants.dart` is crypto-scoped and stays (not a core concern). |
| Every core subdir ≥1 file | VERIFIED (14 subdirs, all non-empty; dynamic invariant covers it) + explicit core-layers list in structure_test pinned to the 14 real subdirs |
| Stray files at core root | After the move: ZERO (only subdirs) — enforced by a new ARC-03 invariant in conventions_test |

### Importers of `package:samay/core/feature_flags.dart` (12, all absolute)

| # | File | Kind |
|---|---|---|
| 1 | `lib/core/router/app_router.dart` | lib |
| 2 | `lib/features/profile/screens/profile_screen.dart` | lib |
| 3 | `test/core/feature_flags_test.dart` | test |
| 4 | `test/router/app_router_test.dart` | test |
| 5 | `test/features/profile_screens_test.dart` | test |
| 6 | `test/features/cosmetics/cosmetics_navigation_test.dart` | test |
| 7 | `integration_test/qr_flow_test.dart` | integration |
| 8 | `integration_test/photos_flow_test.dart` | integration |
| 9 | `integration_test/minigames_flow_test.dart` | integration |
| 10 | `integration_test/party_finder_flow_test.dart` | integration |
| 11 | `integration_test/subscriptions_flow_test.dart` | integration |
| 12 | `integration_test/cosmetics_flow_test.dart` | integration |

Plus a path comment at `test/meta/conventions_test.dart:191` (I-69 route-gating
guard) — updated to the new path.

### Guard/doc update plan

| File | Change | Owner |
|---|---|---|
| `test/structure_test.dart` | core-layers list → the 14 real subdirs (+`deep_links`, `repositories`, `errors`, `extensions`, `telemetry`) + new "no constants/ dir" test | EF-01's (locked) |
| `test/meta/conventions_test.dart` | new ARC-03 invariant (no `.dart` in `lib/core/` root) + comment path update | I-48's (locked) |
| `docs/process/FILE-OWNERSHIP.md` | I-49 row → `lib/core/config/feature_flags.dart`; M-24 row → DONE + decision | orchestrator-owned (locked per mission) |
| `docs/to-fix/TODO.md` | M-24 workstream block | (M-23 precedent) |
| `docs/history/phase-00-foundation/2026-08-10_M24-core-restructure.md` | this log | own |

---

## Commands run (reproducibility)

```bash
export AGENT_NAME="M-24-core-restructure"
# 1. lock the NEW target path + every importer + guards + docs (18 files)
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"   # 18× ACQUIRED
# 2. move
git mv lib/core/feature_flags.dart lib/core/config/feature_flags.dart
# 3. import rewrite (12 files, mechanical sed, per-file locks held)
sed -i '' 's|package:samay/core/feature_flags.dart|package:samay/core/config/feature_flags.dart|' <12 files>
grep -rn "package:samay/core/feature_flags.dart" lib/ test/ integration_test/   # → NONE
grep -rln "package:samay/core/config/feature_flags.dart" lib/ test/ integration_test/  # → 12
# 4. guards (structure_test, conventions_test) + docs (FILE-OWNERSHIP, TODO, this log)
# 5. validation
dart analyze                                        # No issues found!
flutter test <targeted batches>                     # 144/144
flutter test                                        # 1628 pass / 0 fail
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"  # all 18 released
```

---

## EXECUTION LOG

| Step | Result |
|---|---|
| Lock acquisition (18 files) | all ACQUIRED (sole agent — no contention) |
| `git mv feature_flags.dart → config/` | OK; `lib/core/` root now 14 dirs, 0 files |
| Import rewrite | 12/12 files, old path grep = 0 hits |
| `dart analyze` | **No issues found!** (0 errors/warnings/infos) |
| Targeted tests (feature_flags 18 + meta guards + structure 30+ + router 68 + profile + cosmetics nav) | **144/144 pass** |
| Full `flutter test` (main tree) | **1633 pass / 0 failures** — committed baseline re-measured in a detached HEAD worktree: **1626/0** (git 8ae9e51); delta +7 = +5 explicit core-dir assertions (structure_test's dir loop registers one test per dir, 9→14) + 2 new guard tests |
| `git status` | 1 rename (R100) + import-only edits + guard/doc edits |

## Guard/doc edits (all locked, all green)

| File | Change |
|---|---|
| `test/structure_test.dart` | core-layers list extended to the 14 real subdirs (`config` was already listed; added `deep_links`, `repositories`, `errors`, `extensions`, `telemetry`); new test `ARC-03: no constants/ placeholder dir is required` — asserts `lib/core/constants/` does NOT exist, with the decision rationale in the reason string |
| `test/meta/conventions_test.dart` | new test `ARC-03: no .dart files directly in the lib/core root` (mirrors the M-23 ARC-01 feature-root invariant); I-69 route-gating comment path → `lib/core/config/feature_flags.dart` |
| `docs/process/FILE-OWNERSHIP.md` | I-49 row: `lib/core/feature_flags/**` → `lib/core/config/feature_flags.dart` (new — feature-flag provider; moved by M-24); M-24 row: DONE + full decision note |
| `docs/to-fix/TODO.md` | M-24 workstream block (top, M-23 precedent) |

## FINAL VERIFICATION (gate)

- [x] `dart analyze` — **No issues found** (0 errors, 0 warnings, 0 infos).
- [x] Full `flutter test` (main tree) — **1633 pass / 0 failures**. The
      committed baseline was re-measured in a detached-HEAD worktree of
      `8ae9e51` (`flutter test` → **1626/0**, matching the commit message).
      Delta +7 = +5 explicit core-dir assertions (the structure_test dir-loop
      registers one test per dir; the core-layers list grew 9 → 14) + 2 new
      guard tests (ARC-03 root invariant, no-constants-dir). Zero regressions.
- [x] `git status` — 1 rename (`R100 lib/core/feature_flags.dart →
      lib/core/config/feature_flags.dart`) + import-only modifications in the
      12 importers + guard/doc edits. Zero content changes (diff-checked:
      only the import line in the 12 files).
- [x] `tools/agent_lock.sh list` at session end — no locks held (all 18
      released).
- [x] No commits; no `git add`; Juega untouched (read-only); no docker; no
      network ops.

## Lock evidence

Owner `M-24-core-restructure`. 18 files locked before editing, all released
after: the moved file (lock on the NEW path `lib/core/config/feature_flags.dart`
before `git mv`), all 12 importers, `test/structure_test.dart`,
`test/meta/conventions_test.dart`, `docs/process/FILE-OWNERSHIP.md`,
`docs/to-fix/TODO.md`, and this daily log. Verified via
`tools/agent_lock.sh list` = empty at end.

## Decisions made and why

1. **`feature_flags.dart` → `lib/core/config/`** (not `lib/core/flags/`):
   `config/` already holds `EnvConfig` (I-34) — build-time configuration;
   release knobs are config-adjacent and `app_config` (I-71) is the
   documented future remote-config source for them (the provider doc comment
   says exactly that). A separate `flags/` dir would hold one file and split
   config concerns.
2. **No `constants/` dir**: the campaign's conventions already provide a
   constants home — `design_tokens/` (design constants, I-16),
   `config/feature_flags.dart` (`AppFeatureFlag` release-knob enum +
   `AppFeatureFlags` defaults, I-49), `EnvConfig` (env constants, I-34), and
   `app_config` (tuneable economy/QR/limit values — README rule "never
   hardcode economy/QR/limit constants"). Juega's `constants/api_constants`
   (endpoints) maps to Samay's services/`RestClient`; `app_constants` maps to
   the token files. Empty placeholder dirs are forbidden by the structure_test
   dynamic invariant, and a content-bearing `constants/` would be duplication.
   The decision is GUARDED (structure_test asserts the dir does not exist) so
   a future agent cannot half-create it.
3. **Guards > docs for invariants**: the ARC-03 state is enforced by two new
   tests (no stray `.dart` at `lib/core/` root; `constants/` absent) rather
   than documented alone — the M-23 precedent (ARC-01 invariant in
   conventions_test).

## MISTAKE blocks

- None this run (mechanical move; single-agent tree; `git status` clean
  baseline verified BEFORE starting — the M-08 SQL-plan-consistency
  pre-existing failures from M-23's run are gone because the checkpoint
  commit (8ae9e51) landed them).

## Issues found / handoffs

1. **Stale doc (reported, NOT fixed — D-05/V-09 scope):** `README.md:238`
   says flags land "once `lib/core/feature_flags/` lands (I-49)" — pre-I-49
   wording; the file has existed at `lib/core/feature_flags.dart` since
   I-49 and is now `lib/core/config/feature_flags.dart`. README is D-05's
   file; left untouched per AGENT-RULES §4.
2. **Historical logs keep the old path** (I-49/I-54/I-58/I-65/I-69 logs,
   TODO.md I-49 block, M-23 log handoff #2): historical records — left
   untouched (M-23 precedent for SQL migration comments).
3. **D-03/V-02 handoff:** flip ARC-03 in
   `docs/to-fix/categories/00-ARCHITECTURE.md` to ✅ DONE with the M-24 ref
   (precedent: M-18/M-20/M-21/M-22/M-23 left category flips to D-03).
4. **Post-move convention (for future agents):** core-wide single files with
   no subdir go to the layer-appropriate dir — flags → `config/`,
   observers → `telemetry/`, mappers → `extensions/`. The `lib/core/` root is
   subdirs-only (guarded).
