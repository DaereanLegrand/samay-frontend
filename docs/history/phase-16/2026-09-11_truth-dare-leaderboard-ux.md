# Truth or Dare — reaction auto-advance fix + finished-leaderboard UX pass

**Branch:** `truth-or-dare-leaderboard` · **Date:** 2026-09-11

## What was built

### 1. "Last to react" bogus error (all devices)
`submit_minigame_reaction` records the caller's vote AND, when it is the last
required reaction, closes the round by delegating to `_minigame_advance_round`
→ the RPC returns `status:"advanced"` (or `finished`/`already_finished` at the
round target). The Dart client's `submitReaction` switch only accepted
`submitted`/`too_fast`, so the LAST reactor threw
`ServerError('Unexpected submit_minigame_reaction response')` — surfaced as a
snackbar, never logged. The write had already succeeded, so every device still
advanced. Fix: accept `advanced`/`finished`/`already_finished` as success on
`submitReaction`, `submitPasar`, and `submitAsyncAnswer` (all three delegate to
the same auto-advance/finish path), and map the remaining gate statuses
(`own_round`, `answer_pending`).

### 2. Finished leaderboard — load state, centering, header, card layout
- **Answers loading is now a spinner, not an error.** The old card used
  `minigamePlayerContentProvider.valueOrNull`, so while decrypted answers were
  resolving it rendered `minigamesPromptLoadError` ("ERROR AL CARGAR LA
  PREGUNTA"). Now the provider is wrapped in `withTimeout`
  (`AppConstants.leaderboardAnswersTimeout`, 5 s per user directive); a card
  shows a centered spinner while loading, and only on failure/timeout a
  discreet retry: "Oops, we couldn't load the match answers. Try again later."
  (`minigamesAnswersLoadError`) with a refresh affordance. A player with a
  genuinely empty answer set shows `minigamesNoAnswers`.
- **Full-viewport vertical centering.** The finished branch in
  `TruthDareScreen.build` now renders full-bleed (the carousel centers on the
  WHOLE viewport) with the title as a floating `VHeaderTitleRow` overlay,
  mirroring the attendance QR screen. Previously it centered only in the area
  below the 80 px `VHeaderBar`.
- **Header X hidden on the leaderboard.** The match is already settled, so the
  creator's "Terminar juego" action is pointless there — only the back arrow
  remains.
- **Card header.** The rank numeral is a fixed-width, right-aligned Playfair
  glyph fitted to the two-row identity block, so every card's username starts
  on the same x (a real grid). The secondary line is now
  `{score} puntos · ◆ {n} shards` (`minigamesPointsAmount`), always showing the
  shard segment.
- **Tighter spacing + bigger image.** The answer + reaction tally sit as one
  tight group directly under the question; a challenge image is a large 4:3
  `BoxFit.cover` block with the tally flush beneath it (no letterbox void, no
  detached tally at the card floor). Short text/passed cards hug their content
  instead of reserving a dead band.
- **Vertical page affordance.** Multi-answer cards page vertically with a slim
  vertical rail overlaid on the trailing edge (axis-correct HIG affordance),
  and a small trailing gutter so lines never run under it.

### 3. Refactor
The 2 800-line screen was split: shared reaction primitives
(`ReactionEmoji`, `RiseSpec`, `RisingReactionParticle`) moved to
`widgets/reaction_rise.dart`, and the whole leaderboard (provider wrapper
`FinishedLeaderboard` + pure, data-driven `LeaderboardCarousel`) moved to
`widgets/finished_leaderboard.dart`. `truth_dare_screen.dart` shrank by ~810
lines.

## Decisions
- **Provider-level 5 s timeout** (user directive) so the screen never hangs on
  a stuck image download; the retry re-invalidates the provider.
- **Client-only status fix** — no server migration. The `advanced` contract is
  already pinned by `test/opt-020` TEST D and `test/opt-023` TEST D.
- **Full-bleed overlay header** for the finished state (QR parity) rather than
  reserving a header band.
- **`AppConstants`** introduced for the non-visual timeout knob (visual tokens
  stay in `design_tokens`, motion in `SamayDurations`).

## Mistakes / gotchas
- **MISTAKE — the last reactor's error was invisible.** The exception was only
  shown via `SnackBar`; there was no `AppLogger` call, so device logs looked
  clean while users saw an error. Worth auditing other fire-and-forget
  snackbar-only catches.
- **MISTAKE — a fixed carousel height re-introduces dead space.** Several
  iterations tried to size the card by a fraction of the viewport, which always
  left a void for short content. The working model is: one bounded viewport,
  each card hugs its content (`mainAxisSize.min`), the image's 4:3 box drives a
  taller card, and the multi-answer vertical pager gets an explicitly bounded
  height.
- **Judge loop finding — the reaction tally was detached at the card floor.**
  Pinning reactions with a trailing `...[]` outside `Expanded` put them at the
  very bottom while the answer floated mid-card. Bonding the tally to the
  answer fixed both the void and the disconnect.

## Commands run
```bash
flutter gen-l10n
dart analyze lib                     # clean
# screenshot harness (temporary, removed after): flutter run -d <sim> -t lib/main_leaderboard_preview.dart
# 5 rounds of UI/UX judge agents on the captured PNGs (final: 8/10 + 7/10, both shippable)
```

## Files
- `lib/core/services/minigame_service.dart` (status handling)
- `lib/features/minigames/providers/minigames_providers.dart` (timeout)
- `lib/core/config/app_constants.dart` (new)
- `lib/features/minigames/widgets/reaction_rise.dart` (new — extracted)
- `lib/features/minigames/widgets/finished_leaderboard.dart` (new — extracted + redesigned)
- `lib/features/minigames/screens/truth_dare_screen.dart` (full-bleed finished branch, old leaderboard removed)
- `lib/l10n/app_en.arb`, `app_es.arb` (+ generated localizations)
- `.gitignore` (`screenshots/`)
- screenshots under `screenshots/truth-dare/` (gitignored, for human evaluation)
