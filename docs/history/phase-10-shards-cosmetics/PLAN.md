# Phase 10 — Shards Economy & Cosmetics · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-10-shards-cosmetics/*`
> and `docs/specs/steps/cross-references.md`. Read-only planning aid for I-49..I-78.

## Summary

Build the visible side of the shard economy: shard/preshard ledger screens, the
detailed shard-distribution logic (Edge Function, shares work with EEDG), the
cosmetics shop (shard-only purchases), and the democratic group-cosmetics voting
flow (51% approval / 24h window, paid from `group_shards`).

Key mechanics (from specs):
- `shard_ledger` / `preshard_ledger` are immutable, reason-enum-driven (9 shard
  reasons, 6 preshard reasons) with delta convention and reference links.
- Cosmetics: `cosmetics` (shard_cost always non-null, tier_requirement),
  `user_cosmetics` (UNIQUE user+cosmetic, one equipped per type — equipping a new
  one auto-unequips the old of same type). No cash purchases.
- Group cosmetics: only promotor/co_promotor may propose; any member votes, one
  vote per member; ≥51% approval within 24h; cost ≤ `groups.group_shards`; on
  approval deduct + record negative contribution + equip (unequip same type);
  inactivity = rejection. Vote resolution by cron `*/5 * * * *` OR on-vote check.
- Distribution math (SDIS): expected_pool snapshot, N=0 full return, per-user
  `min(floor(P/Y), cap)`, remainder redistribute/return, dust accepted, retries
  3× backoff, integrity abort → `admin_audit_log`, `preshards_distributed` guard.
- Economy firewalls: earned shards (donate/wager/cosmetics) vs preshards
  (event pools ONLY) — preshards never convert to personal_shards.
- Relevant `app_config` keys already seeded: `economy.*`, `events.collage_top_n_photos`.

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `SLED` | `DATA`✅, `SBAS`✅, `AUTH`⚠️ | 2/3 green | ✅ **I-64: landed** (ledger screens, service reads, route, l10n, tests) |
| `SDIS` | `ECRT`❌, `EEDG`❌, `DATA`✅ | 1/3 green | ❌ No code, blocked by `ECRT` + `EEDG` |
| `COSM` | `AUTH`⚠️, `DATA`✅, `DSNG`✅ | 2/3 green | ⚠️ Client landed (I-62); DB `purchase_cosmetic` RPC still required |
| `GCOS` | `GROU`⚠️, `COSM`❌, `DATA`✅ | 1/3 green | ❌ No code |

## Orchestration agents starting here

| Agent | Scope (per **docs/process/DEVELOPMENT-WORKFLOW.md** / FILE-OWNERSHIP.md) |
|-------|--------------------------------------------------|
| I-62 | `lib/features/cosmetics/cosmetics_shop_screen.dart` (foundation) |
| I-64 | `lib/features/shards/shard_ledger_screen.dart` — **landed** (see log `2026-08-09_I64-shard-ledger.md`) |
| I-49/I-50/I-51 | Feature flags / repositories / typed REST client |
| I-72 | Pagination utilities (ledger lists) |
| I-74 | Shared loading/error/empty state views |
| I-77 | pgTAP expansion (ledger/cosmetics invariants) |
| I-78 | Full-matrix sweep |

`SDIS`'s Edge Function is part of `EEDG` (Phase 05) — implementation lands there;
this phase's SDIS scope is verification + CLI/RPC wiring (partially present:
`distribute_shards` RPC + `samay events distribute-shards`).

## Acceptance checklist (from the step specs)

**SLED (`SLED-shard-preshard-ledgers.md`):**
- [x] Shard ledger screen: header balances (personal + preshards), reverse-chron list, reason icon + description + delta (+ green / − gray strikethrough) + timestamp + tappable reference (event/group/cosmetic) — **I-64: landed** (`shard_ledger_screen.dart`, `LedgerEntry` model, `ShardsService.getShardLedger/getPreshardLedger`, `shardLedgerProvider` w/ derived totals, `/shards/ledger` route LIVE + profile balance-card link, 21 ARB keys ×2, 31 new tests; reference links display-only short-id for now — see I-64 log)
- [x] All 9 reason display mappings per the spec table — **I-64** (`shardReasonLabel` + icon map, es/en, unknown-reason fallback)
- [x] Preshard ledger screen with its 6 reason mappings — **I-64** (second tab + `preshardReasonLabel`)
- [x] Economy summary bar on profile: "Ganados" vs "Comprados/Bonos" + the "no expiran / solo eventos" note — **I-64** (ledger balance header; profile balance card links into it)

**SDIS (`SDIS-shard-distribution-logic.md`):**
- [ ] Edge Function logic (implemented under EEDG): pre-execution reads + `already_distributed` short-circuit + expected_pool snapshot + pool=0 early exit
- [ ] Attendee calculation: Y invitees, N attendees, N=0 full return, per-user math w/ cap, distributed_total ≤ P, unused
- [ ] Remainder: redistribute (extra_each = floor(unused/N), dust lost) vs return (proportional)
- [ ] Promotor returns (share_ratio × pool_to_return, floor), attendee crediting (users + event_attendances + shard_ledger), promotor consumption (`event_pool_consumed`), cleanup (pool=0, distributed=true)
- [ ] Retry 3× (1s/2s/4s), pool-integrity abort w/ `admin_audit_log` (system admin ID), exhausted → `distribute-shards` CLI fallback

**COSM (`COSM-cosmetics-shop.md`):**
- [x] Shop: tabs Marcos/Fondos/Insignias, grid of preview + name + shard cost; tier-locked items grayed w/ "Requiere {tier}"; owned → "Adquirido" + "Equipar"; affordable → "Comprar — {cost} ✦" — **I-62: landed** (`cosmetics_shop_screen.dart`, catalog/provider stack, `/cosmetics` route, profile section navigation; flag `cosmeticsSection` dark until the DB RPC below lands)
- [x] Detail view per item; purchase flow: confirm dialog → balance check + tier check → deduct `personal_shards` + `shard_ledger` (cosmetic_purchase) + `user_cosmetics` (equipped=false) → success animation — **I-62: client side complete (typed insufficient/tier errors + friendly messages); ⚠ DB-side blocker:** `shard_ledger` has no INSERT policy (only `sl_read_own`) + FORCE RLS → direct inserts fail 42501, and `users.personal_shards` has no client-side deduction path (protected-columns trigger). A SECURITY DEFINER `purchase_cosmetic` RPC (mirror `donate_shards_to_group`) is REQUIRED before the flag flips — handoff to I-77/S-03 (see I-62 daily log)
- [x] "Mis Cosméticos": grid, "Equipado" badge, toggle (one per type, auto-unequip same type) — **I-62: shipped inside the shop grid** (`setCosmeticEquipped`)
- [ ] `PRFL` renders equipped cosmetics (avatar frame, profile bg, badge) — display on the profile header is NOT in the I-62 scope (I-36 placeholder row now navigates to the shop)

**GCOS (`GCOS-group-cosmetics-voting.md`):**
- [ ] Propose vote (promotor/co_promotor): preview + cost + "El grupo tiene {X} shards disponibles", confirmation text per spec; creates in-app notification + system message in group chat
- [ ] Voting UI: group detail "Votaciones" tab, countdown, Aprobar/Rechazar, "{X} de {Y} miembros han votado"
- [ ] Resolution: ≥51% → deduct from `group_shards` + negative contribution row + `group_cosmetics` (equipped=true, unequip same type) + notify; rejected → no deduction + notify w/ percent; insufficient votes/expiry → reject, notify
- [ ] Expiry mechanism (cron `*/5 * * * *` or on-vote resolution check)
- [ ] Restrictions: only promotor/co_promotor initiate; any member votes once; cost ≤ `group_shards`

## Phase exit gate

All 4 steps green in cross-references.md; ledger/cosmetics screens live; purchase
and voting flows end-to-end tested (opt-test + pgTAP); no shard double-spend in
distribution (race test); full matrix green.
