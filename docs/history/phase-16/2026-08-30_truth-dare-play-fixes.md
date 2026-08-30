# 2026-08-30 — truth-dare play fixes (countdown, usernames, X close)

## What was built

- **190_minigame_countdown** migration (both stacks, byte-identical mirror):
  `init_minigame_game_state` now seeds `phase='countdown'` +
  `countdown_ends_at = now()+5s` + `next_subject_id` (server-authoritative
  "who's next"); `get_minigame_game_state` performs the LAZY flip to
  `playing` once the deadline passes (the UPDATE streams via the existing
  `minigame_game_state` realtime channel — the "go to play screen" broadcast);
  new **`cancel_minigame_start`** (creator-only, resets to a setup skeleton);
  `advance_minigame_turn` rejects mid-countdown (`countdown_pending`) and
  re-draws a fresh `next_subject_id` each turn.
- **Lobby screen**: full-screen countdown overlay for EVERY participant the
  moment the host taps Start (number seeded from the server deadline, purely
  visual); host-only Cancelar → `cancel_minigame_start`; on `countdown →
  playing` (server flip) every participant auto-navigates to the play screen.
  Start button no longer navigates; disabled during countdown.
- **Play screen**: usernames always (never a UUID — names resolve through
  `minigameParticipantsProvider`), header "Turno de <username>", "Siguiente:
  <name>" caption, non-subject view has NO choice buttons, AppBar title
  lowercase, X **host-only** with a small confirm ("¿Seguro? Las apuestas se
  redistribuirán."). Back arrow stays non-destructive.
- Engine/service/provider: `MinigamePhase.countdown`, `nextSubjectId`,
  `countdownEndsAt`, `cancelMinigameStart` / `cancelStart()`.

## Decisions

- The DB row is the single source of truth for the countdown — no client
  wall-clock agreement. Server flips `playing` after 5s; the client timer is
  only a visual + a re-read nudge at 0.
- Deadline stored as a NATIVE timestamptz in jsonb (round-trips exactly both
  ways); the first draft used `to_char(...'Z')` which would have skewed by the
  session timezone — caught before the DB reset.

## MISTAKE blocks

- `to_char(now(), ...'Z')` labels the deadline as UTC while `now()` renders in
  the session timezone → potential 2h+ skew. Fixed with a native timestamptz.
- During edits the `_confirmComplete` method signature was accidentally
  deleted and `integration_test/minigames_flow_test.dart` had a line
  collapsed — both caught by `flutter analyze`.

## Verification (no test files touched)

- `flutter analyze` → no issues.
- `make supabase-testing-reset` (DB reset) → 36 baseline files applied
  cleanly, `190` applied, seed-config ok.
- psql functional check via `request.jwt.claims`: init by non-creator →
  `not_creator`; init by creator → `countdown` + deadline + distinct
  subject/next_subject; re-init idempotent; advance during countdown →
  `countdown_pending`; cancel non-creator → `not_creator`; cancel creator →
  `cancelled` + setup; deadline-passed get → `playing`; advance ok with fresh
  next_subject; cancel after playing → `not_started`.
- `tools/check_ports.sh --strict` → STRICT PASS; `tools/check_secrets.sh` →
  PASS.

## Commands

```
flutter analyze
flutter gen-l10n
make supabase-testing-reset
bash tools/check_migrations.sh
bash tools/check_ports.sh --strict
bash tools/check_secrets.sh
```

---

## Second pass (same day) — stale-state repair: accept flow, roster, remove UI

### Reported symptoms

1. Invitee enters a partida from the feed ("Invitación pendiente"), accepts; the
   Jugadores list is not updated — the only listed player is wrongly shown as
   the host and the other participants never appear. Re-entering from the feed
   still shows "Invitación pendiente". Only a hot RESTART fixes it; hot reload
   does nothing.
2. Host removes a participant: first tap shows "Error del servidor", a retry
   says "Participante no encontrado".

### Root cause

Verified against the reset stack via REST + JWT that the SERVER is correct:
`accept_minigame_invite` appends the invitee to `participants` and
`get_minigame_participants` returns both players; `remove_minigame_participant`
returns `removed` (first) then `not_participant` (retry). The bug was purely
client-side: the accept/decline actions never invalidated the roster, the
pending-invite list, or the invite notification; the roster only re-fetched on
realtime `minigame_sessions` UPDATEs (which can be dropped). Hot reload keeps
Riverpod state, so the stale roster survived; a hot restart re-read the DB.

### Fixes (`lib/features/minigames/providers/minigames_providers.dart` +
`lib/features/minigames/screens/minigame_session_detail_screen.dart`)

- `MinigameInviteNotifier.accept()` now ALSO invalidates
  `minigameParticipantsProvider` (roster re-fetch), `myPendingInvitesProvider`
  (the feed→game page drops the pending row), and marks the invite's
  notification read (`markRead` best-effort — the feed tile's red badge clears
  in the same tap).
- `decline()` invalidates `myPendingInvitesProvider` + marks read.
- `MinigameParticipantsNotifier` now `ref.listen`s on `sessionStatusProvider`
  and re-fetches whenever the authoritative `participants` id set changes —
  covers accept, host-created-after-open, join, leave and kick, even when a
  realtime UPDATE is dropped (guarded with `state.hasValue` to avoid a
  spurious first-load double-build).
- `removeParticipant` also invalidates `myPendingInvitesProvider` (the removed
  invitee's invite closes server-side).
- **Remove UI**: the RPC either removes the player or answers typed
  `not_participant` (double tap / concurrent remove). The removed player is
  already out server-side — the UI now dismisses the confirm dialog on success
  AND on `NOT_FOUND` instead of showing "Error del servidor", so a retry no
  longer resurfaces an error. The host-marker comparison in `_ParticipantRow`
  is null-safe (`participantIds.isNotEmpty && ...`) so a stale roster entry
  (accept flow lag) can never crash a row.

### MISTAKE blocks

- The fake in `truth_dare_screen_test.dart` returned `participants` as a list
  of MAPS, but the real column is `uuid[]` (list of id strings) — this exact
  mismatch was the historical root of the "Toca <UUID>" bug and broke the
  screen tests once the screen read the real shape. Repaired the fakes.
- `minigame_detail_screen_test.dart` still asserted the CAPITALIZED title
  ("Verdad o Reto") — stale since the 180 lowercase-title directive; updated
  to "verdad o reto".

---

## Third pass (same day) — first-ready streams + kicked popup wording

### 191_minigame_game_state_at_creation (both stacks, committed c353a85)

The minigame_game_state row now exists FROM session creation: `create_minigame_session`
INSERTs `(session_id, game_type, state='{}', ready='{}')` in the same transaction,
and `set_minigame_ready` is a plain UPDATE (no `ON CONFLICT`). Every ready toggle
is an UPDATE → the update-only `minigame_game_state` realtime subscription streams
it from the FIRST one (previously the first toggle INSERTed the row, which the
`update`-only subscription never delivered → user had to toggle off/on).

Verified on the reset stack: create → game-state row exists immediately;
first ready toggle returns `ready` and writes the ready map.

### Kicked popup wording

The "Te quitaron de la partida." body line is REMOVED (per user directive). The
"Oops!" popup now shows only the title + Volver button.

### pgTAP

Section 49h (3 assertions, both stacks, plan 793 → 796): create seeds the
game-state row; set_minigame_ready is a plain UPDATE (no ON CONFLICT) that still
writes the auth.uid() ready flag. New assertions pass.

### Pre-existing failures (NOT caused by this work)

`supabase db test` reports 7 failures (tests 321, 332-333, 750-751, 780, 792) —
all present on the baseline commit 07147dd: the 160/170 DEFAULT-arg signatures
broke the `LIKE '%uuid[], text%'` checks, and `get_minigame_participants` /
`init_minigame_game_state` body-pattern checks went stale in 180/190. Out of scope.


### Verification

- `flutter analyze` → no issues.
- `flutter test test/features/minigames/` → 197 passed.
- `flutter test integration_test/truth_dare_flow_test.dart -d macos` → passed.
- REST+JWT against the reset stack: create (wagered) → guest accept → host
  remove → `removed`; retry → `not_participant` (server contract confirmed).
- `tools/check_ports.sh --strict` / `tools/check_secrets.sh` → PASS.

