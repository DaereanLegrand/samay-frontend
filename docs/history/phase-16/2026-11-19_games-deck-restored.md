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

## Follow-up 4 (same day) — pastel ink whitened

Owner directive: *"The soft pastel colors must have a more white tint."*

- `_DeckTitle.pastels` is no longer the raw §2.3 token list: each colour is
  blended 35% toward white by `_DeckTitle.tinted()` before the one-per-launch
  shuffle, so the odd title lines read as a soft tint (still clearly hued, no
  longer a saturated display glyph). The white-outline lines are unchanged.

## Follow-up 5 (same day) — player count is a stepper

Owner directive: *"WHY WOULD IT BE A SET AMOUNT OF PLAYERS. MUST BE - <NUM> +,
'-' and '+' are buttons."*

- The lobby's first step no longer offers a preset chip list (`3/4/5/6/8`) nor a
  numeric text field. `_CountStepper` renders a round `−` button, the live
  number, and a round `+` button (`_StepperButton`, 56px discs).
- Bounds are enforced by the widget: the floor is the game's minimum
  ([LocalRoster.minPlayers] = 3) and the ceiling is 20; both buttons disable
  (and dim to `mutedForeground`) at their end.
- The number is painted in the **Inter** UI voice explicitly — reusing
  `textTheme.displayMedium` had picked up the Playfair display role with its
  pink glow halo, which read as a highlight instead of a count.

## Follow-up 6 (same day) — two-player floor, honest name step

Owner directive: *"min 2"*.

- `LocalRoster.minPlayers` is now **2** (a judge and a subject are the minimum
  the rules need). The stepper's floor, the deck's play gate and every "need
  more players" message follow it; `minigamesLobbyNeedThree` was renamed to
  `minigamesLobbyNeedPlayers` and reworded ("al menos dos jugadores").
- Name collection: the pass-the-device line is now the step's headline and is
  shown for EVERY name (the first person also hands the phone over), and the
  question "Escribe tu nombre o alias" is a real label above the field.
  Previously it was passed as `VInput.label`, which VInput paints as the hint —
  so the prompt vanished as soon as the first character was typed, and the bare
  field looked like the whole screen. The field's placeholder is the seat
  ("Jugador 1"), so no line is duplicated.

## Follow-up 7 (same day) — modern lobby UI

Owner directive: *"LOOKS REALLY SHITTY. Use the modern style used in the rest of
code to do it big centered."* then *"follow modern UI/UX patterns that apply to
current design"*.

- **Step progress.** The three setup questions show a 3-segment bar under the
  header (`_StepProgress`): filled up to the current step, hairline after —
  the standard modern-onboarding cue that the flow is finite. The roster (the
  destination) carries no bar.
- **Centred composition.** `_LobbyStepLayout` centres the headline + control
  block on the page's optical centre instead of top-aligning a form, with the
  primary action pinned above the bottom inset. Copy is centre-aligned.
- **Keyboard-first name entry.** `_BigNameField` autofocuses on the name step,
  renders the value in the display voice above a 2px underline that brightens on
  focus, and submits from the keyboard (`TextInputAction.done`).
- **Segmented controls.** Rounds and charadas duration are single-select
  `_Segmented<T>` pills (one sliding token), replacing loose chip rows — the
  Material 3 / iOS pattern for a short fixed set.
- **Deck grid.** Charadas categories are a 2-column grid of emoji cards
  (`_DeckGrid`), which scans faster than eight chips and gives each category its
  glyph.
- **Modern list rows.** A roster row is a full-width tappable card (chevron +
  X) instead of a name with a 36px pencil: tapping the row renames, which is the
  list interaction users already know. Rename/add open a themed bottom sheet
  (`_askName`) rather than a small alert dialog.
- **Saved groups dedupe.** `LocalGroup.create` now derives a stable id from
  name + roster, and `HiveLocalGroupStore.all()` collapses rows by that content
  key, so the legacy per-save UUID rows stop stacking ("Ana, Beto, Caro" was
  listed 14 times). The roster header also stopped repeating its own title and
  now reads "3 jugadores · Toca un nombre para cambiarlo".

## Follow-up 8 (same day) — custom values, 1-based counting, reorder, seat avatar

Owner directives: *"Rondas and duration must have custom option. Number indexing
is not user friendly, right now in screenshot says '0 DE 3' normal people counts
from 1. Also in lobby must exist a 3 line draggable after the X for removing,
which must serve to change the list order. No hint at name or alias input, also
this screen does not look modern at all."*

- **Custom values.** `_PresetPicker` keeps the presets in a segmented control and
  puts **Personalizado** on its own full-width row (`_CustomValueRow`) — as a
  fifth segment it ellipsized to "Person…". The row shows the active custom value
  and clears when a preset is tapped. Rounds clamp to 1–99, turn length to
  5–600 s.
- **1-based counting.** The name step's overline is the seat being filled
  (`_pending.length + 1`), so the first screen reads "1 de 3".
- **Drag to reorder.** Each roster row gained a `Icons.drag_handle` after the X;
  `_RosterList` wraps `ReorderableListView` (`buildDefaultDragHandles: false`,
  `ReorderableDragStartListener` on the handle only) and `LocalRosterNotifier.
  reorder` moves the seat. Because the judge/subject rotation follows seat order,
  this is the turn order too.
- **No placeholder.** `_BigNameField`'s `hint` is gone entirely: the question
  above the field already says what to type, and the placeholder repeated it.
- **Modern name step.** `_SeatEntry` shows a 96px avatar that fills in with the
  typed initials, the big centred field under it, then the collected players as
  small filled avatars plus the still-empty seats — the step now reads as joining
  a table instead of filling a form.

**MISTAKE** — the custom-value sheet disposed its `TextEditingController` in the
caller right after `pop`, while the route was still animating out with the field
focused: `'_dependents.isEmpty': is not true`. `_PromptSheet` is now stateful and
owns its controller (disposing it in `dispose()`).

**MISTAKE** — the custom sheet pre-filled the current value but did not select
it, so typing appended: entering 7 onto a previous "0" saved **70**. The
controller now selects its whole text on init, so typing replaces.

## Follow-up 9 (same day) — wording + name-step revert

Owner directives: *"Instead of 'Rondas personalizadas' 'Cantidad de rondas…' also
'Escribe tu nombre o alias' looks worse go back."*

- Custom prompts reworded as questions with an ellipsis: **"Cantidad de
  rondas…"** / **"Cantidad de segundos…"** (English "Number of rounds…" /
  "Number of seconds…").
- The name step is back to the earlier, simpler composition: the display
  headline is the seat ("Jugador 1"), the question **"Escribe tu nombre o
  alias"** is the field's in-input hint, and the big initials avatar /
  seat-rows are removed (`_SeatEntry`, `_MiniSeat`, `_EmptySeat` deleted).
