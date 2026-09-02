# 2026-09-02 — Return to an already-running match (rejoin CTA)

## What was built

Truth or Dare (and every minigame, since they share the lobby) had no way to
get back into a match that was already RUNNING. A player who closed the app,
lost connection, or switched apps mid-party was never removed from the roster —
they reopened the partida from the ongoing list and landed on the LOBBY, where:

- the HOST saw **Empezar** (locked, `isPlaying` → `onPressed: null` — tapping
  did nothing),
- a PARTICIPANT saw **¿Listo?**, which flipped their row into a "Listo" chip —
  nonsense mid-game.

The only route into the play screen was the live countdown → playing realtime
flip (`ref.listen`), which never fires for someone arriving at an
already-playing session.

Fix — pure Flutter, no backend/schema change (the participant is still in
`participants`, the game-state row already holds the current round):

- **`_LobbySection`** in `minigame_session_detail_screen.dart`: when the
  game-state phase is `playing`, the bottom CTA is a single
  **"Volver a la partida"** button (host AND participant) that
  `context.push(RoutePaths.truthDare(sessionId))` — the same route the
  countdown flip uses. `TruthDareScreen` renders the correct mid-round state
  from the same providers. Empezar/¿Listo? now only appear pre-play
  (`setup`/`countdown`); the dead `isPlaying` disable in the host branch is
  gone.
- **Ready chips suppressed mid-game**: `_ParticipantRow` takes a new
  `showReadyChip` (default true); the lobby passes `!isPlaying`, so the
  "Listo" badge on rows disappears once the match runs.

## Decisions and why

- **Button in the lobby, not auto-route**: the user explicitly asked "must be
  a button letting them back in". The lobby still shows who is in the match.
- **Reuse the existing play screen + route**: rejoining needs no new RPC —
  `get_minigame_game_state` already returns the live skeleton and the E2EE
  round keys self-heal on demand (`ensureRoundKey` pulls the host's persisted
  bundles).
- **Hide the Listo chips while playing** (user confirmed): ready is a pre-play
  handshake; once the match runs the chip reads as state that does not exist.
- Out of scope (unchanged): arriving mid-COUNTDOWN still shows the countdown
  overlay; a genuinely REMOVED player (host kick) is no longer in
  `participants` and gets the existing "Oops!" poll flow — they never see this
  button.

## Tests

No test layer added — backend/schema untouched, and the Flutter test trees are
deleted (directive 2026-08-31). Validation is static:

- `dart analyze lib/features/minigames lib/l10n` → **No issues found!**
- `flutter analyze` (the two touched items) → **No issues found!**

## Commands

```bash
dart analyze lib/features/minigames lib/l10n
flutter analyze lib/features/minigames/screens/minigame_session_detail_screen.dart lib/l10n/
```

## Files

- `lib/features/minigames/screens/minigame_session_detail_screen.dart`
- `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb` (+ the 3 generated
  `app_localizations*.dart` synced by hand in the repo's established style).
