# Phase 11 — Gamification & Mini-Games · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-11-gamification-minigames/*`
> and `docs/specs/steps/cross-references.md`. Read-only planning aid for I-49..I-78.

## Summary

Implement the daily group-rank recalculation (Edge Function, cron-driven at
`ranks.update_cron` = `59 23 * * *`) and the five group-scoped mini-games
(Poke Chain, Questions, Truth or Dare, Drunk Bottle, Challenges) with the optional
shard wager system. All games sync via Realtime on `minigame_sessions`.

Key mechanics (from specs):
- **GRCK (4 steps + notifications):** decay expired boosts (recompute
  `groups.group_shards` = sum of non-expired contributions), calculate percentile
  brackets per size tier from `ranks.bracket_thresholds` (`0,20,40,60,80,90,100`),
  update `groups.rank_bracket` (track changed), insert `group_rank_snapshots`
  (rank_position 1-indexed, member_count, score; purge > 30 days), notify members
  of bracket changes. This powers the currently-empty leaderboard (RANK ✅ UI).
- **GMCR:** game list in group detail; session creation (game type, optional
  wager via GWAG, participant selection incl. "Seleccionar todos"); each game's
  rules + timeouts from `app_config` (`minigame.poke_timeout_minutes` 5,
  `minigame.challenge_timeout_minutes` 60); Realtime state sync (turns, timers,
  votes).
- **GWAG:** propose → each participant accepts/declines/"play without wager";
  ANY decline → wager = 0. On accept-all: check balances, deduct immediately
  (`shard_ledger` minigame_wager), escrow = amount × participants. Resolution:
  single winner gets escrow (`minigame_win`); draw/group game → refund everyone
  (`minigame_refund`). Verifiability: sum of wager entries = pot = payout.
- Tables (`minigame_sessions`, ledgers) already exist in schema (DATA ✅).

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `GRCK` | `DATA`✅, `INFR`✅, `CRON`✅ | 3/3 green | ✅ **Delivered as SQL (2026-08-13, e0eab3c)** — `recalculate_ranks` RPC (boost decay, bracket-change notifications, `search_path=''`) + daily `ranks-recalculate` cron scheduled by `20260814000003_rank_recalc_decay_cron.sql` honoring the `ranks.update_cron` app_config key (seed default `59 23 * * *`); RANK leaderboard data now flows |
| `GMCR` | `GROU`⚠️, `AUTH`⚠️, `DATA`✅, `DSNG`✅ | 2/4 green | ❌ No code |
| `GWAG` | `GMCR`❌, `DATA`✅, `SDIS`❌ | 1/3 green | ❌ No code |

## Orchestration agents starting here

| Agent | Scope (per **docs/process/DEVELOPMENT-WORKFLOW.md** / FILE-OWNERSHIP.md) |
|-------|--------------------------------------------------|
| I-63 | `lib/features/minigames/minigames_screen.dart` (foundation) ✅ **COMPLETE (2026-08-09)** — see `2026-08-09_I63-minigames.md`: `create_minigame_session` SECURITY DEFINER RPC (migration 20260809000006 + mirror, pgTAP §45 plan 262), `MinigameService` (list/get/create→RPC/join/updateStatus/subscribeToSession), `minigameSessionsProvider` + `sessionStatusProvider`, hub screen (5 game cards + wager create + session list with status chips), route `/minigames/:groupId` flag-gated (`minigames`, dark), 30 ARB keys ×2, 54 unit/widget + router tests + hermetic `integration_test/minigames_flow_test.dart` (runner.sh). Full suite 1396/0. |
| I-52 | Realtime lifecycle (all game state sync) ✅ (provider standard — `sessionStatusProvider` rides `realtimeChannelProvider`) |
| I-49/I-50/I-51 | Feature flags / repositories / typed REST client ✅ (flags gate the route; service uses `RestClient`-era conventions) |
| I-74 | Shared state widgets (game loading/error states) ✅ (hub uses `ErrorView`) |
| I-77 | pgTAP expansion (minigame_sessions, group_rank_snapshots invariants) ⚙️ **HANDOFF:** winner-settlement + join RPCs (finish/join_minigame_session — GWAG §Wager Resolution) + `supabase_realtime` publication for `minigame_sessions` |
| I-78 | Full-matrix sweep |
| U-11 | "Juegos" entry point in group detail (GMCR game-list-in-group-detail follow-up) |

No dedicated I-agent for the `recalculate-ranks` Edge Function in the 4.2 list —
the CLI RPC (`samay shards recalculate-ranks` → `recalculate_ranks`) exists for
manual runs; flag to the orchestrator if an EEDG-style agent must own the Edge
Function.

## Acceptance checklist (from the step specs)

**GRCK (`GRCK-rank-calculation-edge-function.md`):**
- [ ] Edge Function `recalculate-ranks` triggered by `ranks.update_cron`
- [ ] Step 1 decay: per group recompute `group_shards` from non-expired contributions
- [ ] Step 2 brackets: per size tier, ordered by shards DESC, percentile mapping to b0_20…b90_100 per spec labels
- [ ] Step 3 update `rank_bracket`, track changed groups
- [ ] Step 4 snapshots (position/score/member_count) + purge > 30 days
- [ ] Step 5 notifications to members of changed groups
- [ ] `ranks.update_cron` scheduled (SQL cron)

**GMCR (`GMCR-minigames-core.md`):**
- [x] "Juegos" hub screen: 5 game cards (name, description, icon, "Jugar"→create) ✅ I-63 (route `/minigames/:groupId`, flag-gated)
- [x] Session creation foundation: game type + optional wager (→ GWAG) + `minigame_sessions` insert (active) via `create_minigame_session` RPC ✅ I-63
- [ ] "Juegos" tab/entry inside group detail (U-11 follow-up)
- [ ] Participant selection w/ "Seleccionar todos" + per-participant accept (join RPC — I-77/S-03 handoff)
- [ ] Poke Chain: countdown from config, must-poke-before-timeout, holder loses on timeout, chain continues; winner = last successful pass
- [ ] Questions: hot-seat random, group submits questions, vote 👍/👎
- [ ] Truth or Dare: random turn, Verdad/Reto, pool questions/challenges, group vote "Completado"/"No completado"
- [ ] Drunk Bottle: animated spin → random member, social-only, no wager
- [ ] Challenges: text challenge → target confirms within timeout (photo/text), group votes, wager resolution
- [ ] Realtime sync of session state (turn, remaining time, votes) — provider seam ready (`sessionStatusProvider`); `supabase_realtime` publication for `minigame_sessions` pending (I-77/S-11)

**GWAG (`GWAG-wager-system.md`):**
- [x] Escrow entry contract: `create_minigame_session` RPC deducts immediately + `minigame_wager` ledger entry (reference_id = session) — escrow verifiable by summing ledger rows ✅ I-63
- [ ] Proposal flow: amount ≥ 1, "Apuesta: {amount} shards por persona. Total en juego: {amount × N}", notifications
- [ ] Acceptance: any decline → wager 0; all accept → balance check + immediate deduction + `minigame_wager` entries; escrow = amount × participants; game starts
- [ ] Resolution: winner → `minigame_win` + escrow credit; draw → `minigame_refund` for all (**finish_minigame_session RPC — I-77/S-03 handoff**)
- [ ] Edge cases: disconnect mid-game (wager stands), insufficient balance impossible post-deduction, admin intervention via `SHRD`

## Phase exit gate

All 3 steps green in cross-references.md; leaderboard populated by real GRCK data;
games playable end-to-end with and without wagers; ledger math verified
(escrow in = payout out); full matrix green.
