# 2026-09-22 — Minigame header standardization + minimal 2 Lies editor

## What was built

One header language for every minigame surface, plus a from-scratch minimal
"2 mentiras, 1 verdad" subject editor, verified on the iPhone 11 simulator via
Xcode MCP.

1. **Two-line header on the shared optical centerline** — `MinigameHeaderTitle`
   no longer nudges itself with `Padding(top: 8)`; line 1 (Playfair Display
   w700 24 white) is placed on `VHeaderMetrics`' shared centerline via the new
   public `VHeaderMetrics.opticalShiftFor(context, style)`, and line 2 (Inter
   w500 11 `mutedStrong`) tucks under it. It now sits at the exact same glyph
   position as the back arrow, actions and every plain header. Closes the gap
   noted in `2026-09-11_header-optical-alignment.md`.
2. **Shared play-header helpers** — new
   `lib/features/minigames/widgets/minigame_play_header.dart`:
   `minigameHeaderSecondary` (round counter for by-turns, else lowercase game
   name), `minigameTurnTitle` (your-turn / turno de X / generic) and
   `minigameStatusTitle`.
3. **Every named surface converted to the two-line header**:
   - Games tab + hub: `juegos / Te atreves`.
   - Detail: lowercase game name / the game tagline — the tagline was removed
     from the hero body so it is never shown twice.
   - Lobby/session: lowercase game name / partida name.
   - Play screens: Truth or Dare (reference), 2 Lies, Charades, Drunk Bottle —
     turn/status on line 1, game name (or "Ronda X / Y") on line 2; the old
     in-body round counter / subject label / status text was deleted.
4. **2 Lies subject editor rebuilt minimal** — no instructions, no field
   labels inside; three rounded cards (`AppRadius.card`), a small top-left
   label, a borderless centered input (no placeholder hint) that starts at ~1.2x
   a 2-line field and grows to 4 lines then scrolls; the card being written in
   is kept on screen (`Scrollable.ensureVisible` on focus); truth is marked by
   holding a card → white border + soft white glow only (no icon/arrow); the
   pinned bar is `Responder` (dark) / `Pasar` (outlined) with Truth-or-Dare's
   exact alignment.
5. **Voter ballot** — the 3 statements are shown in a per-device deterministic
   shuffled order (`Random(stableSeed(sessionId, round, viewerId))`), reusing
   the rounded cards; the vote is mapped back to the authored index before
   `react(vote_N)`, so position patterns cannot leak the truth.
6. **2 Lies finished board** — full-bleed under the floating back arrow
   (`VHeaderMetrics`), listing each ranked player's 3 statements with the truth
   revealed (glow + `LA VERDAD`/`MENTIRA` chip). Replaced the generic
   `MinigameFinishedLeaderboard`; `FinishedLeaderboard` was deliberately NOT
   reused (its prompt header is truth/dare-typed).
7. **l10n** — added `minigamesTwoLiesHoldHint` and
   `minigamesTwoLiesMarkTruthPrompt` (es + en).

## Decisions made and why

- **Truth or Dare is the reference.** It was the most thought-out play screen
  (two-line header, full-bleed finished board, pinned action bar); the other
  surfaces were aligned to it rather than inventing a new pattern.
- **`VHeaderMetrics.opticalShiftFor` over a per-screen nudge** — one shared
  centerline keeps every header identical at any font scale; the two-line
  widget now measures line 1 with `VDisplayText.styleFor(_lineSize)`.
- **Detail tagline moves into line 2** and is dropped from the hero (no
  duplication), mirroring the hub.
- **Hold-to-truth, no checkbox** (user: a checkbox is "cringe"): the selected
  card carries a white glow with no direction. A 2 s `SnackBar` nudges the user
  if they tap `Responder` with nothing marked.
- **Voter order shuffled per device** with a stable seed so the layout does not
  jump between rebuilds while still differing across devices/rounds.
- **Rounded cards extend the sanctioned minigame-card exception**
  (`AppRadius.card`, directive 2026-09-21) from the Games deck to the minigame
  content cards; the rest of the app stays sharp-cornered.

## MISTAKE blocks

- **MISTAKE — a parent `GestureDetector.onLongPress` loses to the inner
  `TextField`.** Holding the text area of an input card did NOT mark it as the
  truth: Flutter's `TextField` registers its own long-press recognizer even
  with selection disabled, so the 500 ms parent handler never won the arena.
  Fixed with a `RawGestureDetector` + `LongPressGestureRecognizer(duration:
  350ms)` on the card so it wins before the field's 500 ms recognizer. Verified
  on device (long-press directly on the input now glows the card).
- **MISTAKE — ad-hoc `Padding(top: AppSpacing.sm)` on a custom title widget**
  silently took the minigame header off the app-wide optical line. Custom
  titles must use `VHeaderMetrics.opticalShiftFor`; never add vertical nudges.
- **MISTAKE — the first editor draft was ~127 px/card (3 min lines) and read
  as too tall.** Reduced to `minLines: 2` (≈103 px card, ~1.17x a 2-line field)
  with `maxLines: 4`, so it grows with the text and then scrolls internally.
- **`flutter gen-l10n` is lockfile-safe here** (verified: `pubspec.lock`
  unchanged); still never run `flutter analyze <file>` (implicit pub get).

## Commands run (reproducible)

```bash
export AGENT_NAME=minigame-header-foundation   # etc. per workstream
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"

flutter gen-l10n
dart analyze lib                    # No issues found!
git status --short pubspec.lock     # clean — unchanged

# Device verification (Xcode MCP, iPhone 11, testing stack)
make dev TESTING=true TARGET=simulator   # 127.0.0.1:54386 (samay-testing-kong)
# DeviceInteractionStartSession("iPhone 11") → Synthesize (tap/capture)
```

## Issues / notes

- **Header verification (device):** games tab, detail, lobby and the 2 Lies
  play screen all render line 1 at y=56.2 / h=24 and line 2 at y=82.2 / h=11;
  Playfair x-height band centre = 72.0 = the arrow/nav centerline. Consistent.
- **Not reachable for device capture:** verdad-o-reto / charadas / botella play
  screens need an in-progress match (player minimums); they share the identical
  `MinigameHeaderTitle` + helpers, so the measurement generalizes. A latent
  note: the setup/countdown fallback still uses the plain 40 px `VHeaderBar`
  title; reachable only by deep-linking a not-yet-playing session.
- **Anonymous alias editor** now lives only in the subject editor (was shown
  under every state). Anonymous voters keep their deterministic default alias.
- No backend/migration/pgTAP/opt-test change: pure Flutter. Backend-only
  testing directive stands (no Dart tests).
