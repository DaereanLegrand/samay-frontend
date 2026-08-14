# 2026-08-09 — EF-01: Structure-test fix (TST-09/TST-10, L-12/L-13)

**Agent:** EF-01 | **Role:** Enforcement fix — test-suite green | **Phase:** 02-flutter-foundation | **Status:** DONE

**Scope:** `test/structure_test.dart` (rewrite — the only remaining failure class in the
suite), `test/pubspec_test.dart` (meaningfulness verification + asset check), `docs/to-fix/TODO.md`
(L-12/L-13 statuses), this log.

## Context

`test/structure_test.dart` was the **only remaining failure class** in the Flutter suite:
**744 pass / 12 fail**, all 12 from its 26 hardcoded path assertions (finding TST-10/L-13 —
brittle, asserted dirs that legitimately do not exist yet: `lib/features/{events,chat,qr,photos,
notifications,shards,cosmetics,minigames,party_finder,subscriptions,video_souvenir}` and
`lib/shared/models` — those land with feature agents I-54..I-64). Also per mission: verify
`test/pubspec_test.dart` is meaningful after I-23's update (TST-09/L-12).

## Plan → execution

1. **READ** — full repo: all of `lib/` (117 dart files inventoried), `test/` (60 files),
   `integration_test/` (I-01 harness: 3 flows + support/), `docs/to-fix/TODO.md`,
   `docs/to-fix/categories/04-TESTING.md`, `docs/process/*` (rules/ownership/workflow),
   `pubspec.yaml`, `AGENTS.md`, prior daily logs (I-23 log as template).
2. **PREP** — acquired 4 locks (below), log created.
3. **RED** — confirmed the 12 failures via `flutter test` (744/12 baseline).
4. **GREEN** — rewrote `structure_test.dart`; extended `pubspec_test.dart` with the
   declared-assets-on-disk check (TST-09's suggested fix).
5. **VALIDATE** — focused suite 47/47, full suite **753/0**, `dart analyze` clean on both files.
6. **DOCUMENT** — this log + TODO.md.

## What was built

1. **`test/structure_test.dart` — rewritten (26 hardcoded asserts → 22 dynamic asserts).**

   - **Explicit existence assertions on dirs/files that exist TODAY** (mission contract):
     - entrypoints: `lib/main.dart`, `lib/app.dart`
     - core layers: `lib/core/{theme,config,router,services,providers,models,design_tokens,logging,utils}`
     - live feature modules: `lib/features/{auth,profile,friends,groups,feed}`
     - shared + crypto: `lib/shared/widgets`, `lib/crypto`
     - integration suite (I-01): `integration_test/` with ≥1 `*_test.dart`,
       `support/{fake_supabase,test_app,test_users}.dart`, `README.md`
   - **Dynamic invariant (the future-proof check from the finding):** reads the CURRENT tree
     (`Directory.listSync`) and asserts **every `lib/` subdirectory contains ≥1 `.dart` file**
     (recursive) — fails loudly on empty placeholder dirs, and automatically covers any dir
     feature agents I-54..I-64 add later. No hardcoded future paths anywhere.
   - Fast: pure `dart:io`, no flutter binding, no `testWidgets`; `Directory.current` = package root.
   - Deliberately **not** asserted: `lib/features/events` etc. (arrive with I-54..I-64 — asserting
     them now is the exact L-13 bug), `lib/shared/models` (models live in `lib/core/models`).

2. **`test/pubspec_test.dart` — verified meaningful, one addition.**
   - Verified against `pubspec.yaml`: the 15 live-deps assertions, 5 dead-dep-absence assertions
     (qr_flutter, mobile_scanner, purchases_flutter, share_plus, flutter_dotenv) and 3 dev-deps
     are all **accurate and current** (I-23's dep-contract update + I-34's flutter_dotenv removal
     are reflected). Nothing stale.
   - Added the TST-09-suggested fix: **"every asset declared under `flutter:` exists on disk"** —
     parses `flutter: fonts:` (3 variable TTFs) + `flutter: assets:` (future-proof) and asserts
     each declared file exists. Guards against deleted assets with dangling pubspec entries.

## Files modified (lock evidence)

All locks via `tools/agent_lock.sh acquire/release <path> --owner EF-01`:

| File | Action | Lock |
|---|---|---|
| `test/structure_test.dart` | rewritten (26 → 22 asserts) | acquire 2026-08-09T17:56:58Z / released |
| `test/pubspec_test.dart` | extended (+1 asset check) | acquire 2026-08-09T17:56:58Z / released |
| `docs/to-fix/TODO.md` | modified (L-12, L-13 → ✅) | acquire 2026-08-09T17:56:58Z / released |
| `docs/history/phase-02-flutter-foundation/2026-08-09_EF01-structure-test-fix.md` | created (this log) | acquire 2026-08-09T17:56:59Z / released |

## Commands run (reproducibility)

```bash
export AGENT_NAME=EF-01
flutter test test/structure_test.dart          # RED: 14 pass / 12 fail (baseline confirmed)
flutter test                                   # before: 744 pass / 12 fail (all 12 = structure_test)
# ... edits under lock ...
flutter test test/structure_test.dart test/pubspec_test.dart   # 47/47 pass (22 + 25)
flutter test                                   # after: 753 pass / 0 failures
dart analyze test/structure_test.dart test/pubspec_test.dart   # No issues found
tools/agent_lock.sh list                       # all locks released after edits
```

## Test results

- **Before:** `flutter test` = **744 pass / 12 fail** (756 total; all 12 in `test/structure_test.dart`).
- **After:** `flutter test` = **753 pass / 0 failures** (753 total: −26 old structure asserts,
  +22 new, +1 new pubspec asset check). **Gate passed — the 12 have vanished.**
- `dart analyze` on both touched test files: **No issues found**.

## Decisions made and why

1. **dart:io recursive walk instead of package:glob** — `glob` is only a *transitive* dep
   (pubspec.lock), and `flutter_lints` (depend_on_referenced_packages) would flag a direct import.
   `Directory.listSync` is dependency-free, instant for ~160 files, and equally "reads the
   current tree".
2. **Explicit + dynamic split** — the explicit list documents the architecture contract (what
   must exist); the single dynamic invariant (no empty dirs) is the meaningful, refactor-proof
   check the finding demanded. Future feature dirs are covered automatically.
3. **Did NOT touch `docs/to-fix/categories/04-TESTING.md`** (D-03-owned, not in my LOCK LIST /
   mission) — TST-09/TST-10 status rows there remain ❌ "verified still open"; flagged for
   D-03/V-02 re-verification.
4. **Did not flip L-29's "24/24" reference** in TODO.md — pubspec_test now has 25 tests; that
   text belongs to I-23's log, not the TODO row (which I did not modify beyond L-12/L-13).

## MISTAKE / gotcha

- None this session. (Noted I-23's chained-acquire gotcha; acquired locks one per call.)
- Original file had **26** path assertions (13 pass / 12 fail = 25? — no: 26 total, 12 fail /
  14 pass; the earlier +744/−12 full-suite math only adds up with 26, verified by
  756 − 26 + 22 + 1 = 753).

## Issues found (out of scope, reported)

- `docs/to-fix/categories/04-TESTING.md` TST-09/TST-10 statuses stale (still ❌) — needs
  D-03/V-02 flip to ✅ with EF-01 ref, same as TODO.md now carries.
- I-23's log line "pubspec_test … 24/24" — test count moved to 25; no code impact.
- Pre-existing analyze info-level items (19) and any other baseline items untouched — not in scope.
