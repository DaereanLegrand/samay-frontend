# Truth or Dare — finished-game leaderboard redesign + lobby nickname uniqueness

**Branch:** `truth-or-dare-leaderboard` · **Date:** 2026-09-10

## What was built

Finished-game leaderboard (`_FinishedLeaderboard` in
`lib/features/minigames/screens/truth_dare_screen.dart`) rebuilt as a 3D
coverflow carousel and upgraded from "ranks + scores" to per-round
question/answer/reaction cards. Anonymous nickname editing moved from the
match screen into the lobby, and nicknames became session-unique.

1. **Duplicate title removed.** The body `VDisplayText(minigamesLeaderboardTitle)`
   is gone; the header keeps `minigamesBarLeaderboard` ("clasificación"). The
   now-dead `minigamesLeaderboardTitle` l10n key was deleted from both ARBs.
2. **Question + answer.** `MinigamePlayerContentNotifier` batch-resolves each
   answer's `prompt_id` → `minigame_prompts.body` (client join, no migration)
   and attaches it to the answer. Each card page renders the typed question
   (`Verdad`/`Reto` + body) above the answer. If the prompt cannot be resolved
   (inactive/removed — RLS exposes only `is_active = true`), the page shows
   `minigamesPromptLoadError` INSTEAD of question+answer (explicit user choice,
   no fallback).
3. **Per-answer reactions + image-gated rise.** Reactions are tallied per round
   (one subject per round) and attached to that round's answer. When the
   SELECTED card's current answer image has loaded (immediate when there is no
   image), that answer's received reactions rise at once — each reusing
   `_RisingReactionParticle`'s random lane/wobble and 0–320 ms start offset.
   Re-fires on card selection, re-tap, or answer-page change. Reduced motion
   spawns nothing.
4. **Shorter, centered, 3D mist carousel.** `PageView` (`viewportFraction 0.7`,
   `clipBehavior: Clip.none`) inside a fixed-height (`min(54% height, 440px)`)
   `Center`. Per page: perspective `Matrix4` (`setEntry(3,2,0.0015)` +
   `rotateY` + `scaleByDouble`) and a screen-space `translate` recede the
   neighbours; `ImageFiltered` blur + `Opacity` driven by `|page - index|`
   dissolve the outgoing card into mist and resolve the incoming one.
5. **Passed answers last.** The provider sorts each player's answers
   non-passed (round asc) first, passed last.
6. **Lobby nickname editor + uniqueness.** The in-match `_AliasEditor` was
   removed; a `_AliasButton` in the lobby (anonymous + pre-play) opens
   `_AliasDialog` (field + confirm with a spinner until the RPC answers).
   `208_minigame_alias_unique` adds a `UNIQUE (session_id, lower(btrim(alias)))`
   index and replaces `set_minigame_alias` to reject a nickname another
   participant holds (`alias_taken`, case-insensitive) while allowing a
   participant to re-save their own; a lost race (`unique_violation`) maps to
   the same friendly status. The `minigame_aliases` realtime subscription now
   listens to `PostgresChangeEvent.all` so a first-time nickname (INSERT)
   reaches every lobby member, not just renames.

## Decisions

- **Client join over a durable column** for prompt text (user choice): no
  migration, prompts are static; deactivated prompts degrade to the explicit
  load-error state.
- **Reactions grouped per round**, not per subject, because the mirror/table
  key is `(session_id, round, voter_id)` and each round has one subject.
- **Reveal real names only on the leaderboard** (unchanged existing contract).

## Mistakes / gotchas

- **MISTAKE — `has_index/3` does not take a description.** The first pgTAP
  attempt `has_index(table, index, description)` made test 870 fail: pgTAP
  matched the 3-arg overload as `(schema, table, index)` and reported the
  description as the wanted index. Fixed by asserting on
  `to_regclass('public.<index>') IS NOT NULL` + `pg_index.indisunique`.
- **MISTAKE — ARB block edit dropped a sibling key.** Removing
  `minigamesLeaderboardTitle` with a too-wide edit also deleted
  `minigamesPromptSkip`; caught by re-reading the file and restored in the same
  edit that added `minigamesPromptLoadError`.
- **Environment:** the running `samay-testing` DB already had 4 user rows, so
  pgTAP test 210 ("users table empty after init/reset") fails on a dirty stack.
  Pre-existing/environmental, unrelated to this change; passes after
  `make supabase-testing-reset`.
- `..scale(scale)` on `Matrix4` is deprecated; replaced with
  `..scaleByDouble(scale, scale, scale, 1.0)`.

## Commands run

```bash
flutter gen-l10n
dart analyze lib                     # clean
# apply the new migration to the running testing stack
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -f supabase-testing/migrations/208_minigame_alias_unique/alias_unique.sql
make supabase-db-test                # 956 tests, only pre-existing 210 fails
bash test/opt-021-minigame-play-v2.sh  # 83 passed, 0 failed (incl. 3 new alias cases)
```

## Files

- `lib/features/minigames/screens/truth_dare_screen.dart`
- `lib/features/minigames/screens/minigame_session_detail_screen.dart`
- `lib/features/minigames/providers/minigames_providers.dart`
- `lib/features/minigames/logic/minigame_engine.dart`
- `lib/core/services/minigame_service.dart`
- `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb` (+ generated localizations)
- `supabase/migrations/208_minigame_alias_unique/alias_unique.sql` (+ mirror)
- `supabase/tests/schema_test.sql` (+ mirror), `test/opt-021-minigame-play-v2.sh`
- `README.md` (pgTAP baseline 953→956)
