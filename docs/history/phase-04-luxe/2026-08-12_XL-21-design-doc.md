# 2026-08-12 — XL-21: LUXE v2 design documentation (DISCO-LUXE + Gemma rounds + orchestration)

**Agent:** XL-21 | **Campaign:** LUXE v2 UI overhaul | **Branch:** `fixes`
**Role:** design-doc author — docs only, zero code/test changes.

## What was built

| File | Action |
|---|---|
| `docs/design/DISCO-LUXE-DESIGN-SYSTEM.md` | NEW — the LUXE v2 specification (§1 pillars L1–L11, §2 gradient system with exact hexes/stops + family map + glowShadows/watered/aurora rules, §3 typography incl. the 2026-08-12 no-halo MAYUS directive, §4 components, §5 motion table + reduced-motion contract, §6 decluttered-screen rules, §7 Gemma QA loop, §8 implementation-status table + extension rules, §9 sources, §10 changelog). APPENDS to the v1.1 doc — v1.1 stays the read-only authority where LUXE doesn't override. |
| `docs/history/phase-04-luxe/GEMMA-ROUNDS.md` | NEW — the three critique rounds: round 1 (XL-16, reconstructed from logs), round 2 (XL-17, evidence table from the log), round 3 (XL-18+XL-19 fixes + the final verdicts generation = on-disk `luxe-screenshots/verdicts/SUMMARY.md` copied verbatim), the round-to-round movement table, and the final state. |
| `docs/history/phase-04-luxe/ORCHESTRATION-LUXE.md` | Updated — roster XL-16..XL-21 → DONE with test counts (93/93 · 148/148 · 200/200+61/61 · 132/132 · XL-20 suite consolidation · XL-21 docs); added Checkpoint 2 (full suite 2151/2151, analyze 0) and Checkpoint 3 (final screenshots + Gemma round-3 summary OTP 10/10, login 8/8/7/8, signup 7/7/6/7, profile minimalism 9; no pink flags). |

## Decisions

- **The on-disk `luxe-screenshots/verdicts/SUMMARY.md` is the FINAL (round-3) generation.** Evidence:
  its 04_otp 9/10/10/10/8/10/–/10, 02_login 8/8/7/8, 03_signup 7/7/6/7 and 12_profile minimalism 9
  exactly match Checkpoint 3's round-3 summary, while the round-1/round-2 numbers quoted in the
  XL-16/XL-17 logs differ (02_login hierarchy 5 vs 8; 12_profile minimalism 3 vs 9). Rounds 1–2
  tables are therefore reconstructed from log citations and flagged as such.
- **XL-19's evidence set** ("round-2 survivors": 01_welcome minimalism 4, 03_signup luxury 3/
  minimalism 2, 05_age_gate luxury 2, 06_privacy_terms luxury 3, 10_events luxury 2, 14_chat
  trivial) sits between rounds 2 and 3 in the ledger — it is its own §3 section rather than being
  forced into either round.
- **Roster honesty:** XL-20 has no daily log on disk (suite was consolidated — 2154 → 2151); I
  marked it DONE per the orchestrator's instruction with the suite number as its evidence, and did
  NOT fabricate a log or per-agent test count for it. XL-22/XL-23 stay planned.
- **`tabFade` is not a literal token** (VTabFade consumes `fast` 150ms) — documented with a
  DEPARTURE note instead of inventing a token row.
- **Rose kept in the palette doc table** (it is a canonical family in `AppGradients.all`) but every
  usage rule pins the L3 micro-accent-only status, mirroring the code's `familyOf` default → violet.

## Doc-vs-code discrepancies noticed (reported, NOT fixed — docs follow the CODE)

1. **XL-04 log vs code:** the XL-04 log says `VAurora` default = `[cyan, violet, rose]`; the code
   ships `[cyan, violet, mint]` (rose removed under the NO-PINK directive). Log is stale; doc + code
   agree.
2. **XL-03 log vs code:** the XL-03 log describes `VDisplayText` with a slow pulsing halo
   (glowShadows breath + `soft` param); the shipped widget has **no halo** (deleted 2026-08-12 user
   directive — "glowing pulsation outside letters must be deleted"). Stale log.
3. **ORCHESTRATION protocol vs tool:** the campaign spec's endpoint contract says `max_tokens: 1024`;
   `tools/gemma_critique.sh` actually sends 2048. Cosmetic; spec should be updated to match the tool.
4. **`glassHover` (150ms) vs `VInput.shellDuration` (200ms):** the token exists but `VInput` uses its
   own 200ms const (pre-dates the token). No consumer of `glassHover` found in features. Flagged in
   the LUXE doc §5.1 as a future folding pass.
5. **`v_input.dart` comment** says "Feature agents theme the border per-screen gradient later — this
   stays neutral white"; the OTP screen (XL-18) did exactly that locally (gold family slab) without
   touching `VInput` — consistent, but the comment predates the OTP work.
6. **On-disk verdicts `09_groups`/`18_cosmetics`** are no-image backend errors and `05_age_gate`/
   `07_profile_setup` are verdict-only files (score extraction failed) — GEMMA-ROUNDS.md flags them
   as re-run candidates, matching the XL-17/XL-18 logs' evidence.
7. **ORCHESTRATION roster roles:** XL-16/17/18/19 role text was rewritten to match the actual log
   scopes (round 1 = auth form declutter, round 2 = data declutter, round 3 = chat/rest, XL-19 =
   round-2 survivors) — the old text ("auth+shell+feed", "profile+friends+groups", "round 4") didn't
   match the logs.

## Commands run (reproducibility)

```bash
tools/agent_lock.sh acquire docs/design/DISCO-LUXE-DESIGN-SYSTEM.md --owner XL-21
tools/agent_lock.sh acquire docs/history/phase-04-luxe/ORCHESTRATION-LUXE.md --owner XL-21
tools/agent_lock.sh acquire docs/history/phase-04-luxe/GEMMA-ROUNDS.md --owner XL-21
tools/agent_lock.sh acquire docs/history/phase-04-luxe/2026-08-12_XL-21-design-doc.md --owner XL-21
# … read foundation code (app_gradients, app_colors, glass/, v_display_text, v_aurora,
#   v_glow_pulse, v_thinking_dots, v_input, v_button, v_badge, v_chip, v_count_badge,
#   app_theme, samay_durations, main_shell), all XL-01..XL-19 logs, verdicts + SUMMARY,
#   gemma_critique*.sh, gemma_critique_prompt.md …
# … wrote the 3 docs + this log …
tools/agent_lock.sh release <each file> --owner XL-21
```

No `dart analyze`/`flutter test` needed (docs only). No commits (orchestrator-only).

## Validation gate

- [x] Doc specs verified against the code file-by-file (hexes, stops, alphas, durations, defaults)
- [x] Verdict SUMMARY copied verbatim for the final generation; round 1/2 reconstructed + provenance-noted
- [x] ORCHESTRATION roster + checkpoints updated per instruction
- [x] No code or test files touched
- [x] Locks acquired; release pending after log write
