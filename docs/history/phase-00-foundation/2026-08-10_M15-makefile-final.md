# 2026-08-10 — M-15: Makefile finalization — fastlane stubs, migrate-check refresh, deploy placeholders, bundle-install

**Agent:** M-15 (Phase 4.3 — Makefile track; mission covers the M-14/M-15/M-16 scope)
**Role:** (1) fastlane invocation targets `ios-beta` / `ios-release` / `android-alpha`
/ `android-release` — stubs that call `bundle exec fastlane <lane>` per M-17/M-18's
lane names and fail fast with a clear message until the lanes exist (lane-name
contract DECIDED here and documented for M-17/M-18); (2) `migrate-check` refresh —
both migration stacks, latest-migration parity, future-dated-timestamp sanity;
(3) `deploy-api` / `deploy-dashboard` / `deploy-venue` placeholder targets (echo +
exit 0, doc pointers only); (4) `bundle-install` target (Gemfile-guarded, MKE-10);
(5) new static gate `test/opt-008-makefile-static.sh`; (6) daily log + TODO.md +
DEPLOYMENT-PLACEHOLDER.md updates.
**Campaign:** Samay 180-agent orchestration; Juega untouched (read-only), NO commits,
NO containers started, NO bundle/fastlane installs — verification is dry-run +
scratch-repo probes only.

---

## What was built

### 1. `Makefile` (owner M-15 ✅, FILE-OWNERSHIP row)

- **Fastlane stubs (MKE-05/MKE-07 Makefile half):** four targets added at the end of
  the file (after `secrets-check`), each gating on `fastlane/Fastfile` presence AND a
  grep for its lane literal, then invoking `bundle exec fastlane <platform> <lane>`:
  - `ios-beta` → `bundle exec fastlane ios beta_testflight`
  - `ios-release` → `bundle exec fastlane ios release_appstore`
  - `android-alpha` → `bundle exec fastlane android alpha_firebase`
  - `android-release` → `bundle exec fastlane android release_play`
  Until M-17/M-18 create the lanes, the stub prints a clear
  "M-17 must create fastlane/Fastfile with the '…' lane (contract:
  DEPLOYMENT-PLACEHOLDER.md §3.3)" message and the recipe exits 1 (make reports 2).
  The lane-name contract is written into the target-comment block (the ONLY
  fastlane entrypoints) — see §Decisions for the DECIDED contract.
- **`migrate-check` refresh (MKE-07 CI parity):** the old single-stack `git status`
  grep is replaced by `@tools/check_migrations.sh` — the logic now lives in a
  runnable script (so the static gate can RED-probe it in a scratch repo). New
  checks: (1) UNTRACKED files in EITHER `supabase/migrations/` or
  `supabase-testing/migrations/` fail (migrations must be committed to apply);
  (2) latest migration + file count must match between stacks (M-10 parity);
  (3) no migration dated after today (UTC) — the `YYYYMMDDHHMMSS` timestamp
  convention; (4) every filename conforms to `^[0-9]{14}_[a-zA-Z0-9_]+\.sql$`.
- **Deploy placeholders (M-16 scope):** `deploy-api`, `deploy-dashboard`,
  `deploy-venue` echo their target shape (Go API server §1.1 #4, Admin Dashboard
  §1.1 #5, Venue app §1.1 #7), point at `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`
  (§1.2 placeholder domains, §6 registry rows R02/R06), and `exit 0`. **No URL,
  real or placeholder, appears anywhere in the Makefile** (repo placeholder policy).
- **`bundle-install` (MKE-10):** guards on `Gemfile` presence (clear "M-19 scope"
  message when absent), then `bundle install` — Gemfile.lock-aware (M-19 commits
  both `Gemfile` + `Gemfile.lock`).
- `.PHONY` extended with the 8 new targets.

### 2. `tools/check_migrations.sh` (new — free-for-agent per FILE-OWNERSHIP preamble)

`migrate-check` logic as a standalone script (checks in §1 above), styled after
`tools/check_secrets.sh`/`test/opt-005` (✅/❌ output, FAILURES counter, exit 0/1/2).
Takes an optional repo-root argument so tests can point it at a scratch repo.

### 3. `test/opt-008-makefile-static.sh` (new — static gate)

Five sections (exit 0/1):
1. `make -n` resolves ALL 45 documented targets (hardcoded full inventory — a typo
   in `.PHONY` or a removed target fails here).
2. Fastlane stub contract: targets exist; each invokes the EXACT
   `bundle exec fastlane <platform> <lane>`; each has the `fastlane/Fastfile` guard.
   Conditional LIVE probe (runs only while `fastlane/Fastfile` is absent):
   `make ios-beta` and `make bundle-install` fail fast with the M-17/Gemfile
   messages (auto-skips once M-17 lands — documented in the header for M-17/M-18).
3. migrate-check RED probe: `tools/check_migrations.sh` is run against a SCRATCH
   git repo — GREEN on a clean committed pair of stacks, RED on a planted
   untracked migration (exit 1 + "UNTRACKED"), RED on a planted future-dated
   migration (exit 1 + "future-dated"). Real repo never touched.
4. Deploy placeholders: targets exist; the deploy block references
   `DEPLOYMENT-PLACEHOLDER.md`; the block contains NO `scheme://` URL; the targets
   echo + `exit 0`.
5. `bash -n` on the helper script + itself.

### 4. `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (D-10's file, locked per mission)

- Header "Last verified" → M-15.
- §3 intro note: make-level invocation surface now exists; `fastlane/`, `Gemfile`,
  `.github/` still do not (M-17..M-22).
- §3.3 NEW "Makefile contract" table: make target ↔ exact
  `bundle exec fastlane <platform> <lane>` command ↔ M-17/M-18 lane definition —
  the lane-name contract documented in BOTH directions.
- §6 adoption contract: M-15 sentence (make targets are the only fastlane
  entrypoints; `bundle-install` guard).

### 5. `docs/to-fix/TODO.md` (D-03's file, locked per mission)

M-15 workstream block at the top (newest-first, M-13 precedent): the five points +
verification + evidence pointer.

### 6. `docs/to-fix/categories/14-MAKEFILE-CICD.md` (D-03's file, locked per mission)

- MKE-05 🔄 (fastlane stubs landed; AltServer stays dev-only until M-17/M-18).
- MKE-07 🔄 (Makefile half landed with M-15 evidence; `.github/` → M-20..M-22).
- MKE-10 🔄 (`bundle-install` landed; `Gemfile` → M-19).

### 7. `docs/history/phase-00-foundation/2026-08-10_M15-makefile-final.md` (this log)

---

## Decisions made and why

- **LANE-NAME CONTRACT (decided now — the doc's §3.3 names were verified NOT
  stale, so no doc-name fix was needed; the Makefile + doc are now aligned):**
  - `make ios-beta` → `bundle exec fastlane ios beta_testflight` (M-17)
  - `make ios-release` → `bundle exec fastlane ios release_appstore` (M-17)
  - `make android-alpha` → `bundle exec fastlane android alpha_firebase` (M-18)
  - `make android-release` → `bundle exec fastlane android release_play` (M-18)
  These match DEPLOYMENT-PLACEHOLDER.md §3.2 (M-22 shapes: `fastlane ios
  release_appstore`, `fastlane android release_play`, alpha = android
  `alpha_firebase` + ios `beta_testflight`) and §3.3 lane-shape prose verbatim.
  M-17/M-18 must define `platform :ios` + `lane :beta_testflight` /
  `lane :release_appstore` and `platform :android` + `lane :alpha_firebase` /
  `lane :release_play`. `test/opt-008-makefile-static.sh` §2 greps these exact
  strings, so any rename breaks the gate.
- **Stubs gate on `fastlane/Fastfile` + a lane-literal grep, not on Gemfile:** the
  lane is the thing M-17/M-18 must deliver; missing `Gemfile` (M-19) already fails
  inside `bundle exec` with its own clear "Could not locate Gemfile" message.
  Keeps each stub to two gates and one clear failure mode per blocker.
- **`migrate-check` logic extracted to `tools/check_migrations.sh` (not kept
  inline):** inline make recipes are not runnable against a scratch repo, so the
  RED probe would have to pollute the real repo. A script with an optional
  repo-root argument makes the gate testable (M-13's `check_secrets.sh` precedent)
  and keeps `make migrate-check` a one-liner.
- **Future-date check compares only the first 8 digits (YYYYMMDD) of the 14-digit
  timestamp against UTC today:** the full 14-digit number is always > any 8-digit
  date, so comparing the whole prefix would flag EVERY migration (see MISTAKE).
- **Deploy targets exit 0** (not 1): they are informational placeholders by
  mission spec, and a CI that accidentally runs `make deploy-api` must not fail
  the build on a no-op — the echo loudly says nothing was deployed.
- **No URLs (even placeholders) in the Makefile:** the deploy targets reference the
  doc by path; keeping `scheme://` out of the Makefile lets opt-008 §4 ban real
  URLs by banning `scheme://` in the deploy block, and keeps the Makefile out of
  the placeholder-domain churn.
- **Full documented-target list hardcoded in opt-008 §1** (instead of parsing
  `.PHONY`): an explicit inventory catches a target that was dropped from `.PHONY`
  or deleted outright — the gate's job is to freeze the documented surface.

## MISTAKE / gotcha

- **MISTAKE (caught by my own gate):** first draft compared the whole 14-digit
  timestamp against today (`10#$STAMP -gt 10#$TODAY`) — mathematically ALWAYS
  true (14 digits vs 8), so every migration would be "future-dated". Fixed to
  `${STAMP:0:8}` (the YYYYMMDD date part) before first run; the future-dated RED
  probe now passes for a genuinely-future file and clean for the real set.
- **MISTAKE (caught by test run):** opt-008 §2 first used `echo "$STUB_PAIRS" |
  while read …` — the loop runs in a subshell, so `FAILURES` increments were
  LOST. Switched to a here-string (`<<<`), keeping the counter in the main shell.
- **MISTAKE (caught by test run):** opt-008 §3's RED probe grepped the script's
  message for uppercase "UNTRACKED" while the message said "untracked" — fixed the
  script message to "UNTRACKED migration file(s)" (matches the old gate's
  "UNTRACKED MIGRATIONS FOUND" phrasing).
- **Gotcha (make exit codes):** a failing recipe makes `make` exit 2, not 1
  (`make: *** [ios-beta] Error 1`). The stub recipes exit 1 themselves; the LIVE
  probe asserts "non-zero + message", documented in the test comment.
- **Gotcha (exec bit):** `tools/check_migrations.sh` needed `chmod +x` — make
  recipes invoke it as `./…`-style PATH command; first `make migrate-check` run
  failed with "Permission denied" until `chmod +x`.

## Commands run (reproducibility)

```bash
export AGENT_NAME="M-15-makefile-final"
tools/agent_lock.sh acquire Makefile --owner "$AGENT_NAME" --timeout 300    # +6 files (list below)
tools/agent_lock.sh list                    # 7 locks held by M-15-makefile-final

# Static gate (new)
bash test/opt-008-makefile-static.sh        # exit 0 — all checks (45 targets, stubs, RED probes, deploy)

# migrate-check live (real repo)
make migrate-check                          # runs; correctly flags M-08's uncommitted
                                            # 20260810000007_storage_buckets.sql in both stacks (exit 1)
# Stub + placeholder live probes
make ios-beta                               # ❌ "M-17 must create fastlane/Fastfile…" (recipe exit 1, make 2)
make bundle-install                         # ❌ "No Gemfile — … M-19 scope (MKE-10)…" (exit 1/2)
make deploy-api; echo $?                    # placeholder echo, exit 0
make -n ios-release android-alpha           # dry-run renders the stub chains

# Scratch-repo RED/GREEN probes (inside opt-008 §3): GREEN clean → untracked RED → future-date RED
tools/agent_lock.sh release Makefile --owner "$AGENT_NAME"                  # ×7, all released
```

## Verification

- [x] `bash test/opt-008-makefile-static.sh` exit 0 — §1 `make -n` resolves all 45
      targets (incl. the 8 new); §2 stub contract (4 targets × target/command/
      guard) + LIVE fail-fast probes (exit 2 with M-17/Gemfile messages); §3
      migrate-check GREEN + both RED probes (untracked, future-dated) in a scratch
      repo; §4 deploy placeholders (doc pointer, zero `scheme://`, exit 0); §5
      `bash -n` self + helper.
- [x] `make migrate-check` runs: both stacks scanned; currently FAILS on M-08's
      uncommitted `20260810000007_storage_buckets.sql` (both stacks) — the gate
      working as designed (parity + date + format checks pass: 25/25, latest
      identical, no future dates).
- [x] `make ios-beta` / `make bundle-install` fail fast with the documented clear
      messages; `make deploy-api` echoes the placeholder and exits 0; `make -n`
      renders every stub chain correctly.
- [x] `tools/check_ports.sh --strict` unaffected (no port surface touched) — the
      new targets add no ports; no `scheme://` anywhere in the Makefile.
- [x] Lock evidence: 7 files acquired + released by `M-15-makefile-final`.
- [x] No commits; no `git add`; Juega untouched; no containers, no bundle, no
      fastlane, no network ops (scratch-repo + dry-run verification only).

## Lock list (acquire → release, owner `M-15-makefile-final`)

1. `Makefile` (.PHONY, migrate-check → script, fastlane stubs, bundle-install, deploy placeholders)
2. `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (header, §3 note, §3.3 Makefile contract table, §6 adoption)
3. `docs/to-fix/TODO.md` (M-15 workstream block)
4. `docs/to-fix/categories/14-MAKEFILE-CICD.md` (MKE-05/MKE-07/MKE-10 status)
5. `test/opt-008-makefile-static.sh` — new file
6. `tools/check_migrations.sh` — new file
7. `docs/history/phase-00-foundation/2026-08-10_M15-makefile-final.md` (this log)

## Issues found / handoffs (reported, NOT fixed — out of scope)

1. **`make migrate-check` currently exits 1 on M-08's uncommitted
   `20260810000007_storage_buckets.sql`** (untracked in BOTH stacks) — this is the
   gate doing its job; the orchestrator commits at the next checkpoint and the
   check turns green. Nothing to fix in M-15's code.
2. **Handoff M-17/M-18:** implement the lanes EXACTLY as `platform :ios` +
   `lane :beta_testflight` / `lane :release_appstore` and `platform :android` +
   `lane :alpha_firebase` / `lane :release_play` — the opt-008 §2 grep + the
   §3.3 Makefile contract table pin these names; a rename breaks the gate. When
   `fastlane/Fastfile` lands, the opt-008 LIVE stub probes auto-skip.
3. **Handoff M-19:** create `Gemfile` (`gem "fastlane"` + `gem "cocoapods"`) +
   commit `Gemfile.lock`; `make bundle-install` will then run `bundle install`
   instead of failing.
4. **Handoff M-20..M-22:** `.github/workflows/*` may invoke the make targets
   (`make ios-beta` etc.) or fastlane directly with the §3.3 lane names — never
   invent new lane names; the MKE-07 CI half remains open.
5. **`run_all_backend.sh` auto-discovers `test/opt-*.sh`:** opt-008 is now a
   member of that suite's glob (like the static opt-005/opt-007 members — pass
   anywhere, no stack). Header of the runner (I-01's file) lists members 001-006
   — opt-007/opt-008 not enumerated; cosmetic, I-01/D-05 re-verification scope.
6. **Category-file status flips (MKE-05/MKE-07/MKE-10) are D-03's** at
   re-verification (M-11/M-13 precedent); evidence lives in TODO.md + this log.

## Sources consulted

- Repo: `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (§3.2/§3.3 lane shapes, §6 registry,
  §1.1/§1.2 target topology — the lane contract source), `docs/to-fix/categories/
  14-MAKEFILE-CICD.md` (MKE-05/07/09/10), `docs/history/…/2026-08-10_{M11-,
  M12-,M13-}.md` (Makefile-track precedent, exit-code/quoting gotchas),
  `test/opt-005-seed-dev-static.sh` + `test/opt-007-compose-static.sh` (static-gate
  style), `tools/check_secrets.sh` (script-gate + scratch-repo RED/GREEN pattern,
  M-13), `test/run_all_backend.sh` (opt-* auto-discovery — opt-008 joins the glob),
  AGENTS.md (Port Convention), `docs/process/{AGENT-RULES,FILE-OWNERSHIP}.md`.
- GNU make — exit status 2 on failing recipes / `.PHONY` semantics:
  <https://www.gnu.org/software/make/manual/make.html#Error-Rules>
- fastlane — lane/`platform` definition + `bundle exec fastlane <platform>
  <lane>` invocation shape: <https://docs.fastlane.tools/advanced/lanes/>
- bash — `${v:0:8}` substring expansion (POSIX-mode quirk-free in bash) and
  `10#` decimal forcing: <https://www.gnu.org/software/bash/manual/bash.html>
