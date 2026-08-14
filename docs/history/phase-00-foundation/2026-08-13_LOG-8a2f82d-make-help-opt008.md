# Makefile `help` Target Cheatsheet + opt-008 Coverage (2026-08-13, `8a2f82d`)

**Agent:** R2-log-backfill (docs-remediation sweep) · **Branch:** `fixes` · **HEAD:** `8a2f82d`

## What was built

- New **`help`** target (Makefile:18): full target cheatsheet grouped by area —
  BUILD/RUN (`build`/`dev`/`install`/`build-install`/`uninstall`/`clear-storage`/
  `clean`), DEVICE TUNNELS (macOS → <build-host>), CHECKS / TESTS, GO BINARIES
  (`build-cli`/`build-linux`/`build-api`), SUPABASE STACKS (ports
  54382/54386/54381/54384/54443). Documents `TARGET=all|android|waydroid|ios|
  ios-adhoc|simulator`.
- `build-install` added to the `.PHONY`/help surface.
- Pinned by opt-008 (`test/opt-008-makefile-static.sh`): `make -n help`
  resolves dry for the whole target inventory, incl. override forms
  (`TARGET=/OVERRIDES=/FLUTTER_DEFINES=`).
- 1 file changed (Makefile): **+89/−16**.

> Note: the commit message also credits opt-008 with the `GIT_INDEX_FILE`
> scratch-repo hardening — that hunk actually landed in `81722ef`
> (opt-008 +24). `8a2f82d` itself touches only the Makefile.

## Decisions

- One discoverable entry point for the target surface instead of grepping the
  Makefile — the cheatsheet and `.PHONY` list are kept in sync by opt-008's
  dry-run assert (a target added to `.PHONY` without a help line fails the
  gate).

## Commands run

```bash
git show 8a2f82d --stat            # 1 file, +89/−16
make -n help                       # resolves (dry run, opt-008 probe)
bash test/opt-008-makefile-static.sh
```

## Follow-ups

- None — help output doubles as the on-ramp for new targets; keep opt-008's
  target list in sync when adding targets.
