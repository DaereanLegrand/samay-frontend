# 2026-08-12 — XL-17: data-screen declutter (Gemma round 2)

**Agent:** XL-17 | **Campaign:** LUXE v2 UI overhaul | **Branch:** `fixes`

## Evidence (Gemma 4, vision — round 2)

| Verdict | Hits | Direction |
|---|---|---|
| `luxe-screenshots/verdicts/12_profile.md` | "overall composition feels cluttered", "hierarchy overwhelmed by information density" (layout/hierarchy 5, luxury 3, minimalism 3) | tone the gold down, tighten rhythm |
| `luxe-screenshots/verdicts/16_shard_ledger.md` | "pathetic, cluttered mess", "low effort" (luxury 2, minimalism 2) | kill per-row glass + glow, one hairline per row |
| `luxe-screenshots/verdicts/10_events.md` | "overly saturated colors detract from luxury", "cheap; screams low-effort template" (gradients 3, ios-feel 2) | peach only on hero + CTA; neutral badges |
| `luxe-screenshots/verdicts/09_groups.md` | (raw text = no-image error; directive's own evidence) | violet at 1 accent per screen |

Positive controls held: 08_feed (7-8/10), 13_settings (minimalism 9),
17_cosmetics (minimalism 9), 15_coming_soon (9/9) — untouched.

## What was built

Per-screen changes (rendering only — routes, providers, flows, l10n, logic
byte-identical):

| File | Changes |
|---|---|
| `lib/core/design_tokens/app_gradients.dart` | NEW `AppGradients.wateredFamily(g, mix:)` — a full `AppGradient` re-stopped from `watered()` colors (keeps name/stops, so glass ring + glow halo + button face resolve it unchanged, just paler). Token-layer addition documented here per orchestration rules. |
| `lib/features/profile/screens/profile_screen.dart` | Balance card: `AppGradients.gold` → `wateredFamily(gold, mix: 0.4)`, glow 0.35 → 0.12 (directive: glowAlpha ≤ 0.15). Section gaps 32 → 24 (consistent 16/24 rhythm). Vivid gold survives only in the username `VDisplayText` shader + the shard diamond. |
| `lib/features/shards/screens/shard_ledger_screen.dart` | Balance header: watered gold, glow 0.22 → 0.10. **Per-entry `VGlassCard` removed** — rows are now plain hairline rows (ListView separator = `Divider` instead of a gap; kills the "divider + card + glow" repetition). Removed the duplicate xs `VShardIcon` beside every positive delta (the gradient delta is the accent). Row icons + positive deltas ride the watered run (was vivid `colors[1]` @0.85). |
| `lib/features/groups/screens/my_groups_screen.dart` | "Crear grupo" is now the screen's ONE violet accent (`VButton.glowAccent` filled violet); "Ranking" drops to neutral white outlined (was a second full-strength violet button → color spray). Group tiles: glass card + glow removed (hairline rows), `RankBadge` removed from tiles (rank belongs to the leaderboard), subtitle = role badge + shards only. Dropped unused `v_glass`/`rank_badge` imports. |
| `lib/features/groups/screens/group_detail_screen.dart` | Hero card: watered violet, glow 0.25 → 0.12 (hero glow + display voice keep the family). Members/contributor tiles: glass card removed → plain hairline rows. Donar CTA (glowAccent filled violet) untouched — the primary. |
| `lib/features/groups/screens/group_members_screen.dart` | Rows: glass card + glow removed → hairline rows (avatar + role badge + actions affordance kept). |
| `lib/features/groups/screens/leaderboard_screen.dart` | Podium (top-3) rows keep the glass hero moment on the **watered** violet ring (glow 0.22 → 0.12) + vivid `VDisplayText`; non-podium rows are plain rows. Tier chips: violet-accent `VChip.accent` → neutral white `VChip` (the 4-chip violet row was spray; the podium owns the accent). |
| `lib/features/events/screens/event_detail_screen.dart` | 3× `VBadge.accent` peach → plain neutral `VBadge` (glass fill + white text; status via label, never color). Info card, preshard-pool card and promotores card: peach `VGlassCard` → neutral white-only glass (no family border, no glow). Hero `VDisplayText` peach + Edit CTA (glowAccent peach) kept — the only two peach surfaces. |
| `lib/features/events/screens/event_edit_screen.dart` | Pool editor card: peach glass → neutral white-only glass; Save CTA keeps the peach glowAccent. |

Tests updated (visual pins only; behavior green):

| File | Pin change |
|---|---|
| `test/features/profile/restyle_test.dart` | Balance card `gradient == AppGradients.gold` → `gradient.colors == watered(gold, 0.4)`. |
| `test/features/groups/restyle_test.dart` | My-groups: VGlassCard 2→0, RankBadge 2→0, create=glowAccent filled / ranking=outlined-null-gradient. Detail hero + leaderboard podium glass → watered violet colors (VDisplayText vivid pins kept). Tier chips: accent→neutral (accent false, gradient null). Group-members: VGlassCard 2→0. |

## Decisions

- **`wateredFamily` at mix 0.4, not 0.35/0.5 arbitrarily:** 0.4 lands the
  vivid end (`#8B5CF6`-class) far enough toward white to read as "pastel
  chrome" while the border ring keeps a visible hue at α0.18 (VGlass) —
  uniform across all four families instead of per-screen tuning.
- **Rows are hairlines, not mini-cards:** the ledger's ~20 glass tiles each
  with a glow halo was the literal "pathetic, cluttered mess" — a surface
  per data row reads as decoration, not hierarchy. Glass is reserved for
  hero/id moments (balance header, group hero, podium) and forms.
- **The delta is the ledger row's only accent:** the xs shard diamond
  duplicated the gradient "+50" and the row icon — three golds in one row.
  One watered gold icon + one watered delta.
- **Events status stays in the label** (ESTA §1 / design-doc §2.5 rule 5:
  color is never the only signal) — the neutral badges lose the peach spray
  without losing the state.
- **Leaderboard chips neutral:** `VChip` white treatment mirrors the
  settings `SegmentedButton` that scored minimalism 9 — the filter row must
  not outshout the podium.

## MISTAKE (logged per AGENTS.md)

- None found in this pass. The only risk observed: `VChip.accent` with
  `gradient: null` still defaults to violet (v_chip.dart:45-47), so chips
  had to switch to the plain constructor — passing `gradient: null` would
  have silently kept the violet. Future neutral-chip callers: use the plain
  constructor, not `.accent`.

## Commands run (reproducibility)

```bash
# locks (all held until log written)
tools/agent_lock.sh acquire <file> --owner XL-17   # 11 files

export PATH="/opt/homebrew/share/flutter/bin:$PATH"
dart analyze lib/features/profile/ lib/features/shards/ lib/features/groups/ lib/features/events/ lib/core/design_tokens/app_gradients.dart
# → No issues found! (0)

flutter test test/features/profile/ test/features/shards/   # 68/68
flutter test test/features/groups/ test/features/events/    # 80/80
# → All tests passed (148 total; 0 behavioral regressions)

tools/agent_lock.sh release <file> --owner XL-17
```

## Sources

- Gemma verdicts: `luxe-screenshots/verdicts/{12_profile,16_shard_ledger,10_events,09_groups}.md` (round 2) and `{08_feed,13_settings,17_cosmetics,15_coming_soon}.md` (positive controls).
- Design language: `docs/history/phase-04-luxe/ORCHESTRATION-LUXE.md` (§"Gradient family → screen map", directives #2/#3/#8, glow discipline, component vocabulary).
- In-repo component contracts: `lib/core/design_tokens/app_gradients.dart` (watered/glowShadows/textShader), `lib/shared/widgets/glass/v_glass.dart` (VGlassCard: border α0.18 pastel, glow via glowShadows), `lib/shared/widgets/v_badge.dart` (accent fill = watered first stop), `lib/shared/widgets/v_chip.dart` (accent default = violet), `lib/shared/widgets/v_button.dart` (glowAccent halo α0.35).
- Precedent: `docs/history/phase-04-luxe/2026-08-12_XL-16-form-declutter.md` (round-1 "simple is luxury" pattern: one dominant accent surface per screen).
