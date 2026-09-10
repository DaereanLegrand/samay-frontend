# 2026-09-09 — Truth/Dare reactions: exclusivity, controlled spam, closing animation

## What was built

Three fixes to the by_turns / async reaction flow introduced in
`1f07584` (`207_minigame_reaction_event`):

1. **Server exclusivity corrected (the root cause).** Both reaction RPCs
   (`submit_minigame_reaction`, `react_minigame_round`) detected "already
   passed" with `SELECT reaction INTO v_existing … IF v_existing IS NULL`.
   A Pasar row stores a **NULL** `reaction` (`204_minigame_pasar`), so
   *"no row yet"* and *"already passed"* were indistinguishable → **every
   first emoji reaction was rejected `already_passed`** ("Ya pasaste…"). That
   killed the emoji tally, so by_turns never reached the all-reacted
   threshold (turn never advanced) and no `reactions_seq`/`reactions_event`
   reached other devices (no remote animation).
   Corrected to row-EXISTENCE checks: an emoji tap is `already_passed` only
   when a pass row (`reaction IS NULL`) exists; a Pasar tap is
   `already_reacted` only when an emoji row (`reaction IS NOT NULL`) exists.
   Fresh voters and same-emoji/emoji→emoji re-votes are always accepted.

2. **Controlled spam (server + client).**
   - Server: new `minigame_reactions.last_tap_at` (additive, in 207) is
     stamped on every accepted write; a same-voter write inside **250 ms**
     returns `too_fast` with NO write / no seq bump / no event.
   - Client: every emoji tap now floats the rise on the tapper's OWN card
     **immediately** (`_LocalRiseNotifier.emit` runs before the signal gate).
     `reserveTap()` now gates only the **signal to other devices**; taps
     inside the window collapse into one trailing flush of the latest emoji
     (`_ReactionRowState._pending` + `Timer`), so the tap that *closes* a
     round is never lost. Pasar bypasses the timer (mode commit) and cancels
     any pending emoji flush.
   - After a pass, **all** options are locked and greyed (emoji tiles AND the
     Pasar button) per the user directive; after an emoji, Pasar is locked
     and the emoji tiles stay live.
   - `reactToRound` (async tiles) shares the per-session signal window so
     spam is bounded there too.
   - `too_fast` maps to a silent no-op in `MinigameService.submitReaction` /
     `reactToRound` (no "already reacted"-style snackbar).

3. **Closing reaction animates on other devices.** `_ReactionRiseCanvas`
   no longer `_active.clear()`s on a round flip, and it replays the closing
   event from `reactions_event` when the reaction UPDATE + the advance were
   coalesced (or the advance arrived first): `event.round == prevRound &&
   event.hasEmoji && event.voterId != myId && seq > appliedBefore`.

## Decisions

- **Row existence, not reaction value** — the only correct way to tell a
  fresh voter from a passer given the NULL pass marker. This preserves the
  documented intent (cross-mode only) and the `voters` mirror semantics.
- **250 ms server window vs 350 ms client timer** — the client is the
  primary gate; the server is the API-layer backstop with a smaller window
  so a well-behaved device (which sends at ≥350 ms) never trips it.
- **Trailing flush** — without it a same-emoji burst could swallow the tap
  that completes the round and stall the turn. The latest tap is always
  eventually signalled.
- **Don't clear particles on round flip** — bounded by stagger +
  `reactionFloat` (~2 s), so particles self-expire; clearing erased the
  closing rise on every non-tapper device.
- **pgTAP assertions updated in place** — the two 207 exclusivity checks
  asserted the old `SELECT reaction INTO v_existing` implementation detail;
  they now assert row-existence + `too_fast`/`last_tap_at` presence. Plan
  stayed at +1 for the new `has_column` (947→948).

## MISTAKE

- **`edit` matched the wrong switch.** Adding the `too_fast` case to
  `MinigameService` hit `cancelMinigameStart` first (its switch shares the
  same prefix shape), silently replacing `cancelled`/`not_creator`/typed
  auth mapping. Caught by `dart analyze` (`unreachable_switch_case`) and
  `git diff`. Fixed by restoring `cancelMinigameStart` from `HEAD` and
  re-applying the case with a uniquely-identifying surrounding context
  (`invalid_reaction` / `answer_pending`). **Lesson: for edits in files
  with near-identical repeated blocks, anchor the oldString on a line that
  only exists at the intended site, then `git diff` the file immediately.**
- **Test-layer consequence of the server gate.** API opt-tests drove
  consecutive same-voter taps with zero delay and asserted the seq advanced.
  With a real 250 ms gate those taps are `too_fast`. Fixed by adding a
  `tap_wait()` (0.3 s) helper between consecutive same-voter taps in
  opt-020 / opt-021 / opt-023 — the API-level tests now model the client's
  deliberate (350 ms) taps. This is a contract change, not a workaround.

## Commands run

```bash
# apply the edited (idempotent) 207 to the running testing DB
docker exec -i samay-testing-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < supabase/migrations/207_minigame_reaction_event/reaction_event.sql

bash test/opt-023-minigame-reaction-event.sh   # 38 passed, 0 failed (incl. new TEST F)
bash test/opt-020-minigame-voting.sh           # 41 passed, 0 failed
bash test/opt-021-minigame-play-v2.sh          # 80 passed, 0 failed
make supabase-db-test                          # 948 tests, 1 pre-existing failure (205)
dart analyze lib                               # No issues found
diff -rq supabase/migrations supabase-testing/migrations   # identical
tools/check_migrations.sh                      # all migration-hygiene checks passed
```

## Known pre-existing failure (NOT introduced here)

- pgTAP **test 205** ("users table empty after init/reset") fails because the
  testing DB carries 4 stale `tester*` users + their groups from
  **2026-08-15** (auth + public rows). `public.users` has an FK from `groups`,
  so cleanup is not a one-liner. Unrelated to this change — every reaction
  assertion (including 944/946) passes.
- `lib/features/qr/screens/attendance_code_screen.dart` is dirty under another
  session's lock (`diag-qr-a`) and was left untouched.
