# 2026-08-10 — M-26: lint rules + pre-commit hooks — CQ-08/TOOL-04

**Agent:** M-26 (Phase 4.3 — tooling track; sole agent this run)
**Role:** lock in the campaign's 0-issue state with lint rules (CQ-08) and
create the fast pre-commit gate (TOOL-04): `tools/pre-commit.sh` +
`tools/hooks/pre-commit` wrapper + `make install-hooks`, guard tests, TODO
flips, daily log.
**Campaign:** Samay 180-agent orchestration; Juega untouched, NO commits,
NO docker, NO network ops.

---

## PLAN — audit table (written FIRST, before any code)

### Repo state (verified before starting)

| Item | State |
|---|---|
| `analysis_options.yaml` | default `package:flutter_lints/flutter.yaml` (v6.0.0) + the I-10 freezed `invalid_annotation_target: ignore` — zero custom rules (CQ-08) |
| `dart analyze` | **0 issues** (the old 19 info baseline is gone — I-47/U-08 etc. cleaned it) |
| `.git/hooks/` | only the 14 `.sample` files — no pre-commit (TOOL-04) |
| `tools/` | exists with `seed_dev_data.sh` (I-75) — no `pre-commit.sh`, no `hooks/` |
| `test/meta/conventions_test.dart` | I-48/M-25 guard home; M-25's uncommitted opencode group present (do NOT clobber — extend) |
| `Makefile` | M-11..M-16 landed; `check:`/`lint:`/`flutter-analyze:` targets exist; opt-008 verifies `make -n` for the whole .PHONY inventory |
| flutter_lints v6.0.0 already enables | `avoid_print`, `sort_child_properties_last`, `use_build_context_synchronously`, `prefer_const_constructors_in_immutables`, … (verified in pub cache) |
| Working tree | M-24/M-25 uncommitted work present (restructure + .opencode) — analysis_options untouched by them |

### Candidate rule evaluation plan (empirical — add → `dart analyze` → keep/rollback)

| Rule | Prediction | Rule of decision |
|---|---|---|
| `prefer_single_quotes` | 36 lib files carry double-quoted strings | enable only if final analyze = 0 issues (or fix if few) |
| `avoid_print` | **already enabled** via flutter_lints | report-only (already enforced by conventions guard too) |
| `prefer_const_constructors` | unknown — I-20 did a const pass | enable only if 0 issues (or fix if few) |
| `unnecessary_late` | 24 `late` usages, mostly `late final` lazy | enable only if 0 issues |
| `sort_child_properties_last` | **already enabled** via flutter_lints | report-only |
| `use_build_context_synchronously` | **already enabled** + passing | report-only |
| `always_specify_types` | likely noisy (thousands of `var`/inferred) | evaluate; disable with documented reason if >~20 issues |
| `strict-casts` / `strict-inference` | Dart 3 language options | evaluate; disable with documented reason if they break the tree |

### Files to create/modify (all locked before touching)

| Path | Action | Owner per FILE-OWNERSHIP |
|---|---|---|
| `analysis_options.yaml` | add enabled rules | M-26 ✅ |
| `tools/pre-commit.sh` | create (the gate) | M-26 |
| `tools/hooks/pre-commit` | create (thin git wrapper) | M-26 |
| `Makefile` | `install-hooks` target + `check` refs | M-11 ✅ (⚙️ M-26) |
| `test/meta/conventions_test.dart` | M-26 guard group | I-48 ✅ (⚙️) |
| `docs/to-fix/TODO.md` | M-26 workstream block + CQ-08/TOOL-04 flips | D-03 ✅ (⚙️ M-25 precedent) |
| `docs/history/phase-00-foundation/2026-08-10_M26-lints-hooks.md` | this log | own |

---

## Commands run (reproducibility) — filled in as executed

```bash
export AGENT_NAME="M-26-lints-hooks"
dart analyze                                   # baseline: 0 issues
# per-rule probes: edit analysis_options.yaml → dart analyze → keep/rollback
flutter test test/meta/conventions_test.dart   # guard
bash tools/pre-commit.sh                        # the gate itself
make install-hooks                             # wiring
flutter test                                   # full suite
tools/agent_lock.sh list                       # must be empty at end
```

---

## EXECUTION LOG

| Step | Result |
|---|---|
| Baseline `dart analyze` | **0 issues** (campaign cleaned the old 19-info baseline) |
| flutter_lints v6.0.0 inventory | already enables `avoid_print`, `sort_child_properties_last`, `use_build_context_synchronously`, `prefer_const_constructors_in_immutables`, … (verified in `~/.pub-cache/.../flutter_lints-6.0.0/lib/flutter.yaml`) |
| Probe `prefer_single_quotes` | 0 issues → **enabled** |
| Probe `prefer_const_constructors` | 92 issues (79 test / 13 lib) → `dart fix --apply --code=prefer_const_constructors` = **83 mechanical const insertions in 38 files** → 0 issues → **enabled**. Diffs verified pure const additions |
| Probe `unnecessary_late` | 0 issues (24 `late` usages are all legit lazy/initState patterns) → **enabled** |
| Probe `always_specify_types` | **7323 issues** → disabled with documented reason |
| Probe `strict-casts` | **15 errors** across 11 files (auth_provider, chat_service, event_service, storage_service, cosmetics, group_detail, profile_screen, 2 tests) owned by I-09/I-11/I-26/I-30/I-38 — semantic fixes, not mechanical → disabled with documented reason + handoff |
| Probe `strict-inference` | **41 warnings** (8 lib / 33 test), no automated fixes → disabled with documented reason + handoff |
| YAML restructure | M-26 probe edits mangled the `linter:` key placement → rewritten cleanly (see MISTAKE below) |
| Final `dart analyze` | **0 issues** |
| RED guard tests | 3/4 new tests failed (scripts + make target absent) — 14 pre-existing passed |
| `tools/pre-commit.sh` | written (5 fail-fast gates; `--fatal-infos --fatal-warnings` after the RED probe exposed bare `dart analyze` exits 0 on infos) |
| `tools/hooks/pre-commit` | thin wrapper, `git rev-parse --show-toplevel` → exec delegation; both `chmod +x` |
| `make install-hooks` | `.PHONY` + target added (M-11/M-15 comment style); `git config core.hooksPath tools/hooks` verified live |
| **GREEN gate run** | `bash tools/pre-commit.sh` → all 5 gates pass, **18 s** (vs full `make test-all` minutes) |
| **RED probe (temp git repo)** | full working-tree snapshot to scratch repo → planted `print()` violation → gate **exit 1 at step 1** (2 issues, fail-fast, steps 2-5 never ran) → removed → gate exit 0. Scratch deleted |
| **Hook wiring proof** | scratch repo: `make install-hooks` → `git commit` with planted violation **BLOCKED** (hook, exit 1) → clean change committed **exit 0** (hook ran, gate passed). Scratch deleted |
| Guard suite | `flutter test test/meta/conventions_test.dart` → **17/17** |
| Full suite | `flutter test` → **1642 pass / 0 failures** |
| `make check` | dart analyze + flutter analyze + go vet + `check_ports --strict` → STRICT PASS (71 OK / 138 INFO / 0 VIOLATIONS) |
| `go test ./...` | all ok |
| Locks | all 8 acquired, all released at end |

## Guard/doc edits (all locked, all green)

| File | Change |
|---|---|
| `analysis_options.yaml` | 3 custom rules + pointer comment to this log (CQ-08) |
| `tools/pre-commit.sh` | the fast gate (TOOL-04) — header documents the full-vs-fast tradeoff + the no-lock rationale |
| `tools/hooks/pre-commit` | thin git wrapper (delegation, one place to maintain) |
| `Makefile` | `install-hooks` target + `.PHONY` row |
| `test/meta/conventions_test.dart` | M-26 guard group (4 tests) |
| `tools/check_secrets.sh` | `EVIDENCE3` allowlist (see Issues found — pre-existing bug the gate caught) |
| `docs/to-fix/TODO.md` | M-26 workstream block at top (M-23/M-24/M-25 precedent) |
| this log | daily log |

## FINAL VERIFICATION (gate)

- [x] `dart analyze` — **0 issues** (final state; also `--fatal-infos --fatal-warnings` clean).
- [x] `bash tools/pre-commit.sh` — **GREEN**, 18 s, exit 0.
- [x] **RED proof** — temp git repo snapshot + planted `print()` violation → gate exit 1 at step 1 (fail-fast; steps 2-5 never ran). Cleaned.
- [x] **Hook wiring proof** — scratch repo with `make install-hooks`: violation commit BLOCKED, clean commit landed (exit 0). Cleaned.
- [x] `flutter test test/meta/conventions_test.dart` — **17/17**.
- [x] Full `flutter test` — **1642/0** (M-25 committed baseline 1633/0 + the new guard tests).
- [x] `make check` — STRICT PASS (ports 0 violations).
- [x] `go test ./...` — ok.
- [x] `tools/agent_lock.sh list` at session end — no locks held (all 8 released).
- [x] No commits; no `git add`; Juega untouched; no docker; no network ops.

## Decisions made and why

1. **Enabled only rules with a proven 0-issue tree** — the campaign rule
   from CQ-08 ("enable only rules with 0 current violations, or fix the
   violations if few"): `prefer_single_quotes`, `prefer_const_constructors`
   (92→0 via `dart fix`), `unnecessary_late`. Three more (`avoid_print`,
   `sort_child_properties_last`, `use_build_context_synchronously`) are
   already on via flutter_lints v6 and stay as-is.
2. **`always_specify_types` disabled** — 7323 violations at probe. Explicit
   types on every local/param is contrary to Dart's inference-first design;
   fixing would churn ~all of `lib/` + `test/` in a checkpoint whose goal is
   *locking in* a clean tree, not ballooning it. Documented in
   analysis_options + this log.
3. **`strict-casts`/`strict-inference` disabled (with handoff)** — 15 errors
   / 41 warnings, all requiring semantic fixes (`as Map<String, dynamic>`
   casts on `dynamic` PostgREST responses, explicit type args on `rpc()`)
   in files owned by I-09/I-11/I-26/I-30/I-38 etc. Right target, wrong
   checkpoint: the I-10 freezed typed-models migration (CQ-02) removes the
   raw-`dynamic` patterns at their source; **handoff: enable both after the
   typed-models pass** — they are the real "type safety" win CQ-08 asked for.
4. **Fail-fast `--fatal-infos --fatal-warnings`** — the RED probe proved
   bare `dart analyze` returns 0 on info-level issues (the planted `print`
   produced 2 infos and the gate would have PASSED). The gate must treat
   ANY issue as blocking: the pre-commit contract is "0 issues", the CI
   baseline is "0 issues".
5. **Fast smoke = `test/meta/` + `test/core/` + `test/utils/`** — the
   pre-commit gate must finish in seconds or devs bypass it. The smoke
   covers the layers that (a) guard the repo's own conventions (meta),
   (b) pure logic most likely to break on a sloppy edit (utils/core). Full
   `test/` + `integration_test/` + `go test` stay CI's job (`make test-all`,
   `make check`). Tradeoff documented in the script header.
6. **Hook delegates via thin wrapper** — `tools/hooks/pre-commit` only
   resolves the root and `exec`s `tools/pre-commit.sh`; one place to
   maintain the gate, and the committed `tools/hooks/` dir (vs `.git/hooks/`
   which is per-clone state) is what `make install-hooks` points
   `core.hooksPath` at.
7. **The gate takes NO locks** — the semaphore arbitrates editors; a
   read-only checker cannot clobber anything, and locking staged files per
   commit would make every commit O(locks) slower. If a parallel agent is
   mid-edit at commit time, the analyze/test steps catch the half-written
   state — the check, not the lock, is the gate. (Rationale in script header.)
8. **`EVIDENCE3` allowlist in check_secrets.sh** — the documented remedy
   for evidence-log hits (M-13 log: "justify+extend the allowlist"). The
   M-13/M-17/M-20/M-21 daily logs quote the P2/P3 pattern literals in their
   pattern tables — same class as the M-03/M-09/D-03/I-34 logs already
   allowlisted. The gate caught this on the COMMITTED tree (pre-existing
   since 8ae9e51), so it had to be fixed for the gate to pass at all.

## MISTAKE blocks

- **Bare `dart analyze` in a gate exits 0 on infos (caught by the RED
  probe).** The first version of step 1 did `if ! dart analyze`; the probe
  with a planted `print()` showed "2 issues found" and the gate moved on to
  step 2. Every gate must use `--fatal-infos --fatal-warnings` (or grep the
  output). This is exactly what a RED probe is for — the temp-repo test
  caught it before any developer hit it.
- **YAML edit mangling (caught immediately).** While toggling the language
  options I deleted the `linter:` key line, silently re-parenting `rules:`
  under `analyzer:` (valid YAML, wrong schema — `dart analyze` still ran,
  which is how it was caught). Rewrote the file cleanly instead of
  incremental edits. Future agents: for small config files, one `write` of
  the final content beats 6 `edit`s.
- **RED-probe temp clone from HEAD is wrong.** The first probe repo was a
  `git clone` of HEAD — but the 83 const fixes + M-24/M-25 work are
  UNCOMMITTED, so the clone analyzed the pre-const tree and failed for the
  wrong reason (92 rule hits, not the planted violation). The probe must
  snapshot the LIVE WORKING TREE (rsync minus `.git/.dart_tool/build/
  repo-locks` + `git init`), not HEAD.

## Issues found / handoffs

1. **Pre-existing `secrets-check` failure (fixed in-scope):** the committed
   tree (8ae9e51) fails `make secrets-check` — M-13/M-17/M-20/M-21 daily
   logs quote P2/P3 pattern literals without allowlist coverage. Fixed via
   `EVIDENCE3` in `tools/check_secrets.sh` (documented remedy). Any agent
   who has since run `make check` on the committed tree would have seen
   this. M-13 review welcome.
2. **D-03/V-02 handoff:** flip CQ-08 in `docs/to-fix/categories/16-CODE-QUALITY.md`
   and TOOL-04 in `docs/to-fix/categories/09-CODE-GENERATION-TOOLING.md` to
   ✅ with the M-26 ref (precedent: M-18/M-20/M-21/M-22/M-23/M-24/M-25 left
   category flips to D-03).
3. **strict-casts/strict-inference handoff:** enable both language options
   after the typed-models migration (I-10 freezed / CQ-02) — the current
   15/41 failures are the raw-`dynamic` service patterns that pass removes.
4. **FILE-OWNERSHIP.md already lists M-26 ✅** for `analysis_options.yaml` +
   `tools/pre-commit.sh` + hooks (orchestrator pre-marked) — left untouched.
   Note: `tools/hooks/pre-commit` + the `Makefile install-hooks` target are
   new paths not in the ownership map; free-for-all per the unlisted-file
   rule.
5. **`flutter test test/meta/ test/core/ test/utils/`** smoke baseline:
   328 tests, ~7 s. If the suite grows beyond ~30 s, consider dropping to
   `test/meta/` alone (the guards) — documented in the script header.
6. **Checkpoint note:** the const-fix diff touches 38 files (6 lib + 32
   test) — all mechanical `const` insertions from `dart fix`, verified pure
   by `git diff` inspection (no behavior change; full suite 1642/0).
