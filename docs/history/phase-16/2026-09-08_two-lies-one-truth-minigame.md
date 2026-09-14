# 2026-09-08 — Minigame "2 mentiras 1 verdad" (Two Lies, One Truth) Implementation (206)

## What was built

Implemented the complete **"2 mentiras 1 verdad" (Two Lies, One Truth)** minigame across the entire stack (PostgreSQL / Supabase, Dart / Flutter, E2EE, i18n, and backend tests), without breaking existing games (`truth_dare`) and adhering strictly to the repository conventions in `AGENTS.md`.

### 1. Database & Migrations (Migration `206_minigame_two_lies_one_truth/two_lies.sql`)
- Mirrored byte-identical in both `supabase/migrations/` and `supabase-testing/migrations/`.
- Extended `public.mini_game_type` enum with `'two_lies_one_truth'`.
- Updated `mgs_reaction_value_check` on `minigame_reactions` to allow `'vote_0'`, `'vote_1'`, `'vote_2'` alongside existing emojis and NULL (`pasar`).
- Updated `submit_minigame_reaction` and `react_minigame_round` RPCs:
  - Validates vote reactions for `two_lies_one_truth` rounds.
  - Supports auto-advancing rounds when all non-subject players have cast their votes or passed.
- Seeded initial topic prompts into `minigame_prompts` for `'two_lies_one_truth'`.

### 2. Logic & Cryptography (`lib/features/minigames/logic/`)
- Created `two_lies_one_truth.dart`:
  - `TwoLiesStatement`: model for individual statements with client-side truth flag.
  - `TwoLiesPayload`: JSON serialization/deserialization for round answers, safely encrypting/decrypting statements and the true index using `MinigameCipher.encryptAnswerText` / `decryptAnswerText` with the per-round key $K_r$.
  - Wire helper functions (`voteWireForIndex`, `parseVoteIndex`).
- Extended `ReactionKind` in `minigame_engine.dart` with `vote0`, `vote1`, `vote2`.
- Updated `minigame_meta.dart` mapping `twoLiesOneTruth` with metadata, icon (`Icons.psychology_alt`), and payload parsing.

### 3. Reusable UI Components & Screens
- Created `lib/features/minigames/widgets/minigame_shared_widgets.dart`:
  - `MinigameFinishedLeaderboard`: reusable podium/leaderboard card for ended games.
  - `MinigameAliasEditor`: reusable anonymous alias editor dialog/sheet.
  - `minigameResolveDisplayName`: helper to uniformly resolve player nicknames/aliases.
- Created `lib/features/minigames/screens/two_lies_screen.dart`:
  - Subject input card: 3 statement text fields with radio/selection for the true statement, encrypted client-side upon submission.
  - Waiting card: displayed to the subject while participants cast votes.
  - Voter guess card: allows participants to select which of the 3 statements is the truth, or pass (`pasar`).
  - Round transition and leaderboard display on match completion.
- Updated `MinigamesScreen` to display the "2 mentiras 1 verdad" card.
- Updated `MinigameSessionDetailScreen` (lobby):
  - Dynamic game routing on match start (`two_lies_one_truth` routes to `RoutePaths.twoLiesOneTruth`).
  - Added direct navigation button ("Ir a la partida") if the session is already in `playing` status.

### 4. Routing & Localization
- Added `RoutePaths.twoLiesOneTruth(sessionId)` and registered the route behind `AppFeatureFlag.minigames` in `app_router.dart`.
- Added localized strings in `app_es.arb` and `app_en.arb` for metadata, prompts, placeholders, voter choices, and results. Generated via `flutter gen-l10n`.

### 5. Backend Tests
- Added Section 49p (5 assertions) in `supabase/tests/schema_test.sql` and `supabase-testing/tests/schema_test.sql`, advancing the pgTAP suite to `plan(908)`.
- Created curl integration test `test/opt-022-minigame-two-lies.sh` verifying session creation, lobby invites, match start, E2EE submission, voting auto-advance, and finish settlement.

---

## Decisions and Why

1. **Reusing `minigame_reactions` with `'vote_0'..'vote_2'`**:
   Rather than introducing a separate voting table or altering the primary key constraints, votes ride the existing reaction infrastructure. The composite primary key `(session_id, round_number, voter_id)` naturally guarantees one vote per player per round.
2. **Client-side E2EE for Statements and Truth Index**:
   The server only stores encrypted ciphertexts in `minigame_answers`. The server never learns which statement is the truth, preserving privacy and cheating resistance.
3. **Component Reusability**:
   Extracted the finished leaderboard and alias editor into `minigame_shared_widgets.dart`, deduplicating code between `truth_dare` and `two_lies_one_truth`.
4. **Dynamic Lobby Dispatch**:
   Replaced hardcoded truth/dare routing in `MinigameSessionDetailScreen` with dynamic resolution based on `gameType`.

---

## Verification & Commands

```bash
# Apply migration 206 to test database
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/migrations/206_minigame_two_lies_one_truth/two_lies.sql

# Test Section 49p pgTAP assertions
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql

# Code generation & static analysis
flutter gen-l10n
dart analyze
go test ./...

# Migration & security hygiene
bash tools/check_migrations.sh
bash tools/check_secrets.sh
bash tools/check_ports.sh --strict
```

---

## Post-Implementation Bug Fixes & MISTAKE Blocks

### 1. Black Screen on Round 0 Statement Entry

```markdown
MISTAKE: In `lib/features/minigames/screens/two_lies_screen.dart` (`_SubjectEditorCard`),
`VButton.outlined` was placed inside a `Row` alongside `Expanded(child: VButton.emphasized(...))`
without being wrapped in `Expanded`. Because `VButton` has an internal width of
`double.infinity`, placing it inside a horizontal `Row` without `Expanded` or `Flexible`
causes an unconstrained width assertion failure (`RenderBox was not laid out: RenderPadding NEEDS-PAINT`).
During rendering, this crashes the Flutter frame layout and produces a black screen of death.
FIX: Wrapped `VButton.outlined` in `Expanded`.
```

### 2. Multi-emulator Session Visibility & Minimum Players

- **Pending Invites in Hub**: `MinigamesScreen` (`/minigames`) previously only queried `myMinigameSessionsProvider` (which filters by `participants @> [my_id]`), ignoring sessions the user was invited to until they accepted. Updated `_buildSessions` to watch `myPendingInvitesProvider` in direct mode and display pending invitation cards with "Invitación pendiente - Invitado por <nombre>", allowing invitees to tap and accept directly from the hub.
- **Minimum Players Gate in Lobby**: In `MinigameSessionDetailScreen`, starting a multiplayer-only minigame (`MinigameAudience.friends`) with only 1 participant is now prevented, displaying a friendly prompt ("Esperando jugadores...") instead of launching an unplayable solo match before invited friends accept.

