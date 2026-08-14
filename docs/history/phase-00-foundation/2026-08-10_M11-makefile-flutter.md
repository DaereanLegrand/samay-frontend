# 2026-08-10 — M-11: Makefile Flutter half — dart-define consistency, test split (MKE-06), `make check` (MKE-09)

**Agent:** M-11 (Phase 4.3 — Makefile track, Flutter targets)
**Role:** Rework the Flutter + testing section of the Makefile: keep and extend
the I-34 `FLUTTER_DEFINES` seam consistently across `build`/`dev`/`install`,
add the separated test targets (`test-unit`, `test-integration`,
`test-backend-static`, `test-go`, `test-all`, `test` = `test-all`), add the
`check` target, and close the MKE-06 finding (plus the Flutter half of
MKE-03/MKE-04/MKE-09).
**Campaign:** Samay 180-agent orchestration, branch `fixes`; Juega untouched
(read-only), NO commits, NO containers started — verification is dry-run only.

---

## What was built

### 1. `Makefile` — Flutter section (owner M-11 ✅, FILE-OWNERSHIP row)

- **`FLUTTER_DEFINES` consistency (MKE-03/MKE-04):** verified `build` and `dev`
  already pass it in every branch (I-34); `install TARGET=ios` now forwards
  `FLUTTER_DEFINES=$(FLUTTER_DEFINES)` into the macvm `make build` invocation,
  so a CLI override (`make install TARGET=ios FLUTTER_DEFINES="--dart-define=…"`)
  reaches the remote build instead of only the local `.env` file. Android
  install branches need no defines (they install the artifact `build` produced).
- **`FLUTTER_TEST_DEFINES ?=` seam (new):** test targets run define-FREE by
  default — `test/core/env_config_test.dart` asserts the empty-default
  behavior, and I-34 proved `--dart-define` flips exactly those two cases.
  Documented on the variable with the override form
  (`make test-unit FLUTTER_TEST_DEFINES="--dart-define=SUPABASE_URL=…"`).
- **Separated test targets (MKE-06):**
  - `test-unit` → `flutter test test/ $(FLUTTER_TEST_DEFINES)` (unit/widget
    only; `integration_test/` excluded by path).
  - `test-integration` → `bash integration_test/runner.sh` (hermetic by
    default, `-d <device>` passthrough lives in the runner).
  - `test-backend-static` → `bash test/opt-005-seed-dev-static.sh` + `bash
    test/opt-007-compose-static.sh` (the two backend gates that need NO
    stack; the live curl suite 001/002/003/004/006 stays behind
    `bash test/run_all_backend.sh` and requires the stack).
  - `test-go` → `go test ./...` (MKE-09 Go test target).
  - `test-all` → `test-unit test-go test-backend-static test-integration`
    (order: cheapest/deterministic first, slowest hermetic suite last).
  - `test` → `test-all` (replaces the old `flutter-test` + `go test ./... -v`
    pair — `flutter-test` is kept as the unit-test alias).
- **`check` target (new, MKE-09):** `dart analyze` + `flutter analyze` +
  `go vet ./...` + `tools/check_ports.sh --strict` — the pre-CI gate; port-map
  violations must exit 0 per AGENTS.md Port Convention. `lint` unchanged
  (analyze + go vet + golangci-lint fallback).
- `.PHONY` extended with the six new targets.

### 2. `docs/to-fix/categories/14-MAKEFILE-CICD.md` (D-03's file, locked per mission)

- **MKE-06** 🔄 → ✅ with M-11 evidence (target table + define-free rationale +
  live-suite note).
- **MKE-03** status line refreshed: install passthrough + define-free test
  default landed; full `set -a; . ./supabase/.env.local` sourcing stays → M-13.
- **MKE-09** status line refreshed: `test-go` + `go vet` in `make check`
  landed; CI workflow still → M-20.
- **MKE-04** already ✅ (I-34) — re-verified, no change needed (no `.env`
  asset in `pubspec.yaml`; Makefile auto-detects `.env` presence).

### 3. `docs/to-fix/TODO.md` (D-03's file, locked per mission)

- New M-11 workstream block at the top (newest-first, M-01..M-10 precedent)
  summarizing the four points above + evidence pointer.

### 4. `docs/process/DEVELOPMENT-WORKFLOW.md` (D-09's file, locked per mission)

- §1.6 validation gate: `make test` composition updated (unit + go + static
  gates + integration) and `make check` added.
- §8 cheatsheet: `make test` line updated to `test-all` semantics; `make check`
  line added. (All other `make flutter-test`/`flutter-analyze` references
  remain valid — both targets still exist.)

### 5. `docs/history/phase-00-foundation/2026-08-10_M11-makefile-flutter.md` (this log)

---

## Decisions made and why

- **`test` = `test-all` (not a trimmed gate):** the mission mandates it; the
  components are chosen to run anywhere — `flutter test test/` and `go test
  ./...` need no server, opt-005/opt-007 are static gates by design, and the
  integration runner is hermetic by default (I-01/I-78). Nothing in
  `test-all` requires the stack, so `make test` stays CI-safe.
- **Live curl opt-tests NOT chained into `test-all`:** they fail-fast when
  Kong 54386 is down (documented I-78 behavior). Keeping them behind
  `bash test/run_all_backend.sh` preserves the distinction between the
  no-stack gate and the live suite — noted in the section comment.
- **`FLUTTER_TEST_DEFINES` empty by default:** env tests (I-34) explicitly
  assert the `''`-default behavior of `String.fromEnvironment`; passing the
  dev `.env` defines would flip those two cases and make the suite
  environment-dependent. The override seam covers the "prove a define
  reaches the app" use case.
- **`install` passes `FLUTTER_DEFINES` (not full env):** the macvm build
  already auto-detects its own `.env` via the Makefile conditional; the
  passthrough only matters for explicit overrides. Full env sourcing on the
  remote is M-13's pass (I-34 caveat #3 documents the macvm needs its own
  `.env`).
- **`flutter-test` kept as alias** instead of removing it: DEVELOPMENT-
  WORKFLOW.md and test/README.md (D-05/D-09-owned) reference it; deleting
  would ripple into doc work for zero gain.
- **`make check` duplicates `dart analyze` + `flutter analyze`** per the
  mission's explicit list — harmless redundancy, `flutter analyze` is the
  canonical CI form and `dart analyze` covers pure-Dart lint contexts.

## MISTAKE / gotcha

- **MISTAKE (avoided):** first draft chained `test` directly to the four
  leaf targets with `&&` in one recipe; that makes `make -n` noise and loses
  make's per-prerequisite dependency semantics (a failure in one target does
  not stop the others from being attempted — desired for a test gate).
  Replaced with the prerequisite-chain form (`test: test-all`,
  `test-all: test-unit test-go test-backend-static test-integration`) —
  clean `make -n` output and correct make semantics.
- **Gotcha:** `flutter test test/` (explicit path) vs bare `flutter test` —
  equivalent defaults, but the explicit path makes the "unit/widget only"
  contract self-documenting and future-proof against flutter's default-dir
  changes.
- **Gotcha (verification):** `make -n install` echoes the macvm SSH line with
  `FLUTTER_DEFINES=--dart-define-from-file=.env` — no spaces, so the remote
  `zsh -c '…'` string stays intact; an override WITH spaces would need
  different quoting (pre-existing limitation of that SSH line, unchanged).

## Commands run (reproducibility)

```bash
export AGENT_NAME="M-11-makefile-flutter"
tools/agent_lock.sh acquire Makefile --owner "$AGENT_NAME"
# ... same for docs/process/DEVELOPMENT-WORKFLOW.md, docs/to-fix/TODO.md,
#     docs/to-fix/categories/14-MAKEFILE-CICD.md, and the daily log path
tools/agent_lock.sh list                # 5 locks held by M-11-makefile-flutter

# Dry-run gates — every target resolves
for t in build dev install clean build-cli build-linux build-api test test-all \
         test-unit test-integration test-backend-static test-go flutter-test \
         flutter-analyze check lint define-env migrate-check supabase-seed-dev; do
  make -n "$t" >/dev/null && echo "$t OK" || echo "$t FAIL"
done                                    # all OK

make -n test                            # flutter test test/ ; go test ./... ;
                                        # opt-005 ; opt-007 ; runner.sh
make -n check                           # dart analyze ; flutter analyze ;
                                        # go vet ./... ; check_ports.sh --strict
make -n test-unit FLUTTER_TEST_DEFINES="--dart-define=SUPABASE_URL=x"   # override flows
make -n install TARGET=ios | grep "make build TARGET=ios" # FLUTTER_DEFINES passthrough
make define-env                         # ENV_FILE=.env / FLUTTER_DEFINES=--dart-define-from-file=.env

tools/agent_lock.sh release Makefile --owner "$AGENT_NAME"   # ×5, all released
```

## Verification

- [x] `make -n` resolves for ALL 21 targets (incl. override forms
      `FLUTTER_TEST_DEFINES=…`, `FLUTTER_DEFINES=…`, `TARGET=ios`).
- [x] `make test` dry-run shows the full chain: unit → go → opt-005 → opt-007
      → integration runner.
- [x] `make check` dry-run shows the 4-step chain (both analyzers, go vet,
      check_ports --strict).
- [x] MKE-03/MKE-04: `build`/`dev`/`install` all carry `FLUTTER_DEFINES`;
      `make define-env` prints the effective flags; `pubspec.yaml` has NO
      `.env` asset (re-verified) and the Makefile conditional handles the
      no-`.env` case (empty defines → fail-fast app, never misconfigured).
- [x] MKE-06: all separated targets exist + resolve; `test` = `test-all`.
- [x] MKE-09: `test-go` + `go vet` in `check` landed.
- [x] Lock evidence: 5 files acquired + released by `M-11-makefile-flutter`.
- [x] No commits; no `git add`; Juega untouched; no containers started
      (dry-run verification only).

## Issues found (reported, NOT fixed — out of scope)

1. **macvm `install` SSH quoting:** a `FLUTTER_DEFINES` override containing
   spaces breaks the remote `zsh -c '…'` string (pre-existing shape of the
   SSH line). M-13's env pass (or M-14's fastlane replacement) should rework
   this — flagged, not fixed.
2. **Full env sourcing still missing** (`set -a; . ./supabase/.env.local;
   set +a` before ALL targets) — MKE-03 remainder, owned by M-13. This
   mission only completed the Flutter-side dart-define consistency.
3. **`make test` no longer prints `go test -v`** (was `-v` in the old `test`
   target) — deliberate: plain `go test ./...` output is the CI form; add
   `GOFLAGS=-v` if a verbose run is wanted.
4. **Category-file status flips beyond MKE-06 (MKE-03/MKE-09 refresh lines)
   are evidence for D-03's re-verification** (M-01/M-09 precedent); TODO.md +
   category + this log carry the detail.

## Sources consulted

- Flutter CLI — `--dart-define-from-file` + `--dart-define` precedence
  (verified locally, I-34 log): `flutter build apk -h`
- Repo: `docs/history/phase-02-flutter-foundation/2026-08-09_I34-env-dartdefine.md`
  (the seam this mission extends; env-test flip proof),
  `docs/history/phase-00-foundation/2026-08-09_I75-seed-dev.md` +
  `2026-08-10_M01-compose-base.md` (opt-005/opt-007 static-gate semantics),
  `integration_test/runner.sh` (hermetic runner contract),
  `docs/to-fix/categories/14-MAKEFILE-CICD.md` (MKE-03/04/06/09),
  `docs/process/{AGENT-RULES,FILE-OWNERSHIP,DEVELOPMENT-WORKFLOW}.md`,
  `test/README.md` (test matrix), `tools/check_ports.sh` (--strict contract)
