# 2026-11-19 — Games deck restored as the root selector

## What was built

`slim-prod`'s root is the vertical finger-tracked deck again (`GamesDeck`), with
the `samay` wordmark as the only header title. The plain `ListView` of game rows
is gone.

- `lib/features/minigames/logic/match_preview.dart` — restored (`MatchPlayer`,
  `MatchPreview`).
- `lib/features/minigames/providers/minigames_providers.dart` — restored
  `kDeckMatchesPerGame`, `matchRosterProvider` and `gameTabMatchesProvider`
  (plus its `_createdAtOf` helper) immediately after
  `myMinigameSessionsProvider`; re-added the `match_preview.dart` and
  `minigame_meta.dart` imports.
- `lib/features/minigames/widgets/games_deck.dart` — restored the vertical
  two-phase drag deck: the hero follows the finger vertically with its
  horizontal offset locked to a quadratic Bézier arc, the rest of the deck
  catches up past the halfway point, and the release velocity drives an
  unbounded `SpringSimulation` settle (a hard throw projects through several
  cards). Reduced motion snaps.
- `lib/features/minigames/widgets/game_name_band.dart` — restored: each card
  carries two circulating `icon + lowercase name` bands (top forward, bottom
  reverse), `VDisplayText` size 18, constant 28 px/s, frozen under reduced
  motion.
- `lib/features/minigames/widgets/match_bubble_field.dart` — restored: one mega
  bubble per recent match (newest first, cap 5), each nesting up to six randomly
  sized avatar bubbles plus a `+N` overflow, packed deterministically and
  collision-free around the centred play glyph and the two band zones.
- `lib/features/minigames/screens/games_home_screen.dart` — rewritten around
  the deck: `Stack` of deck (reserved header band) + background scrim gradient +
  the header painted last, so a card overflowing upward passes behind the title.
  Header is `VHeaderBar(title: l10n.welcomeSamay, showBack: false, actions:
  [_GamesMenuButton()])`. The `_GamesMenuButton` / `_GamesMenuSheet` are
  unchanged; `_GameRow` and its imports are dropped.

The three widgets come from `5f7de05^`, i.e. **after** the app-wide theme
migration (`7648c60`), so they were already palette-driven (`context.palette`)
— no colour work was needed. They read `background`, `surfaceAlt`,
`foreground` and `mutedForeground`, so all seven app presets and group themes
repaint the deck.

Adaptations for the slim tree:

- `MainShell.navBarInset(context)` no longer exists (the nav shell is gone), so
  the deck's bottom padding is `pageBottomInset(context)` (OS home-indicator
  inset + one step).
- The header menu moved into the overlaid `VHeaderBar`'s `actions`, since the
  deck owns the whole screen.

## Decisions made and why

- **Restore rather than re-invent.** The deck, bands and bubble field were
  deleted wholesale in `5f7de05` along with the nav shell. Restoring the
  post-theme versions keeps the docs (`DESIGN.md` §3, the phase-16 logs) and the
  visual contract accurate, and keeps this change to three files plus one.
- **`samay` as the header wordmark** (owner directive): the deck replaces the
  game *list*, so the screen no longer needs to name "juegos"; the brand word
  sits where every other root header puts its title. `welcomeSamay` already
  holds `"samay"` in both locales.
- **Bubbles kept.** Main shipped them; they are the only surface that shows
  recent partidas on the root. Cost is bounded: at most 5 sessions per game, one
  `get_minigame_participants` read each, and only for the caller's own sessions.

## Mistakes / gotchas

**GOTCHA** — the pre-deletion commit is `5f7de05^`, not `5f7de05`. The theme
migration (`7648c60`) landed *before* the delete, so `main`'s version of these
files still hardcodes `AppColors`. Restoring from `main` would have put fixed
white/black tokens back into a themed app.

**GOTCHA** — `kDeckMatchesPerGame` and both providers survived the widget
deletion (they were only unused) and were removed later in `cba8321`. They must
be restored from `5f7de05^` too, or the deck compiles against nothing.

## Commands run

```bash
dart analyze lib     # No issues found!
flutter test         # 102/102 passing
```

## Follow-up (same day) — card content reduced to name + play button

Owner directive: *"instead of the cycle with the name of the game, just the name
of the game big and centered below it the play button, nothing else by now no
avatars in bubbles."*

- `_DeckCard` now paints only: the game name as a centred `VDisplayText` (size
  scaled from the card width × 0.16, clamped 24–56, lowercased like every other
  game surface) and a full-width `VButton.emphasized` labelled
  `minigamesPlayNow` directly below it. The pending invite `VCountBadge` stays
  top-right.
- The play button starts the pass-the-phone match in one tap
  (`/minigames/local/<type>?quick=1`, the same deal-the-first-round contract the
  game page's primary CTA uses); the rest of the card still opens the game page.
  `GamesDeck` gained `onPlay` alongside `onOpen` so the deck stays provider-free.
- Deleted as unused: `widgets/game_name_band.dart` (circulating bands),
  `widgets/match_bubble_field.dart` (nested avatars), `logic/match_preview.dart`
  (`MatchPlayer` / `MatchPreview`), and the deck providers that existed only to
  feed the bubbles (`kDeckMatchesPerGame`, `matchRosterProvider`,
  `gameTabMatchesProvider`). The root builds no avatar network requests now.
- `docs/design/DESIGN.md` §3 Games-deck paragraph updated; `TODO.md` and
  `docs/SLIM-PROD.md` §3.11 record the final card content.

## Follow-up 2 (same day) — fitted titles, symbol-only button

Owner directive: *"Some titles can be in 2 lines. Button no text only symbol."*

- `_fittedNameSize()` binary-searches the largest display size that the card
  width can hold, measured with `TextPainter` against
  `VDisplayText.styleFor` at the ambient `TextScaler` (2% width safety margin).
  One line wins whenever it can reach 75% of the max size; otherwise the name
  takes its second line at a larger size. Result: "verdad o reto", "botella"
  and "charadas" are one line, "2 mentiras, 1 verdad" is two — none truncated.
- The card's primary action is a **symbol-only** `VButton.emphasized` with a
  play triangle (`Icons.play_arrow_rounded`, 28, painted in
  `palette.background`). The "jugar ahora" string is kept solely as the
  button's `Semantics` label, so screen readers still announce the action.
- The name size ceiling moved to `min(cardWidth × 0.24, 56)` with a 20px floor.

## Follow-up 3 (same day) — stacked lines, circular button, random pastels

Owner directives: *"Some titles can be in 2 lines. Button no text only symbol.
… BUTTON FOR PLAY MUST BE CIRCULAR AND POSITION AGNOSTIC. POSITION OF SU BUTTON
NOW IN BOTTOM RIGHT."* then *"Color must be random"*.

- Title lines: a name of up to three words stacks **one word per line**
  ("verdad" / "o" / "reto"); a longer one splits in two balanced lines
  ("2 mentiras," / "1 verdad"). `_fittedTitleSize()` then binary-searches the
  largest size at which EVERY line fits on its own, measured with `TextPainter`
  against `VDisplayText.styleFor` at the ambient `TextScaler`.
- The card's primary action is a **circular** `_PlayButton` (56px
  `palette.foreground` disc, play triangle in `palette.background`, ink ripple)
  positioned bottom-right (`AppSpacing.lg`) by the card's `Stack` — it is laid
  out by the card, never by its neighbours, and paints no text ("jugar ahora" is
  the `Semantics` label only).
- Title colour contract: **odd lines** (1st, 3rd, …) are soft pastels from
  `AppColors.pastel*`; **even lines** (2nd, 4th, …) are a **white outline**
  (hollow letters: `TextStyle.foreground` with `PaintingStyle.stroke`). This is
  a deliberate, documented exception to the deck's monochrome rule, in the same
  family as the two legacy pastel screens.
- Randomness: the pool is shuffled once per deck (`_pastelOrder`, `Random()` in
  `initState`-time field init), and each card reads it from **its own deck
  index**, so the four games always get different first-line colours while the
  assignment stays arbitrary per launch.

**MISTAKE** — the first attempt seeded the pastel with a `hash * 31` of the game
name. All four names hashed into the same bucket, so every card painted the same
peach (and truthdare's third line collapsed to cyan). Replacing it with an
FNV-1a + avalanche finalizer spread the seeds, but two of four games still
landed on the same colour by chance. Fixed by shuffling ONE order per deck and
giving each card a distinct index instead of an independent toss per name.

## Commands run

```bash
dart analyze lib     # No issues found!
flutter test         # 102/102 passing
```
