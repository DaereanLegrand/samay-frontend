# Docs ↔ Code Audit + P0/P1 Refresh (2026-08-13)

**Agent:** audit-2026-08-13 (human-run audit session) · **Branch:** `fixes` · **HEAD:** `8a2f82d`

## What was built

1. **Full docs↔code audit** — 8 parallel read-only verifier agents covered every doc domain
   (specs, daily logs/DONE markers, to-fix, agents/orchestration, security, infra/ports,
   design, test baselines). Full evidence: `docs/audit/2026-08-13_DOCS-vs-CODE-AUDIT.md`.
2. **Live baseline re-verification:**
   - `flutter test` → **2209/2209** (was 2032 at gate, 2151/2151 in README)
   - `go test ./...` → green, **182 `func Test`** (was "82"/"178")
   - `dart analyze` → **0 issues** (was "0 errors / 19 pre-existing info")
   - pgTAP `plan(385) == 385` both stacks (was 125/312/321/344 across docs)
   - opt-tests 8 files (docs enumerated 6); integration 18 registered/19 files;
     manual QA 55 cases (docs said 63); migrations 33/33 (docs said 18/17)
3. **P0 fixes:**
   - `Makefile:214` `LANE_SUPABASE_URL` real domain `https://samay-api.qallariy.lat`
     → placeholder `https://supabase.samay.example.com` (DEPLOYMENT-PLACEHOLDER R03);
     comment updated. (Caddyfile/nginx templates verified as documented homes per
     SELFHOSTING §4 — left untouched.)
   - `fastlane/report.xml` stray (gitignored) removed.
   - Baselines refreshed in: GATE-REPORT (addendum), DEVELOPMENT-WORKFLOW (§1.6/§3.4/
     §3.5/§3.6/§4.1/§4.2/§4.3/§8), test/README, run_all_backend.sh header (opt-007/008),
     root README, SELFHOSTING (pgTAP 385 ×4 + rows 25/26), DEPLOYMENT-PLACEHOLDER §3.2
     historical numbers, Makefile:667 (312→385).
4. **P1 fixes:**
   - `cross-references.md` — ~25 step rows flipped ❌/⚠️ → ✅/⚠️ with evidence notes
     (ECRT/EDET/ESTA/EINV/QRAT/QRSC/QEDG/CHAT/CHPT/CHMC/FEED/PHUP/COLL/NOTI/NTRG/
     SLED/SDIS/COSM/GRCK/GMCR/GWAG/PLAN/PFND/APIS); Known Issues table refreshed
     (ports, parity, schema_test, 23-failures, VComingSoonScreen, realtime path,
     go count); dependency graph + critical path + header date updated.
   - `PHASE-INVENTORY.md` (R-4) — functions-dir existence, 33/33 migrations, 17
     triggers, `ranks.update_cron` scheduled, share_plus removal, facade deletion,
     AUTH/PRFL remaining gaps, phases-05-15 dev-dirs note, Go count.
   - `DEVELOPMENT-WORKFLOW.md` §4.1 (mid-remap warning → landed) + §4.2 (`.env`-asset
     warning → dart-define landed) + §4.3 + §8 cheatsheet.

## Decisions

- Keep dated snapshots (GATE-REPORT 2026-08-11 table, AGENT-REGISTRY rows, ORCHESTRATION
  baselines, daily logs) intact as historical records; append an addendum/refresh note
  instead of rewriting history.
- Date convention: local dates (commits use -0500 local; HEAD 2026-08-13 20:35). The
  `20260814*` migration names and the "removed 2026-08-14" annotations follow UTC
  (commit a0814c7 = 08-14 01:34 UTC) — both conventions coexist in the repo; left as-is.
- Post-gate E2EE/chat/QR/ranks/notify code (commits 81722ef/e0eab3c/8a2f82d) reflected
  in cross-references/PG numbers but NOT re-documented in SECURITY.md/E2EE-ARCHITECTURE.md
  (P2 follow-up — refresh requires code-level security review).

## MISTAKE

- In `DEPLOYMENT-PLACEHOLDER.md` §3.2 I replaced a 6-line block with a 5-line one,
  silently dropping the `bash -n test/*.sh tools/*.sh supabase/*.sh # syntax gate`
  line. Caught by re-reading the edited region and restored immediately. Lesson:
  after multi-line edits, re-read the block before moving on.

## Commands run

```bash
flutter test                                  # 2209/2209
go test ./...                                 # green, 182 func Test
dart analyze                                  # 0 issues
rg -c '^func Test' --glob '*_test.go' cmd internal
bash tools/check_ports.sh --strict            # 19 mappings / 221 refs / 0 violations — STRICT PASS
git log --format='%h %ad %s' --date=format:'%Y-%m-%d %H:%M %z' -4   # date-convention check
git ls-files supabase/volumes/proxy/ fastlane/  # tracked-file check for the URL finding
```

Locks held (tools/agent_lock.sh): Makefile, GATE-REPORT.md, DEVELOPMENT-WORKFLOW.md,
test/README.md, run_all_backend.sh, cross-references.md, PHASE-INVENTORY.md, README.md,
SELFHOSTING.md, DEPLOYMENT-PLACEHOLDER.md, docs/audit/* (new file, creator-owned) —
all released after edits.

## Follow-ups (tracked in docs/audit/2026-08-13_DOCS-vs-CODE-AUDIT.md §6)

- P2: SECURITY.md + E2EE-ARCHITECTURE.md refresh (incl. `20260811000001` anon-EXECUTE
  fix + migrations 20260814000001..05), ORCHESTRATION CI-removal note, FILE-OWNERSHIP
  phantom paths (`.agents/`, `build.yaml`), SELFHOSTING reset/MinIO rows + row-27 +
  opt-key defaults, DEPLOYMENT-PLACEHOLDER .env inventory/line refs.
- P3: to-fix category status sweep (~17 rows) + TODO.md:1695-1852 CI-block removal note.
- P4: design-doc departure notes (VComingSoonScreen, hint color, pressed ratios, feed
  sizes), spec status-section refresh, daily logs for 5 undocumented commit groups.
