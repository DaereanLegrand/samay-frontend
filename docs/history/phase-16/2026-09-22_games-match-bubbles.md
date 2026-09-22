# 2026-09-22 — Games tab: play glyph + nested match bubbles (seeded demo data)

## What was built

The Games-tab deck cards gained a **background-less white play glyph** at the
centre and a **nested match-bubble field** around it, fed by demo minigame
matches seeded into the local `supabase-testing` stack.

- `lib/features/minigames/widgets/match_bubble_field.dart` — NEW. One **mega
  bubble per recent match**, radius scaled by player count; each nests up to
  **6 randomly-sized avatar bubbles** (some markedly smaller) plus a white
  `+N` overflow. The mega bubbles are a deterministic, **collision-free
  scatter** that avoids each other, the centred play glyph, and the top/bottom
  name-band zones. Newest matches are tried first; only the ones that fit are
  drawn (cap 5). The packing is memoized on (matches, box size) so a deck drag
  never re-runs it. No physics, no ticker — reduced-motion safe.
- `lib/features/minigames/logic/match_preview.dart` — NEW. `MatchPreview` +
  `MatchPlayer`: the minimal typed shape the card draws, kept out of the
  providers file so the deck widgets stay provider-free.
- `lib/features/minigames/providers/minigames_providers.dart` —
  `matchRosterProvider` (family, the single `get_minigame_participants` read —
  deliberately NOT `minigameParticipantsProvider`, which attaches realtime
  session + game-state listeners per session) and `gameTabMatchesProvider`
  (groups `myMinigameSessionsProvider` by game, sorts `created_at` desc, takes
  `kDeckMatchesPerGame = 5`, resolves rosters).
- `lib/features/minigames/widgets/game_name_band.dart` — exposed
  `GameNameBand.bandHeight` so the card can reserve the band zones.
- `lib/features/minigames/widgets/games_deck.dart` — `GamesDeck.matchesByGame`
  param; `_DeckCard` draws the play glyph + `MatchBubbleField` (band insets).
- `lib/features/minigames/screens/games_tab_screen.dart` — watches
  `gameTabMatchesProvider` and injects it into the deck.
- `supabase-testing/seed-sample-matches.sh` + `make
  supabase-testing-seed-sample-matches` — NEW. Downloads 20 CC0 DiceBear
  `lorelei` avatars, creates 20 sample users (admin API + public profile +
  storage upload), and inserts **28 DIRECT sessions (7 per game)** with
  random-ish player counts and `created_at` 7 h apart. Idempotent; refuses any
  non-local target.
- Game-detail lists needed **no change** — they filter
  `myMinigameSessionsProvider` by `game_type`, so the seeded rows surface
  there automatically.

## Decisions made and why

- **Seed the DB, not bundle assets** (human directive): sample matches appear
  in BOTH the deck cards and the per-game detail lists through the real
  provider/RLS path.
- **Local-only guard in the script**: the root `.env` points at the PROD API
  (`samay-api.qallariy.lat`); the script hard-asserts `127.0.0.1:54386` and
  exits otherwise, so a prod-pointed run can never be seeded. Only
  `supabase-testing/` was touched.
- **Demo host in every session** (human directive: log in as a sample user):
  `demo_ana@samay.test` is a participant of all 28 so one login shows every
  match.
- **lorelei CC0** avatars (human directive): DiceBear's `lorelei` style is
  CC0 1.0 — no attribution, PNG ≤256. Uploaded to the public `avatars` bucket
  (`<uid>/avatar.png`), public URL stored in `users.avatar_url`.
- **A dedicated roster provider** instead of reusing
  `minigameParticipantsProvider`: the latter subscribes to session + game-state
  realtime per session; watching it for ~20 sessions would open ~60 channels
  for a static preview.
- **Mega size scales with player count** and **newest-first** selection (human
  directives).

## Mistakes / gotchas

**MISTAKE** — `${array[*]}` joins with only the FIRST character of `IFS`, so
`IFS="','"; "${a[*]}"` yields `x'y` (no commas), not `'x','y'`. Fixed with a
`join_quoted` helper (`printf "'%s',"` + strip the trailing comma).

**MISTAKE** — `zsh` treats `UID` as a readonly integer. Assigning a UUID to
`UID` in a verification one-liner throws `bad math expression`. Use a different
variable name (`DUID`) for shell UUIDs.

**GOTCHA** — `POSTGRES_DB=supabase` in `supabase-testing/.env` is not the real
database name; the container's DB is `postgres` (port 54382). The script
defaults to `postgres` (override with `SEED_DB`).

**GOTCHA** — public storage objects still need the Kong `apikey` header: a
direct `GET` of `/storage/v1/object/public/...` returns 401 without it (the
app's `VNetworkImage` adds it for `/storage/v1/` URLs).

## Commands run

```bash
dart analyze lib/features/minigames/logic/match_preview.dart \
  lib/features/minigames/widgets/match_bubble_field.dart \
  lib/features/minigames/providers/minigames_providers.dart \
  lib/features/minigames/widgets/games_deck.dart \
  lib/features/minigames/widgets/game_name_band.dart \
  lib/features/minigames/screens/games_tab_screen.dart   # No issues found!

bash supabase-testing/seed-sample-matches.sh
# ✅ seeded 20 sample users, 28 sessions
#    login: demo.ana@samay.test / SamayDemo#2026
```

Verified end-to-end against `127.0.0.1:54386`: password login as the demo host,
28 sessions visible via RLS, avatar public fetch 200, roster RPC returns
players with avatars.

No backend/migration/RLS change; Flutter/Dart test trees stay deleted
(directive 2026-08-31). Human to run `make dev TESTING=true` and log in as the
demo host to view.

## Follow-up (2026-09-22) — bubble stability rework (no fallbacks)

Three defects reported on-device after the first bubble pass:

1. **Scroll crash** — `MatchBubbleField._ticker` was a *lazy* `late final`
   (`createTicker` in the initializer). A card that never jiggled never
   initialized it, so `dispose()` triggered the lazy init → `createTicker`
   looked up `TickerMode` on an already-deactivated element → the
   `_lifecycleState != defunct` assertion. FIX: the ticker is created eagerly
   in `initState()` and held in a nullable field; `dispose` uses `?.`.
2. **Bubbles appearing/disappearing while scrolling** — `_DeckCard` /
   `MatchBubbleField` were unkeyed, so a slot's widget was reused for a
   different game every cycle and re-ran every avatar's load+stagger. FIX: the
   field is keyed per game (`ValueKey('bubbles:${type.value}')`) and load state
   moved to a module-level `_resolvedBubbles` set, so a bubble that has
   appeared renders instantly on any later mount.
3. **`+N` / missing mega rings** — `_OverflowBubble` was an unkeyed direct
   Stack child while avatars were keyed, so repacks could swap/drop it; and
   mega completion was a fragile cross-widget async handshake. FIX: every
   inner is keyed on its `Positioned` wrapper (`avatar:`/`overflow:`), the
   `+N` is rendered whenever `totalPlayers > shown` and never gated on load,
   and completion is read straight from `_resolvedBubbles`.

**No fallback timers** (human directive): the completion net added earlier was
deleted. Loading is reliable because `VNetworkImage.resolveStorageUrl` rewrites
seeded storage URLs to the build's own Supabase origin and the `apikey` header
is attached; a real error still resolves the bubble to its initials so a ring
cannot stick.

```bash
dart analyze lib/features/minigames/widgets/match_bubble_field.dart \
  lib/features/minigames/widgets/games_deck.dart   # No issues found!
```

## Follow-up (2026-09-22) — placement fits, physics removed, slower settle

- **Packing actually fills now**: the avatar caps were huge (`min 22–34`, `max
  ≤54`) and the play exclusion was `0.17×` the card, so the old random probing
  only ever found 2 slots. Caps are now `min 22–30`, `max ≤44`, the exclusion is
  `0.13×`, the mega padding is 7, and placement scans a **deterministic shuffled
  grid** over the whole free zone — up to the cap (4 fit cleanly).
- **`+N` count fixed**: the roster can omit participants the viewer cannot
  resolve, so `totalPlayers` is now `max(roster.length, participants.length)`
  and the overflow bubble reflects the real match.
- **Movement reaction removed** (human directive): the jiggle ticker, `motion`
  parameter and `Transform.translate` are gone — the field is static again.
- **Slower lock-in**: the deck settle spring went from `stiffness 420 / damping
  34` to **`80 / 18`**, so the deck eases into the next/previous card slowly
  instead of snapping.
