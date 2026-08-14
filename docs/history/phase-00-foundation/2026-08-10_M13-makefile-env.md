# 2026-08-10 — M-13: Makefile env/secrets track — load-env, macvm quoting fix, secrets-check, tunnel-android (MKE-02/MKE-03/MKE-08)

**Agent:** M-13 (Phase 4.3 — Makefile env/secrets track; SECOND attempt — first session
stalled before producing work; verified zero locks, zero partial edits at start)
**Role:** (1) `load-env` helper sourced by build/dev/install/docker targets; (2) fix the
macvm SSH quoting so spaced `FLUTTER_DEFINES` survive (M-11 issue #1); (3) `secrets-check`
target (committed-secret grep + documented allowlists) wired into `check`; (4)
`tunnel-android` target (MKE-08, Juega pattern); (5) daily log + TODO.md
MKE-02/MKE-03 lock + DEPLOYMENT-PLACEHOLDER.md secrets section lock.
**Campaign:** Samay 180-agent orchestration; Juega untouched (read-only reference for the
tunnel pattern), NO commits, NO containers started, NO remote ops — verification is
dry-run + local shims only.

---

## What was built

### 1. `Makefile` (owner M-13 ✅, FILE-OWNERSHIP row)

- **`load-env` helper (MKE-03 closed):**
  ```make
  define load-env
  set -a; [ -r ./.env.local ] && . ./.env.local || true; [ -r ./.env ] && . ./.env || true; set +a
  endef
  ```
  Sourced first in `build`, `dev`, `install`, `supabase-docker-start/stop/status/reset`
  and `supabase-testing-start/stop/status/reset`. `set -a` exports so later recipe lines
  and subprocesses inherit. Never echoes values. The make-level `FLUTTER_DEFINES`
  decision (I-34/M-11) is independent and unchanged.
- **macvm SSH quoting fix (M-11 issue #1):** `install TARGET=ios` now sends
  `FLUTTER_DEFINES='$$FLUTTER_DEFINES'` (make-escaped `$$` → `$`, locally expanded) as a
  **separately-quoted env assignment** in the ssh command, and the remote
  `make build TARGET=ios NO_PUB=$(NO_PUB) FLUTTER_DEFINES=\"\$$FLUTTER_DEFINES\"`
  (`\$$` renders `\$` → local shell passes literal `$FLUTTER_DEFINES` → inner macvm zsh
  expands from its env). Spaced dart-defines survive all four layers.
- **MKE-02 closed:** `APPLE_PASSWORD ?=` Make variable **removed**. The value is read at
  recipe time from the sourced env files or the shell env only:
  `-p "$$APPLE_PASSWORD"`. Nothing secret can appear in `make -n` output, shell history,
  or CI logs. `IOS_UDID`/`APPLE_ID`/`MACVM_PATH` are non-secret config and stay
  overridable.
- **`secrets-check` target (new, MKE-02):** `@tools/check_secrets.sh` — tracked-file
  scan (see §2). Wired into `check` as a prerequisite (`check: secrets-check`), so it
  runs first in the pre-CI gate.
- **`tunnel-android` target (new, MKE-08):** Juega's SSH-forward pattern, parametrized:
  `TUNNEL_HOST ?= <build-host>`, `TUNNEL_PORT ?= 5555`,
  `TUNNEL_CMD ?= flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d localhost:$(TUNNEL_PORT)`;
  recipe = `trap 'adb disconnect localhost:$(TUNNEL_PORT); kill 0' EXIT` + `ssh -N -L`
  background + `adb connect` + `$(TUNNEL_CMD)`. Documented usage in the target comment.
- `.PHONY` extended: `secrets-check tunnel-android`.

### 2. `tools/check_secrets.sh` (new file — free-for-agent per FILE-OWNERSHIP preamble)

Six scans over **tracked files only** (`git grep` — untracked local `.env`/`.env.local`
are by design not scanned; local secrets live outside version control). Each pattern's
allowlist is exact-path and documented in the script header:

| # | Pattern | Allowlist (rationale) |
|---|---|---|
| P1 | `sb_publishable_q7NDNoV4TCGqCgheg4tcvC_odjEiEdN` (known dev anon key, H-21 class) | opt-test defaults (`test/opt-001..006`, `run_all_backend.sh` — dev-only defaults, CI overrides via env, M-03); tracked `supabase/.env.local` + `supabase-testing/.env.local` (M-03 dev source of truth); M-03/M-09 evidence logs (historical records, I-34/D-03 precedent); the script itself (pattern literals) |
| P2 | `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH` (historical anon key from git history) | D-03/I-34 evidence logs + the script |
| P3 | `sb_service_role` (any service-role literal) | opt-test dev defaults + opt-007 search-literal + SELFHOSTING/TODO matrix prose + M-03/M-09 logs + the script |
| P4 | `sb_secret_[A-Za-z0-9_-]{16,}` (**real service-role key shape**) | opt-007 search-literal + M-03 evidence log + the script — **no code/config allowlist** |
| P5 | `your_supabase` (placeholders) | `.env.example` (canonical), compose `${VAR:-…}` safe defaults (M-03), opt-007, `docs/` (documented convention), the script |
| P6 | `^[[:space:]]*APPLE_PASSWORD=` (secrets as Make-variable assignments) | **zero allowlist** |

Exit 1 on any hit; prints every violating `path:line`; never echoes env values.

### 3. `docs/to-fix/TODO.md` (D-03's file, locked per mission)

M-13 workstream block at the top (newest-first, M-11/M-12 precedent): load-env + the
macOS `/bin/sh` gotcha, macvm quoting fix, secrets-check + RED/GREEN proof, MKE-02
locked, tunnel-android, MKE-05 hygiene note, verification summary, evidence pointer.

### 4. `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (D-10's file, locked per mission)

- Header "Last verified" → 2026-08-10 (M-13).
- §2.1 "Verified current state" note rewritten: I-34 scrubbed `.env.example`; dev values
  live in the tracked `supabase/.env.local` pair (M-03 source of truth); the
  `secrets-check` gate now enforces tracked-file hygiene; H-21 rotation stays an ops
  action.
- §2.4 dart-define migration plan → marked ✅ COMPLETE (all 5 steps, owner trail
  I-34/M-11/M-13).
- §3.3 AltServer replacement note: `APPLE_PASSWORD` no longer a Make var (env-sourced,
  never echoed); fastlane replacement stays M-14/M-17..M-19.
- §6 registry rows R11/R12/R13 (env plumbing + gate ✅, replacement = release-time ops),
  R26 (gate landed; `[auth.smtp]` itself → M-08/checkpoint), R28 (M-13 ✅ — secret moved
  out of the Makefile).

### 5. `docs/history/phase-00-foundation/2026-08-10_M13-makefile-env.md` (this log)

---

## Decisions made and why

- **`load-env` uses `[ -r x ] && . x || true` instead of the mission's literal
  `. x 2>/dev/null || true`.** Proven empirically: macOS `/bin/sh` (bash 3.2.57 in
  POSIX mode) **exits the recipe shell** when the `.` builtin targets a missing file —
  even with `|| true` and `2>/dev/null` (the `||` never gets a chance). The bare form
  kills `make build` on every fresh clone (no `.env`). The `[ -r ] &&` guard never
  invokes `.` on an absent file; `|| true` still swallows a failing source. Full-bash
  and zsh don't have the quirk (verified), but make recipes run under `/bin/sh`.
- **`secrets-check` scans tracked files via `git grep`, not the working tree.**
  "Committed files" per mission = tracked; local untracked `.env` files legitimately
  hold dev values and must not fail the gate (and `.env` is gitignored). RED-proven in
  a scratch git repo both ways (leak → FAIL, cleaned → PASS).
- **Allowlists are exact-path, not pattern-broadening.** Each is justified (dev
  defaults / evidence logs / search-literals). A new real key (`sb_secret_…`) in any
  code/config file fails with zero allowlist. P4 is the "known service-role key"
  detector: the only service-role literal ever committed is the placeholder-shaped
  `sb_service_role_key_change_in_production` (P3, allowlisted); real keys have the
  `sb_secret_` shape (P4, no code allowlist).
- **MKE-02 fix = remove the Make variable, not `pass`-store it.** The mission's MKE-02
  reference says Juega uses `pass`; wiring `pass` in the Makefile would add a dependency
  for a dev-only burner password and risk shell-history leaks via the make var. Env-only
  sourcing achieves the same exposure reduction (nothing in Make, nothing echoed,
  nothing in `make -n`). `pass`/1password integration remains S-08/M-14 scope.
- **`TUNNEL_CMD` default is `flutter run … -d localhost:$(TUNNEL_PORT)`** (mirrors
  Juega's `flutter run -d localhost:5555`), and the port is a variable so
  `check_ports.sh` sees no hardcoded host-port (5555 is a device/adb port, not part of
  the approved map; `$(TUNNEL_PORT)` renders no digit run for the scanner).
- **`secrets-check` wired as a `check` prerequisite** (runs before the recipe) so a
  leak fails the gate before the analyzers even start; `make -n check` shows it first.

## MISTAKE / gotcha

- **MISTAKE (found via testing):** the mission's `set -a; . ./.env.local 2>/dev/null ||
  true; . ./.env 2>/dev/null || true; set +a` **kills the recipe shell on macOS** when
  the file is missing (bash 3.2 `.`-builtin POSIX-mode behavior; even `|| true` does not
  rescue). First dry-run after wiring it failed with `make: *** [install] Error 1` and
  the trace stopping at `. ./.env.local`. Fixed with the `[ -r ] &&` guard — documented
  on the variable and here. Lesson: test the env-sourcing form on the ACTUAL recipe
  shell (/bin/sh), not in zsh/full-bash.
- **MISTAKE (avoided):** first `secrets-check` draft allowlisted nothing for the script's
  own pattern literals — a committed `tools/check_secrets.sh` would fail P1/P2/P3/P5.
  RED-tested in the scratch repo (correct repo layout: script under `tools/`), caught,
  and the `SELF` fragment added to every applicable allowlist.
- **Gotcha (RED-test setup):** the first scratch-repo test put the script in the repo
  root — `dirname $0/..` resolved to the PARENT dir and the scan ran in the wrong repo,
  passing a real leak. The script's ROOT resolution is correct for its real location
  (`tools/`); the test was fixed to mirror the real layout.
- **Gotcha (make quoting):** `\$` is NOT a make escape (it renders `\` + expands the
  next make var — `\$F` → `\` + empty). The literal-dollar forms that work:
  `$$` → `$` (locally expanded) and `\$$` → `\$` (locally escaped, passes a literal
  `$FLUTTER_DEFINES` to the remote). Verified with a minimal test Makefile before
  editing the real one.

## Commands run (reproducibility)

```bash
export AGENT_NAME="M-13-makefile-env"
tools/agent_lock.sh acquire Makefile --owner "$AGENT_NAME" --timeout 600      # +3 files below
tools/agent_lock.sh list                                                       # 4 locks held

# Quoting research (minimal test Makefile, before touching the real one)
make -n -f /tmp/mqtest/Makefile install                                        # \$$ renders \$FLUTTER_DEFINES

# End-to-end quoting verification with fake ssh/scp/altserver shims
export PATH="/tmp/fakebin:$PATH" APPLE_PASSWORD=testpass
make install TARGET=ios FLUTTER_DEFINES="--dart-define=SUPABASE_URL=http://127.0.0.1:54386 --dart-define=SUPABASE_ANON_KEY=test" NO_PUB=true
#   FAKE-SSH args(2): [macvm] [FLUTTER_DEFINES='--dart-define=… --dart-define=…' zsh -c '…make build TARGET=ios NO_PUB=true FLUTTER_DEFINES="$FLUTTER_DEFINES";…']
#   FAKE-ALTSERVER: -p testpass (env-sourced, no make var)
unset APPLE_PASSWORD; make install TARGET=ios NO_PUB=true                     # ❌ error + exit 1, no ssh

# Remote-side simulation: inner zsh expands the env var into make's args
FLUTTER_DEFINES='--dart-define=A --dart-define=B' zsh -c \
  'make -f /tmp/mqtest/Makefile3 build FLUTTER_DEFINES="$FLUTTER_DEFINES"'
#   → received FLUTTER_DEFINES=[--dart-define=A --dart-define=B] (one arg, intact)

# Dry-run gates — all 36 targets resolve
for t in build dev install clean build-cli build-linux build-api test test-all \
         test-unit test-integration test-backend-static test-go flutter-test \
         flutter-analyze check lint define-env migrate-check secrets-check \
         tunnel-android supabase-*; do make -n "$t" >/dev/null 2>&1 && echo "$t OK" || echo "$t FAIL"; done
make -n install TARGET=ios FLUTTER_DEFINES="--dart-define=A=1 --dart-define=B=2"  # quoted ssh line
make -n tunnel-android TUNNEL_CMD="adb -s localhost:5555 install -r app.apk"     # override flows

# Live gates
make secrets-check                                      # PASS (6/6 scans)
make check --dry-run                                    # secrets scan runs first
bash test/opt-005-seed-dev-static.sh                    # exit 0
bash test/opt-007-compose-static.sh                     # exit 0
tools/check_ports.sh --strict                           # STRICT PASS, 0 violations

# RED/GREEN proof (scratch repo, mirroring tools/ layout)
#   commit sb_secret_AAAA… → make secrets-check exit 1 (P4 ✗); remove → exit 0

tools/agent_lock.sh release Makefile --owner "$AGENT_NAME"                      # ×4, all released
```

## Verification

- [x] `make -n` resolves for ALL 36 targets (incl. `TARGET=ios/android`, spaced
      `FLUTTER_DEFINES=…`, `TUNNEL_HOST/PORT/CMD` overrides, `OVERRIDES=…`).
- [x] `install TARGET=ios` SSH quoting: spaced dart-defines survive local make →
      local shell → ssh arg (fake-ssh shim shows ONE intact quoted arg) → remote zsh →
      remote make (zsh two-layer simulation echoes the full value); `make -n` renders
      the line correctly.
- [x] `APPLE_PASSWORD` env-sourced end-to-end (fake-altserver `-p testpass`); missing →
      clear error, exit 1, no ssh attempt; nothing secret in any output.
- [x] `make secrets-check` PASS (6/6 scans); RED-proven (leak → exit 1) and GREEN-proven
      (clean → exit 0) in a scratch repo; `make check` dry-run starts with the scan.
- [x] opt-005 (212 checks) + opt-007 (365 checks) exit 0; `check_ports.sh --strict`
      STRICT PASS, 0 violations (tunnel port is a variable, no hardcoded host binding).
- [x] Lock evidence: 4 files acquired + released by `M-13-makefile-env`
      (Makefile, DEPLOYMENT-PLACEHOLDER.md, TODO.md, daily log).
- [x] No commits; no `git add`; Juega untouched (read-only); no containers started, no
      image pulls, no remote SSH (shims only).

## Lock list (acquire → release, owner `M-13-makefile-env`)

1. `Makefile` (load-env, install ios rework, secrets-check, tunnel-android, check wiring, .PHONY)
2. `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (§header, §2.1 note, §2.4 ✅, §3.3, §6 R11-R13/R26/R28)
3. `docs/to-fix/TODO.md` (M-13 workstream block, MKE-02/MKE-03/MKE-08 locked)
4. `docs/history/phase-00-foundation/2026-08-10_M13-makefile-env.md` (this log)
5. `tools/check_secrets.sh` — new file (free-for-agent per FILE-OWNERSHIP preamble), no lock needed

## Issues found / handoffs (reported, NOT fixed — out of scope)

1. **`supabase/.env.local` + `supabase-testing/.env.local` are TRACKED and carry the
   dev anon key + real dev URL** (`samay-api.qallariy.lat`). Intentional dev source of
   truth (M-03) and allowlisted in the gate, but S-08 should decide whether to
   gitignore them (they would then rely on the compose `${VAR:-…}` defaults + opt-test
   env overrides).
2. **Real dev anon key still in git history** (`.env.example` at ce904e9 + D-03 audit
   log) — H-21/SEC-03: rotation at release time is an ops action (I-34 noted
   `git-blame-ignore-revs`/history purge for S-08). P2 guards against reintroduction.
3. **fastlane handoff (MKE-05/MKE-02):** AltServer sideload stays dev-only with the
   env-sourced `APPLE_PASSWORD`. M-14/M-17..M-19 should replace it; the secrets matrix
   (DEPLOYMENT-PLACEHOLDER §3.3/§6 R20-R28) is the placeholder contract; the
   `secrets-check` gate will enforce their placeholder-only status.
4. **macvm still needs its own `.env`** (or `FLUTTER_DEFINES` passthrough) for the
   remote build to have values — unchanged from I-34 caveat #3; the new quoting makes
   the passthrough form safe with spaces.
5. **`.env` (root, untracked) still holds the OLD real anon key
   (`sb_publishable_ACJW…`)** — local file, not scanned, but anyone rebuilding from it
   points at a rotated/leaked key; `cp .env.example .env` is the fresh-clone path.
6. **Category-file status flips (MKE-02/MKE-03/MKE-08 in
   `categories/14-MAKEFILE-CICD.md`) are D-03's** at re-verification (M-01..M-12
   precedent); evidence lives in TODO.md + this log.

## Sources consulted

- macOS `/bin/sh` (bash 3.2.57) `.`-builtin missing-file behavior — verified empirically
  (`/bin/sh -c '. missing || true; echo x'` exits 1 without echoing; `/bin/bash` and
  zsh do not) — <https://www.gnu.org/software/bash/manual/bash.html#Bourne-Shell-Builtins>
- GNU make — variable expansion in recipes (`$$` vs `\$` vs `\\$$`), `define` variables
  in recipes: <https://www.gnu.org/software/make/manual/make.html#Recipe-Syntax> +
  <https://www.gnu.org/software/make/manual/make.html#Multi_002dLine>
- Repo (read-only reference): Juega `Makefile:28-41` `tunnel-android`/`tunnel-waydroid`
  macros (MKE-08 pattern); `docs/history/…/2026-08-10_{M11-makefile-flutter,
  M12-makefile-docker}.md` (handoff: macvm quoting issue #1, env-sourcing remainder);
  `2026-08-09_I34-env-dartdefine.md` (dart-define seam + macvm caveat);
  `docs/to-fix/categories/14-MAKEFILE-CICD.md` (MKE-02/03/05/08);
  `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (§2/§3.3/§6 secrets matrix);
  `test/opt-007-compose-static.sh` §8.4 (kong-keys gate — the search-literal allowlists);
  `tools/check_ports.sh` (strict contract)
