# 2026-08-09 — D-12: Phase Inventory + Phase 05–15 PLANs

**Agent:** D-12 (Phase 4.1 — documentation) · **Role:** phase inventory + phase-05+ plan docs
**Owner map:** `docs/history/**` phase inventory + phase-05+ plan docs (per `docs/process/FILE-OWNERSHIP.md`)
**Campaign:** Samay 180-agent orchestration, started 2026-08-09 · **Branch:** `fixes`

## What was built

1. **`docs/history/PHASE-INVENTORY.md`** — phase-by-phase inventory for phases 00–15:
   - Table per phase: step, DONE marker existence, cross-references.md status, spec file,
     dev logs present, and a **reality check** (verified against the working tree).
   - Global findings: 34 DONE markers exist for phases 00–04 (6+14+6+3+5) — all **empty
     files** except `GROU.DONE`/`GLIM.DONE` (which carry "⚠️ PARTIALLY MET" gap notes);
     `FLMT` has no marker (🔴 blocked by `EEDG`); phases 05–15 have zero markers/dirs.
   - Orchestration workstream status table (I-01, I-02/M-01..M-10, I-37/I-38, D-11/U-*,
     I-49..I-78) with verified reality.
2. **11 PLAN.md files** under `docs/history/` (one per unimplemented phase):

| Dir | Steps covered | Orchestration agents mapped |
|-----|---------------|-----------------------------|
| `phase-05-events/` | ECRT, EDET, ESTA, EINV, EEDG | I-54, I-55, I-66, I-49..I-52, I-72..I-74, I-76, I-77, I-78 |
| `phase-06-qr-system/` | QRAT, QRSC, QEDG | I-57, I-49..I-52, I-76, I-77, I-78 |
| `phase-07-chat/` | CHAT, CHPT, CHMC | I-56, I-37, I-38, I-49..I-52, I-76, I-77, I-78 |
| `phase-08-social-feed-photos/` | FEED, FEET, PHUP, COLL | I-58, I-59, I-49..I-52, I-72, I-74, I-76, I-77, I-78 |
| `phase-09-notifications-push/` | NOTI, PUSH, NTRG | I-53, I-66, I-68, I-49..I-52, I-77, I-78 |
| `phase-10-shards-cosmetics/` | SLED, SDIS, COSM, GCOS | I-62, I-64, I-49..I-51, I-72, I-74, I-77, I-78 |
| `phase-11-gamification-minigames/` | GRCK, GMCR, GWAG | I-63, I-52, I-49..I-51, I-74, I-77, I-78 |
| `phase-12-monetization-subscriptions/` | PLAN, RCBH, SOVR, PPAC, MPGR | I-61, I-71, I-49..I-51, I-77, I-78 |
| `phase-13-party-finder-video/` | PFND, VIDS, MUSC | I-60, I-56, I-38, I-59, I-49..I-51, I-66, I-74, I-78 |
| `phase-14-alpha-beta-launch/` | ATST, RSDK, PLAT, TEST, BTA1, BTA2, BLNC | I-61, I-66, I-68, I-70, I-75, I-77, I-78, I-41 (indirect) |
| `phase-15-post-mvp-web-servers/` | APIS, DASH, PORT, VENU, DEPL | I-41, I-39, I-40, I-42, I-43, I-50, I-51, M-21 (groundwork) |

Each PLAN.md = phase summary from the implementation specs (read all 45 phase-05..15
spec files), step table with dependency status from cross-references.md, the
orchestration agents starting work there (from ORCHESTRATION.md + FILE-OWNERSHIP.md),
and an acceptance checklist transcribed from the spec requirements — **no invented
scope**.

## Files created (lock acquire/release evidence)

All 13 locks acquired via `tools/agent_lock.sh acquire <path> --owner D-12` (batch,
2026-08-09T05:46:42Z–43Z), all released after writing. No conflicts (D-08/D-09/D-10
hold locks on their own files only).

| File | Lock acquired | Lock released |
|------|---------------|---------------|
| `docs/history/PHASE-INVENTORY.md` | ✅ | ✅ |
| `docs/history/phase-05-events/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-06-qr-system/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-07-chat/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-08-social-feed-photos/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-09-notifications-push/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-10-shards-cosmetics/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-11-gamification-minigames/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-12-monetization-subscriptions/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-13-party-finder-video/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-14-alpha-beta-launch/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-15-post-mvp-web-servers/PLAN.md` | ✅ | ✅ |
| `docs/history/phase-00-foundation/2026-08-09_D12-phase-inventory.md` (this log) | ✅ | ✅ |

## Verification (every claim checked against code, not docs)

| Claim | Evidence |
|-------|----------|
| Events screens are coming-soon placeholders | `lib/core/router/app_router.dart:115,120–125,149` → `VComingSoonScreen` |
| Chat is a placeholder | `app_router.dart:159`; group detail chat tab "Chat próximamente"; `supabase_service.dart` has full chat service layer (C-02) |
| QR / subscriptions / party-finder placeholders | `app_router.dart:168–171` |
| Feed is a static welcome | `lib/features/feed/feed_screen.dart` (no logic) |
| No events/qr/chat/notifications/photos/cosmetics/minigames/shards/party_finder feature dirs | `ls lib/features/` → auth, feed, friends, groups, profile |
| `EEDG`/`QEDG` blocked: no Edge Functions | `supabase/functions/` does not exist; `shard_distribution_dispatch_trigger` = `RAISE LOG` only |
| `APIS` blocked: no API server | `cmd/` contains only `samay-admin`; no `build-api` in Makefile |
| `I-01` blocked: no integration suite | `integration_test/` absent; only `opt-001-rls-security.sh` exists |
| CLI complete (phase 01) | 14/14 `.DONE` markers; 9 cobra command groups in `cmd/samay-admin/`; `samay` binary at root |
| Port remap partial (I-02) | `supabase/config.toml`: api=54386/studio=54381/inbucket=54384/analytics=54388 but `[db] port=5432`; compose maps `5432:5432`,`54321:8000`,`54443:8443` |
| `supabase-testing/` one migration behind | 17 vs 18 migrations (missing `20260724000002_fix_donate_shards_rpc.sql`) |
| DONE markers read directly | All 34 marker files cat'ed; GROU/GLIM carry PARTIALLY-MET text, rest empty |

## Issues found (for implementation agents / orchestrator)

1. **DONE-marker semantics:** 32/34 markers are empty files; GROU/GLIM markers document
   partial work while the steps are still ⚠️ in cross-references. V-03 must not treat
   "marker exists" as "spec complete" — AUTH/PRFL have markers yet are 37/64 + partial.
2. **`/event/:inviteToken` shadowed by `/event/:eventId`** (pre-existing NAV ordering
   issue, app_router.dart:120–125) — must be fixed before EINV/QRAT deep links (I-54/
   I-55/I-66/I-57 should coordinate).
3. **GLIM hardcodes:** `group_detail_screen.dart` `_getMemberLimit()` returns `'14'`;
   `create_group_screen.dart` hardcodes `groupCount >= 5`. `app_config` keys are seeded
   but unused — I-49/I-71 wiring needed.
4. **`structure_test.dart`** passes on empty dirs — it won't catch placeholder feature
   dirs created during phase 05+ work.
5. **`ranks.update_cron` (GRCK) + `override-reconciler` (SOVR/MPGR) not scheduled** in
   `20260510000002_cron.sql` — GRCK/SOVR implementers must add the cron schedules.
6. **Edge Functions have NO owning I-agent** for `EEDG`/`QEDG`/`RCBH`/`SOVR`/`MPGR`/
   `GRCK` — the 4.2 roster covers screens (I-54..I-64) and tests (I-76/I-77) but no
   agent owns `supabase/functions/**`. Orchestrator should dispatch one or extend I-76.
7. **AGENT-RULES.md says "150-agent orchestration"** while ORCHESTRATION.md/FILE-OWNERSHIP
   say 180 — minor doc inconsistency (D-01 owns AGENT-RULES.md; flag for V-08 too).
8. **`.env.example` carries a real-looking anon key** (`sb_publishable_ACJW...`) — D-06
   flagged; I-34/M-13 own removal (not touched by D-12).
9. **`supabase-testing/` parity gap** (migration 18 missing) — M-10/I-02 scope, but I-77
   pgTAP work must keep the two test files structurally aligned (per D-04's pattern).

## Sources consulted

- `docs/specs/steps/cross-references.md` (dependency graph + statuses)
- All 45 step specs in `docs/specs/steps/phase-05..15/`
- `docs/specs/product/samay_mvp_spec.md`, `samay_admin_cli_spec.md`, `samay_web_servers_spec.md`
- `docs/process/{ORCHESTRATION,AGENT-RULES,FILE-OWNERSHIP,AGENT-REGISTRY}.md`
- Full code read: `lib/**`, `cmd/**`, `internal/**`, `supabase/**`, `test/**`, Makefile, pubspec.yaml, go.mod

## MISTAKE / gotcha

- **MISTAKE (avoided):** while counting `.DONE` markers, I initially assumed "marker ⇒
  step complete". The GLIM/GROU markers proved otherwise (partial text inside). The
  inventory therefore treats markers as *as-built evidence* and always cross-checks the
  cross-references status column — documented as a reading rule in PHASE-INVENTORY.md.
