# 2026-08-28 — Dedicated per-game pages + partida names (Flutter/DB layer)

## What was built

The feed's minigame cards now open a **dedicated per-game landing page**
instead of the shared hub: game title + icon, tagline, explanation, a
"con amigos / solo" audience chip, the primary **"Nueva partida"** button,
and the game's **ongoing partidas list** (empty state shown when there are
none).

- `lib/features/minigames/screens/minigame_detail_screen.dart` — the reusable
  `MinigameDetailScreen(gameType:)` shell for ALL five games (and future
  ones). Game-agnostic: everything game-specific resolves through the
  `MinigameMeta` extension, so a new game only needs a l10n pair + a switch
  arm.
- **Create wizard** ("Nueva partida"): name input (blank → auto `partida-XX`
  display), **Directa/Grupo** scope chips (Grupo → group picker), invite
  players (reuses `MinigameInviteScreen`/`UserPickerView`), wager **default
  10 shards** (0 = no wager preserved). Pops `true` so the page refreshes its
  list.
- `lib/features/minigames/logic/minigame_meta.dart` — `MinigameMeta`
  extension (`explanation` / `audience` / `audienceLabel` / `tagline` per
  game type), `minigameTypeFromString` (route param → enum), and
  `minigameSessionName` (user `name` → else auto `partida-XX` running
  number).
- `RoutePaths.minigame(gameType)` → `/minigames/game/:gameType`, flag-gated
  in `app_router.dart` (unknown type → `RouteErrorScreen`). Feed card `onTap`
  now routes here; the old group-picker bottom-sheet path was removed from
  the feed (Direct is the default scope; Grupo is chosen inside the wizard).
- **DB**: migration `160_minigame_names` — `minigame_sessions.name` (text,
  nullable) + `create_minigame_session(uuid,text,integer,uuid[],text)` with
  optional `p_name` (trimmed; NULL/blank → auto-name fallback). The 4-arg
  overload is dropped (CREATE OR REPLACE can't change the arg list).
- `MinigameService.createSession`/notifiers forward `name` as `p_name`.

## Decisions

- **Reusability-first**: the detail page + `MinigameMeta` mean per-game
  content is a l10n pair, not a new screen. `MinigameAudience`: challenge =
  both, the other four = friends.
- **Auto `partida-XX` stays client-side**: NULL/blank `name` never pollutes
  the DB — the display computes `partida-N` (N = running number in the
  list). This kept the migration pure (additive column).
- **Direct default from the feed**: per the approved plan, the feed card
  opens the page directly (no bottom sheet); Directa is default and Grupo is
  an in-wizard choice. The existing `MinigamesScreen` hub stays untouched
  (group-detail/chat entries still land there).
- **Lazy list (PERF-01)**: the ongoing rows are `ListView.builder` items
  (index 0 = hero + CTA + heading; rows after). The wizard's form stays a
  plain `ListView` (fixed child count — justified in the perf allowlist; the
  pre-existing `truth_dare_screen.dart` fixed 3-child play body was added
  with justification too).
- **pgTAP**: Section 49d added; plan(742) → **751** (9 assertions, counted
  with the same regex the Dart static guard uses). `minigame_rpc_migration_test.dart`
  now reads `160_minigame_names` for the create RPC contract.
- **opt-018** extended with TEST A1: `p_name` trimmed+stored; blank → NULL.

## Follow-up — UI refinements + live migration (same day)

- **Redundant hero removed** (user directive): the AppBar already names the
  game, so the hero no longer repeats the title + icon — the per-game page
  keeps tagline + explanation + audience tag only.
- **"Nueva partida" is now white with black font** (`VButton.emphasized`).
- **Audience tag restyled**: smaller grey pill (`AppColors.border` background,
  black 12px text) via a dedicated `_AudienceTag` widget instead of `VChip`.
- **Live-stack fix**: the running `samay-testing` stack (54386) was still on
  the 4-arg `create_minigame_session` (140) — the app's `p_name` caused the
  "No se pudieron cargar las partidas / Reintentar" failure. Applied
  `supabase-testing/migrations/160_minigame_names/names.sql` directly via psql
  (additive + self-contained; `apply_migrations.sh` is NOT idempotent on an
  existing DB, so a targeted apply beats a full `supabase-testing-reset` that
  would wipe the tester user's data). Verified: 5-arg RPC + `name` column live,
  authenticated EXECUTE granted; `listMySessions` returns the tester's existing
  direct truth_dare partida.
- **Seed images stripped (user directive 2026-08-28)**: `seed-test.sql`
  (both stacks, byte-identical) no longer carries any image data — the 4
  @tester users insert with `avatar_url NULL`, the "Cowboy Bebopers" group
  inserts with `cover_url NULL`, and the 4 `storage.objects` metadata rows
  (avatars + group cover) are deleted from the seed. All the non-image seed
  data (friendships, group+members, minigames, e2ee keys, shards/ranks,
  signup tracker) is kept. opt-005 static seed validation still passes (58
  checks). Re-applied the cleaned seed to the live testing DB (which was
  empty) so the 4 tester accounts work with no avatars/banners.

## MISTAKE blocks

- **MISTAKE (wizard hint vs label)**: the wizard's name field asserts its
  *hint* ("En blanco = nombre automático"), not the label — `VInput` renders
  `hint ?? label`, so passing a hint overrides the label as the placeholder.
  Fixed the test to match the hint text.
- **MISTAKE (unbounded LayoutBuilder)**: an initial `_fillState`-style
  `LayoutBuilder` + `SingleChildScrollView` empty-state wrapper inside the
  outer `ListView` threw "BoxConstraints forces an infinite height". Removed
  the height-filling wrapper — the outer scrollable owns layout.
- **MISTAKE (plan count)**: first bump was plan(750) but 9 assertions were
  added; the Dart static guard caught the mismatch and I corrected to 751.
- **MISTAKE (route shadowing)**: the per-game path uses a fixed `/game/`
  segment so it can never be shadowed by the `:groupId` hub — remembered from
  the `/minigames/play/truth-dare` precedent.

## Commands run

```bash
make test-file FILE=test/features/minigames/minigame_rpc_migration_test.dart
make test-file FILE=test/features/minigames/logic/minigame_meta_test.dart
make test-file FILE=test/features/minigames/minigame_service_test.dart
make test-file FILE=test/features/minigames/minigames_providers_test.dart
make test-file FILE=test/features/minigames/minigame_detail_screen_test.dart
make test-feature FEATURE=minigames
make test-feature FEATURE=feed
make test-file FILE=test/features/plugged_entries_test.dart
make test-file FILE=test/meta/conventions_test.dart
make test-file FILE=test/structure_test.dart
make test-file FILE=test/perf/list_view_builder_test.dart
make flutter-test          # 1853 pass / 0 fail
make check                # analyze + vet + ports + secrets all green
go test ./...             # green
bash -n test/opt-018-minigame-play.sh
bash tools/check_ports.sh --strict   # STRICT PASS
bash tools/check_secrets.sh          # PASS
```

## Notes

- Integration flows (`integration_test/minigames_flow_test.dart` gained a
  per-game-page flow; the fake's `createSession` signature grew `name`) need
  a device — analyzed clean, not executed here.
- README baselines updated: pgTAP plan→751, Flutter 1783→1853; cross-references
  `GMCR` row and `<private-ops-repo>/DATABASE.md` gained the 160_minigame_names row.
