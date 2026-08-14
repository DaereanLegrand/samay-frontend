# 2026-08-09 — D-03: To-Fix Documentation Audit (truthful + maintainable)

**Agent:** D-03 (Phase 4.1 — Documentation) · **Role:** `docs/to-fix/` auditor
**Owner map:** `docs/to-fix/TODO.md` + all `docs/to-fix/categories/*.md` (per `docs/process/FILE-OWNERSHIP.md`)
**Campaign:** Samay 180-agent orchestration, started 2026-08-09

## What was built

Re-verified every one of the 112 findings in `docs/to-fix/TODO.md` against the actual code
(not the status column) and made the whole `docs/to-fix/` tree truthful and maintainable:

1. **TODO.md** — verified all 112 statuses; 4 flips: C-06 `❌→🔄` (backend opt-test harness now
   exists, Flutter `integration_test/` pending → I-01), M-23 `❌→✅` (all 4 missing RLS policies
   exist in fix migrations), M-24 `❌→✅` (central `toAppError()` mapping replaces `replaceAll`
   string-cleaning), M-35 `❌→✅` (same mapper). Header note added: actively tracked by the
   180-agent orchestration, statuses re-verified per agent completion.
2. **README.md** (docs/to-fix) — header note; corrected stale counts (41→0 `UnimplementedError`
   stubs; 12→0 in executive summary); "Key Numbers" marked as snapshot + re-verified note.
3. **All 17 category files** — per finding: stale `lib/screens/...`→`lib/features/...` paths
   fixed, stale line numbers refreshed (or removed), stale counts corrected, ✅-DONE findings
   annotated with `**Status:** ✅ DONE (date, commit/agent)` matching the ERR-03 pattern, and
   open-but-scheduled findings annotated with `→ addressed by <agent-ID>` (per FILE-OWNERSHIP,
   without altering finding text).
4. **Daily log** — this file.

## Files modified (lock acquire/release evidence)

All locks via `tools/agent_lock.sh acquire <path> --owner D-03` (20/20 acquired, all released after):

| File | Lock | Key changes |
|------|------|-------------|
| `docs/to-fix/TODO.md` | ✅ | 4 status flips + orchestration header note |
| `docs/to-fix/README.md` | ✅ | header note + stale counts (41→0 stubs) |
| `docs/to-fix/categories/00-ARCHITECTURE.md` | ✅ | ARC-07 ✅ DONE; ARC-01 example files updated; ARC-05 936 lines; agent refs |
| `docs/to-fix/categories/01-STATE-MANAGEMENT.md` | ✅ | 12× status lines with verified file:line evidence + agent refs |
| `docs/to-fix/categories/02-NAVIGATION-ROUTING.md` | ✅ | NAV-01/NAV-02 ✅ DONE (commits ffbc8ae, RoutePaths); NAV-03..08 line refresh |
| `docs/to-fix/categories/03-ERROR-HANDLING.md` | ✅ | ERR-01/02/09 ✅ DONE; ERR-03 paths fixed; ERR-04 20 sites re-listed w/ lines |
| `docs/to-fix/categories/04-TESTING.md` | ✅ | TST-01 🔄 (opt-001 + runner exist); TST-02..10 evidence + refs |
| `docs/to-fix/categories/05-LOCALIZATION.md` | ✅ | L10N-04 `intl` verified unused; L10N-05/06 file:line evidence |
| `docs/to-fix/categories/06-SUPABASE-BACKEND.md` | ✅ | SUP-01/07/10 ✅ DONE; SUP-02/03 partial w/ real counts (1/31 FORCE RLS, 1/16 search_path) |
| `docs/to-fix/categories/07-UI-DESIGN.md` | ✅ | UI-02 count 3→2 Image.network sites; U-phase refs |
| `docs/to-fix/categories/08-SECURITY.md` | ✅ | SEC-01/02/15 ✅ DONE (commits b02090e/aa0ca5e/bb03e18); SEC-12 path fix; SEC-13/14 partial |
| `docs/to-fix/categories/09-CODE-GENERATION-TOOLING.md` | ✅ | all ❌ verified + M/U/I refs |
| `docs/to-fix/categories/10-PERFORMANCE.md` | ✅ | PERF-01 line refresh (8 lists verified); PERF-02 2 sites; PERF-05 debounce split |
| `docs/to-fix/categories/11-DEPENDENCY-MANAGEMENT.md` | ✅ | line numbers for each dep; mocktail nuance (pubspec_test only) |
| `docs/to-fix/categories/12-GO-BACKEND.md` | ✅ | GO-01/03/14 ✅ DONE; GO-04 6 sites verified; GO-05 🔄 (5/6 covered); GO-13 evidence |
| `docs/to-fix/categories/13-DOCKER-INFRASTRUCTURE.md` | ✅ | DKR-01/05/06/08 🔄; DKR-03 5432 conflict documented |
| `docs/to-fix/categories/14-MAKEFILE-CICD.md` | ✅ | MKE-06/09 🔄; MKE-02/05 line evidence; agent refs |
| `docs/to-fix/categories/15-LOGGING-OBSERVABILITY.md` | ✅ | LOG-01 ✅ DONE; LOG-02 count 38→8; LOG-04/06 partial; LOG-07 paths fixed |
| `docs/to-fix/categories/16-CODE-QUALITY.md` | ✅ | CQ-04/07 ✅ DONE; CQ-01 936 lines; CQ-09 path `backend/`→`internal/ops/` |
| `docs/history/phase-00-foundation/2026-08-09_D03-tofix-audit.md` | ✅ | this log |

## Verification (greps proving correctness)

1. `rg UnimplementedError lib/` → **0 hits** → C-02/M-41/L-01/ERR-01/CQ-04 ✅ (stubs really gone).
2. `rg "\.or\(" lib/` → **0 hits**; `rg "catch \(_\)" lib/ | wc -l` → **20** → C-04 ✅ done, ERR-04/H-05 still open at exactly the audited count.
3. `rg -n "users_insert_own|sl_insert_own|friendships_delete_own|group_members_update_promotor" supabase/migrations/*.sql` → all 4 policies present (20260511000001:5-6, 20260512000004:2, 20260512000009:4) → M-23 ✅.
4. `rg "replaceAll" lib/` → **0 hits**; `lib/core/extensions/error_mapper.dart` maps PostgrestException codes → M-24/M-35/SUP-10/SEC-15 ✅.
5. `rg -n "FORCE ROW LEVEL SECURITY" supabase/migrations/` → only `20260724000001:73` (signup_tracker) → SUP-02/SEC-13 partial, 1/31.
6. `rg -n "SET search_path" supabase/migrations/*.sql` → only `''` in check_signup_email; `handle_signup` still `= public` → SUP-03/SEC-14 partial, 1/16.
7. `rg -n "UnimplementedError" lib/` (0) + `wc -l supabase_service.dart` → 936 lines → ARC-05/CQ-01 counts corrected.
8. `rg -n "ListView\(\s*$" lib/features` → 8 sites → PERF-01/H-27 count confirmed, lines refreshed.
9. `rg -n "Image\.network|NetworkImage" lib/` → 2 sites (my_groups:121, group_detail:131) → UI-02/PERF-02 count 3→2.
10. `git ls-files | grep go.sum` → tracked → GO-14 ✅. `cmd/samay-admin/` exists + `make build-cli` artifacts `samay`/`samay-linux` present → GO-01 ✅.
11. `rg -c debugPrint lib/` = 8 (was 38) → LOG-02 count corrected. `rg "context\.(push|go)\(" lib/ | wc -l` = 33 (was "28+") → NAV-02/CQ-07 all RoutePaths-driven.
12. `rg "package:intl/" lib/` = 0 → L10N-04/DEP-06 still open. `rg -l mocktail test/` = only `pubspec_test.dart` → TST-02/DEP-05 nuance.

## Issues found (do NOT fix out of scope; reported)

- **Impossible to fully verify without a live DB**: C-06/TST-01's opt-001 harness and
  `supabase/tests/schema_test.sql` (plan 125, pgTAP) require the stack on ports 54382/54386 —
  the compose files still map `5432:5432`/`54321:8000` (Juega conflict per AGENTS.md port
  convention). The port remap is M-01..M-10's assignment; I did not start the stack.
- **`.env.example:5` still contains the real anon key** `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH`
  (SEC-03/H-21) — scheduled I-34; out of my scope to edit.
- **`test/structure_test.dart`** hardcodes 25 paths, 11 of which don't exist — it is one of the
  23 pre-existing failing tests (I-47/I-48's assignment); documented in TST-10.
- **Residual error-leak**: `error_mapper.dart:53` fallback `ServerError(toString())` still
  surfaces raw strings for unmapped errors (noted in ERR-09/SUP-10/SEC-15).
- **`supabase/docker-compose.yml` + `supabase-testing/docker-compose.yml`** conflict with Juega's
  ports (5432/54321) — flagged in DKR-03; M-01..M-10 must remap before any stack start.
- **Historical findings** (SUP-06, SUP-08, L-22, L-23) can only be "resolved" by squashing
  migration history — marked as historical/deferred rather than falsely ✅.
- Parallel agents D-02/D-04/D-06 were active on their own files during my run; no lock conflicts.

## Commands run (reproducibility)

```bash
export AGENT_NAME=D-03
for f in <20 target files>; do tools/agent_lock.sh acquire "$f" --owner "$AGENT_NAME" --timeout 600; done
# ... edits (see Files modified) ...
for f in <20 target files>; do tools/agent_lock.sh release "$f" --owner "$AGENT_NAME"; done

rg UnimplementedError lib/ ; rg "\.or\(" lib/ ; rg -c "catch \(_\)" lib/ | awk -F: '{s+=$2} END {print s}'
rg -n "users_insert_own|sl_insert_own|friendships_delete_own|group_members_update_promotor" supabase/migrations/*.sql
rg "replaceAll" lib/ ; rg -n "FORCE ROW LEVEL SECURITY" supabase/migrations/ ; rg -n "SET search_path" supabase/migrations/*.sql
rg -n "ListView\(\s*$" lib/features ; rg -n "Image\.network|NetworkImage" lib/ ; rg -c debugPrint lib/
rg "context\.(push|go)\(" lib/ | wc -l ; rg "package:intl/" lib/ ; rg -l mocktail test/ ; git ls-files | grep -E 'go\.(mod|sum)'
```
