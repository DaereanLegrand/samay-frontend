# 2026-09-01 — Reactor-side Pasar on the Truth or Dare reaction deck (204)

## What was built

The user directive: **below the emotion deck** there must be a **Pasar /
Pass** button. Tapping it gives **-0.5** to the user whose turn it is — the
one who submitted the answer — as **final leaderboard points**, stacking
per passer against the +1-per-emoji scoring.

That is a *reactor*-side Pasar, distinct from the already-shipped
*subject*-side skip (`submit_minigame_pasar`, -1, blocks reactions). It is
available in BOTH modes: the by_turns reaction row and each async
reactable-round tile.

### Backend (migration `204_minigame_pasar`, mirrored into `supabase-testing`)

- `minigame_reactions.reaction` became **NULLABLE** — NULL is the pass
  marker; a new `mgs_reaction_value_check` allows NULL or the six emoji
  wire values. The PK `(session, round, voter)` still guarantees ONE action
  per voter per round.
- `submit_minigame_reaction(uuid, text)` and `react_minigame_round(uuid,
  int, text)` (both CREATE OR REPLACE) accept `p_reaction = 'pasar'`: they
  upsert a NULL-reaction row and mirror `{subject_id: {"list": [emoji…],
  "count": N, "pass": P}}` into `state.reactions` (new `pass` count).
  The by_turns auto-advance counts passers as "reacted" (a round closes
  once every non-subject has emoji-reacted or passed).
- `_minigame_advance_round` scores `emoji_count - pass_count/2`, normalized
  to an integer when integral (jsonb renders `2`, not `2.0`; fractional
  scores keep one decimal). A passed round / a round with ZERO emojis still
  scores **-1** (the no-reactions penalty keeps precedence over an all-pass
  round's 0).
- `finish_minigame_game` settles fractional scores: by_turns reads
  `(rr ->> 'score')::numeric`; async computes per-round `emoji_count -
  pass_count/2` summed across the player's rounds (-1 per passed round).

### Flutter

- `ReactionKind.pass` (wire `'pasar'`) added; `reactionEmojiKinds` is the
  emoji-only iteration list (pass renders as a button, never an emoji).
- `GameTurnSkeleton` gains `reactionPassCounts` (parsed from the mirror's
  `pass`) + `reactionPassCount(subjectId)`; `hasReactedToCurrentRound`
  treats a pass as reacted.
- `_ReactionRow` (by_turns) and `_AsyncReactableTile` (async) each got a
  `VButton.outlined(l10n.minigamesPasar)` below the emoji row, with a new
  l10n hint `minigamesPasarReactionHint` ("Pasar — al jugador le resta 0.5").

## Decisions and why

- **Reuse the existing wire RPCs** instead of new signatures/table: `pasar`
  rides `submit_minigame_reaction` / `react_minigame_round`. One voter per
  (session, round, voter) already existed, so the pass is a NULL emoji —
  no schema surface added.
- **NULL = pass marker** rather than a `'pasar'` text value: `count(distinct
  voter_id)` and the `list` aggregation both treat NULL cleanly (list only
  aggregates non-NULL), and the PK upsert (emoji ↔ pass) replaces the
  voter's one action.
- **-0.5 per passer, stacking**, per the explicit product answer. Only
  halves ever occur (each passer = -0.5), so numeric keeps one decimal and
  normalizes to integer when integral.
- **Scoring stays server-authoritative**: the client never computes scores;
  it only renders the mirror. Round records and results carry the exact
  fractional value.

## Tests

- `test/opt-020-minigame-voting.sh` — TEST G: dedicated session; pass before
  answer rejected (`answer_pending`), subject own-round pass rejected
  (`own_round`), 1 emoji + 1 pass → auto-advance + round `"score":0.5`.
- `test/opt-021-minigame-play-v2.sh` — TEST J: async reactable round, pass
  via `react_minigame_round`, mirror carries `{"list","count":2,"pass":1}`,
  subject own-round pass rejected, invalid reaction still rejected.
- pgTAP `supabase/tests/schema_test.sql` Section 49n (+12 → plan(893)),
  mirrored into `supabase-testing/tests/schema_test.sql`.

Results: opt-020 **41/41**, opt-021 **80/80**, pgTAP **893/893**,
`dart analyze` **0 issues**, opt-005 **45 checks** pass.

## MISTAKE: pgTAP runner regression

`make supabase-db-test` had been silently broken by a CLI upgrade: the CLI
(pg_prove via `supabase/pg_prove:3.36`) now **requires `sslmode=disable`**
in `--db-url` — the compose server exposes no TLS and the run failed with
`tls error (The server does not support SSL connections)`. The `PGTAP_DB_URL`
in the Makefile had no `sslmode` since it was introduced (2026-08-10). Fixed
by appending `?sslmode=disable` and documenting it. Do NOT "fix" this by
adding TLS to the compose stack — the approved port map / self-hosted
posture has none.

## MISTAKE: opt-007 compose-static "failures"

`opt-007` reports SERVICE_KEY-vs-.env drift on opt-001..006: the root
`.env`'s `SUPABASE_SERVICE_ROLE_KEY` is EMPTY while the opt-tests hardcode
the `supabase-testing/.env` value. This is the documented 2026-08-25-rotation
drift (README §Testing summary) — pre-existing, NOT caused by this change.
Runtime runs pass because `test/dev_env.sh` loads the real key from
`supabase-testing/.env`.

## Commands

```bash
make supabase-testing-reset
bash test/opt-020-minigame-voting.sh   # 41/41
bash test/opt-021-minigame-play-v2.sh  # 80/80
make supabase-db-test                  # pgTAP 893/893 (after sslmode fix)
dart analyze                           # 0 issues
bash test/opt-005-seeds-static.sh      # 45 checks
```
