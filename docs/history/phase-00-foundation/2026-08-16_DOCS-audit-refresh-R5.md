# Docs ↔ Code Audit Refresh R-5 (2026-08-16)

**Agent:** UIUX-docs-audit (human-run audit session) · **Branch:** `fixes` · **HEAD:** `c8bba7e` + uncommitted UI/UX pass

## What was built

Docs updated/audited after the ISSUE-4 group-chat workstream (commits `1336679`,
`9d7c93d`, `7ca2b8c`, `ffdad74`, `f60f617`, `c8bba7e`) and the uncommitted UI/UX
pass (pastel re-saturation + Makefile simulator picker — see the companion log
`2026-08-16_UIUX-pastels-makefile.md`).

### 1. Design docs

- `docs/design/DISCO-LUXE-DESIGN-SYSTEM.md`:
  - §2.1 gradient-stop table + pastel-token table re-stopped/re-ratioed to the new
    hexes (9.75 / 9.98 / 15.75 / 16.51 / 15.66 / 14.60 — all still AAA vs black).
  - §2.4 watering table: "chat bubbles 0.45" removed → note that chat bubbles are
    solid-white/glass since 2026-08-15 (no watered family fill).
  - §4.1 glow-discipline table: "group hero 0.12" dropped — the group-detail hero
    banner was deleted (G4/USER FIX 4, 2026-08-16).
  - §10 changelog: 2026-08-16 row.
- `docs/design/DISCO-DESIGN-SYSTEM.md` §4.2: chat bubbles exempted from the
  radius-0 rule; full bubble contract documented as a DEPARTURE note (radius 8,
  padding 10/8, 320px cap + shrink-wrap, solid-white own / white-glass peer,
  pastel sender names in group threads, hour bottom-right + ticks right of hour,
  date separator chips).
- Historical XL logs updated in place (user decision): `XL-09` (pastelMint hex +
  ratio), `XL-10` (violet family light end), `XL-11` (peach family light end).

### 2. Baseline numbers (current truth, re-verified live)

| Suite | Docs said | Now |
|---|---|---|
| `flutter test` | 2209/2209 | **2440/2440** |
| `go test ./...` | 182 | 182 (unchanged) |
| pgTAP | 385 | **494** (plan 494, 46/46 migrations, both stacks) |
| opt-tests | 001..008 / 8-8 | **001..011** (009 groups-chain, 010 groups-chat, 011 groups-reads) |
| integration flows | 18 registered | **19 registered** (group_chat_flow_test.dart, #12 after chat) |
| test/crypto | 179 (group_cipher 39) | **182 (group_cipher 42)** — key-request retry +3 |

Refreshed in: DEVELOPMENT-WORKFLOW (§1.6, §3.2 flows, §3.3 opt list, §3.5 plan
history, §3.6 table, §8 cheatsheet), README (tree + testing summary), test/README
(opt list + flows + pgTAP row), PHASE-INVENTORY (R-5 note + DATA row + phase-01),
SELFHOSTING (pgTAP 494 ×4 + row 26), DEPLOYMENT-PLACEHOLDER (ci.yml block),
SECURITY.md (pgTAP line + footer), cross-references (parity row, schema_test row,
23-failures row, I-01 row, I-37 count chain), E2EE-ARCHITECTURE (§0 count + §0.3
breakdown + re-run date), FILE-OWNERSHIP (appendix count chain), integration_test/
README (flow table row 12 + numbering).

### 3. Suite fix

- Stray gitignored `lib/features/chat/widgets/.dart_tool/` (created 2026-08-16
  18:54 during the group-chat work window) broke `test/meta/conventions_test.dart`
  — the port-map guard reads every file under `lib/` as UTF-8 and choked on the
  binary `objective_c.dylib`. Removed; `find` verified no other strays.
  `flutter test` → **2440/2440**.
- `test/opt-011-groups-reads.sh` count queries fixed (3 checks): the three
  `message_reads` counts (exactly-1-receipt, idempotency, self-stamp denial)
  queried the WHOLE table — on a reused stack, stale receipts from earlier runs
  (the trap cleanup only deletes the run's own rows) inflated the count (94) and
  failed the checks. The queries now filter
  `message_id=in.($MSG_G1,$MSG_G2,$MSG_DIST,$MSG_D1)` like the cleanup does.
  Green 15/15 at write time (issue3 log) and 15/15 again after the fix on the
  dirty stack.

## Decisions

- Historical records kept intact: the R-4 note in PHASE-INVENTORY, the "as of
  2026-08-13" clauses in SELFHOSTING row 26 / cross-references, GATE-REPORT and
  the 2026-08-13 audit doc keep their dated numbers; new facts appended as
  supersede/refresh notes (same policy as the 2026-08-13 audit).
- Design-doc authorship: the chat-bubble spec lives in DISCO-DESIGN-SYSTEM v1.1
  §4.2 (user decision — no new LUXE section); the LUXE doc only gained the
  cross-reference note.
- The I-37 count chain in cross-references/FILE-OWNERSHIP continues the existing
  supersede-chain style (…K1: 179/39 → key-request retry +3 → 182/42).
- Changes stay uncommitted (user decision).

## MISTAKE

- First edit of the integration_test/README flow table appended the group-chat
  row at position 19 — the runner's ORDERED_FLOWS has it at **12** (after chat,
  before QR). Caught by cross-checking the array; table renumbered correctly.
- `agent_lock.sh run` silently failed to execute its command (see the companion
  log) — the README "18 registered flows" line was fixed via the edit tool and
  verified by re-grep instead.

## Commands (reproducibility)

```bash
flutter test                                   # 2440/2440
dart analyze                                   # 0 issues
go test ./...                                  # 182 pass
rg -c '^  test\(' test/crypto/*.dart           # 182 (group_cipher 42)
ls supabase/migrations/*.sql | wc -l           # 46
rg -n 'SELECT plan' supabase(+testing)/tests/schema_test.sql   # 494 both
bash integration_test/runner.sh                # hermetic, 19 flows
bash test/run_all_backend.sh                   # 11/11 (stack up, Kong 54386)
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -f supabase/tests/schema_test.sql  # 494 ok / 0 not ok
tools/check_ports.sh --strict                  # STRICT PASS
```

Locks (tools/agent_lock.sh): every edited path acquired + released under
`--owner UIUX-docs-audit`; the two new daily logs creator-owned; zero locks held
at close.

## Follow-ups

- `docs/to-fix/TODO.md` category statuses for the ISSUE-4 chat/group items were
  not re-verified in this pass (V-02 domain) — a read of the CHAT/07-UI-DESIGN
  categories found no open items closed by the workstream, so statuses were left
  untouched.
- `gum` is now a Makefile dependency for the multi-simulator picker — consider
  adding it to the docs/process prerequisites list if a README/onboarding pass
  ever enumerates dev tooling.
