# Post-Orchestration Docs Restructure (2026-08-13)

**Agent:** audit-2026-08-13 (human-run session) · **Branch:** `fixes` · **HEAD:** `8a2f82d`

## What was built

Completed the docs↔code audit session (see `2026-08-13_DOCS-audit-refresh.md`) with:

1. **Campaign-doc deletions (Tier 1 + Tier 2):**
   - `docs/agents/AGENT-REGISTRY.md`, `docs/agents/ORCHESTRATION.md`,
     `docs/agents/AGENT-RULES.md` — 180-agent campaign lifecycle docs (COMPLETE
     at STOP-180, 2026-08-11)
   - `docs/development/phase-04-luxe/ORCHESTRATION-LUXE.md`,
     `GEMMA-ROUNDS.md` — luxe mini-campaign internals
   - Root `flutter_01.log`, `flutter_02.log` — stray build logs
   - All references rewired to the surviving doc (`docs/process/DEVELOPMENT-WORKFLOW.md`)
     in AGENTS.md, README.md, DEVELOPMENT-WORKFLOW.md, GATE-REPORT(s), .opencode/,
     tools/check_ports.sh, integration_test/README.md, TODO.md, SECURITY/E2EE docs,
     SELFHOSTING.md, DISCO-LUXE design doc; `test/meta/conventions_test.dart`
     assertions updated (AGENT-RULES → DEVELOPMENT-WORKFLOW, tool/ → tools/).

2. **Docs restructure (Diátaxis model — diataxis.fr):**

   | Before | After |
   |---|---|
   | `docs/planification/` | `docs/specs/product/` (read-only product specs) |
   | `docs/implementation/` | `docs/specs/steps/` (read-only step specs + cross-references) |
   | `docs/development/` | `docs/history/` (daily logs + PHASE-INVENTORY) |
   | `docs/agents/` | `docs/process/` (DEVELOPMENT-WORKFLOW.md, FILE-OWNERSHIP.md) |
   | `docs/agents/GATE-REPORT.md` | `docs/audit/GATE-REPORT.md` |
   | `docs/development/phase-04-luxe/GATE-REPORT-LUXE.md` | `docs/audit/GATE-REPORT-LUXE.md` |
   | `tool/` (5 files) | merged into `tools/` |

   - New **`docs/README.md` hub** — "where things live" table + why (Diátaxis
     quadrants) + quick navigation.
   - AGENTS.md Documentation Standards + Orchestration Protocol section rewritten
     (campaign COMPLETE; standing protocol = `docs/process/DEVELOPMENT-WORKFLOW.md`).
   - Repo-wide path reference rewrite via `git mv` + perl:
     `docs/planification→docs/specs/product`, `docs/implementation→docs/specs/steps`,
     `docs/development→docs/history`, `docs/agents→docs/process`,
     `tool/→tools/` (`\btool/` with `(?<!s)` lookbehind — `.dart_tool/` untouched).

## Decisions

- **Diátaxis** over ad-hoc layout: process (how-to) / specs (reference) /
  design|security|infra (explanation) / history|audit|to-fix (records). New docs
  go in the existing area, not new top-level dirs.
- Deleted campaign docs are NOT archived — their content is superseded by
  `DEVELOPMENT-WORKFLOW.md` (rules) and `GATE-REPORT.md`/`GATE-REPORT-LUXE.md`
  (gate evidence, both preserved in `docs/audit/`).
- `tool/` merged into `tools/` because the split was a recurring source of
  confusion (FILE-OWNERSHIP row 25 documented the `tool/check_ports.sh` vs
  `tools/check_ports.sh` mix-up).
- `.opencode/` kept (opencode config + 4 agents are live tooling, still used
  post-campaign); its `instructions` now inject AGENTS.md +
  docs/process/{DEVELOPMENT-WORKFLOW,FILE-OWNERSHIP}.md.

## MISTAKE

- `git mv docs/development docs/history` failed with "bad source" because the
  campaign files I `rm`'d were still in git's index. Fix: `git rm --cached` the
  deleted files first, then `git mv` (done for both the agents/ and the
  luxe-campaign deletions).
- Initial `rg` for the bulk replace silently skipped `.opencode/` (gitignore),
  so the perl pass missed it; caught it via a follow-up grep and fixed the
  `.opencode` files separately. Lesson: run bulk replaces with `--no-ignore`.

## Commands run

```bash
git rm --cached <deleted-campaign-files>   # unstage rm'd files so git mv works
git mv docs/planification docs/specs/product
git mv docs/implementation docs/specs/steps
git mv docs/development docs/history
git mv docs/agents docs/process
git mv docs/process/GATE-REPORT.md docs/audit/
git mv docs/history/phase-04-luxe/GATE-REPORT-LUXE.md docs/audit/
git mv tool/{gen_testing_anon_key.py,hooks,icon_gen.dart,pre-commit.sh,seed_dev_data.sh} tools/
perl -pi -e 's{docs/planification}{docs/specs/product}g; ... ' $(rg -l -P "docs/(planification|implementation|development|agents)|(?<!s)tool/" .)

# Validation (all green):
dart analyze                # 0 issues
flutter test                # 2209/2209
go test ./...               # green
bash test/opt-005-seed-dev-static.sh   # PASS
bash test/opt-007-compose-static.sh    # PASS
bash test/opt-008-makefile-static.sh   # PASS
bash tools/check_ports.sh --strict     # STRICT PASS (19 mappings / 221 refs)
bash -n tools/*.sh tools/hooks/pre-commit; python3 -m py_compile tools/gen_testing_anon_key.py; ruby -c tools/ios_dev_signing.rb
```

## Follow-ups

- P2/P3/P4 items unchanged (see `docs/audit/2026-08-13_DOCS-vs-CODE-AUDIT.md` §6).
- Consider retiring `docs/process/FILE-OWNERSHIP.md` when parallel-agent work stops.
