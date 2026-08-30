# 2026-08-30 — Minigame Partida Lobby (180_minigame_lobby)

## What was built

The session detail screen is now the **partida lobby** — the pre-play room:

- **AppBar title = LOWERCASE minigame name** (user directive): the session
  detail AppBar shows "verdad o reto" for Verdad o Reto (es) / "truth or
  dare" (en). New `minigameGameNameLower(l10n, gameType)` in
  `minigame_meta.dart` (`minigameGameName(...).toLowerCase()`).
- **Realtime participants list**: `get_minigame_participants(uuid)` RPC
  (SECURITY DEFINER, `search_path=''`, I-57 typed-jsonb) resolves every
  participant's id/username/avatar_url through the security-barrier
  `user_search_view` in ONE round trip — works for NON-friends (the existing
  `get_friend_profiles` RPC is friends-only and would drop strangers).
- **Per-player Ready**: `set_minigame_ready(uuid, boolean)` RPC upserts the
  caller's flag into the NEW authoritative `minigame_game_state.ready` jsonb
  map (`{participant_id: bool}`). The ready map lives on the GAME-STATE row
  (not the session row) so the existing `minigame_game_state` realtime
  subscription streams every toggle live to the whole lobby.
- **Creator-only Start, backend-enforced**: `init_minigame_game_state`
  (CREATE OR REPLACE, same signature) now gates to `participants[0]` →
  `not_creator`. The provider NO LONGER auto-inits on first read (the old
  behavior made the play screen the implicit starter); `start()` is the
  creator's explicit action and the ready map clears on init.
- **Creator-only removal**: `remove_minigame_participant(uuid, uuid)` RPC —
  gated to `participants[0]` (`not_creator`); in one transaction it refunds
  the removed player's wager escrow (`minigame_refund` ledger + shards
  credit), drops them from `participants`, deletes their invite row, and
  clears their ready flag. The creator can never remove themself
  (`not_participant`).
- **`minigame_sessions` joins `supabase_realtime`** (guarded) — it was
  missing from the publication, so a realtime participants list could not
  see a peer join or be removed.

Client side: `MinigameService.setReady/getMinigameParticipants/
removeParticipant`; `minigameParticipantsProvider` (roster merged with the
LIVE ready map from `minigameGameStateProvider`); ready/start/remove actions
on the game-state notifier; the lobby UI on `minigame_session_detail_screen`
(participant rows, ready chips, creator Start → navigates to
`RoutePaths.truthDare`, creator remove with confirmation dialog).

### Lobby polish (same session, after the initial ship)

- **Accepted invitees see the lobby** — the static "Te uniste a la partida"
  card is gone; accepting falls through to `_LobbySection` (the join
  confirmation lives in the SnackBar).
- **Granular ready sync** — the roster is fetched ONCE; live ready toggles
  stream through `minigameGameStateProvider` and `ref.listen` diffs the ready
  map, updating ONLY the changed row in place (`copyWithReady`). No whole-list
  rebuild, no re-fetch — a participant flipping ready doesn't ripple the
  whole lobby on every device.
- **Ready UI (2026-08-30 user directive)** — others show a plain
  (non-emphasized, `selected:false`) "Listo"/"Ready" chip with NO username,
  and only once they are ready; a not-ready player shows nothing; the HOST
  never shows a chip (ready by default). A non-creator toggles their own
  state via the EMPHASIZED "¿Listo?"/"Ready?" button (white fill, black font)
  that flips to the outlined "Listo"/"Ready" — sitting exactly where the
  creator's Start button does.
- **Creator Start** is now the emphasized "Empezar"/"Start" (white fill,
  black font).
- Removed the dead `minigamesReadyFor` l10n key (no longer used).

## Decisions made and why

- **Ready/Start model = industry-standard lobby pattern** (researched
  Colyseus/Nakama/Photon): the DB row IS the authoritative room state, RPCs
  are the server-side intent handlers, the realtime channel is state sync,
  and the creator is the host with authority over the `lobby → playing`
  transition. The `ready` jsonb map on `minigame_game_state` is the
  Colyseus `MapSchema<Player>` analog.
- **Creator gate lives in the RPC, not the UI** (explicit user directive
  "creator only must be backend enforced"): `init_minigame_game_state` and
  `remove_minigame_participant` check `participants[0] == auth.uid()` server
  side and return `not_creator`.
- **Ready map on game state, not session**: the game-state row already has
  the realtime membership; putting `ready` there avoids touching the
  `minigame_sessions` UPDATE path (which was not realtime-enabled) and keeps
  one channel driving lobby + play.
- **Roster via a new RPC** instead of `getUserProfile` N+1 or
  `get_friend_profiles`: batched, non-friend-safe, `search_path=''` hardened,
  mirrors the play-engine I-57 contract.
- **Removal refunds the wager** (GWAG): the participant's escrow deduction is
  reversed via the `minigame_refund` ledger, consistent with draw settlement.

## MISTAKE blocks

- **MISTAKE (auto-init removal):** `minigameGameStateProvider` used to call
  `init_minigame_game_state` on first read. With the lobby watching it for
  the ready map, merely opening the lobby would START the game (or throw
  `not_creator` for non-creators). Fixed by removing the auto-init and making
  `start()` explicit. This broke two play-screen tests that assumed a
  `not_started` row would auto-seed — updated them to seed lazily.
- **MISTAKE (pre-existing Hive regression):** commit 5b49bd5 (friends-cache
  warmer) broke EVERY hermetic integration flow — the real `HiveService`
  reads encrypted boxes that are never opened in the test harness
  (`Box not found`). `integration_test/truth_dare_flow_test.dart` was
  failing before this session's work. Fixed centrally in
  `integration_test/support/test_app.dart`: `newTestContainer` now overrides
  `hiveServiceProvider` with an in-memory `MemoryHiveService`.
- **MISTAKE (get_minigame_participants signature):** first draft raised
  exceptions; changed to the established I-57 typed-jsonb-status contract
  (`{'status':'ok','participants':[...]}`) to match every other play RPC.

## Commands run

```bash
flutter gen-l10n
flutter analyze lib/features/minigames lib/core/services/minigame_service.dart
flutter test test/features/minigames/
flutter test -d macos integration_test/minigame_lobby_flow_test.dart
flutter test -d macos integration_test/truth_dare_flow_test.dart
flutter test -d macos integration_test/minigames_flow_test.dart
bash -n test/opt-019-minigame-lobby.sh
```

## Coverage

- `test/features/minigames/minigame_service_test.dart` — `setReady` /
  `getMinigameParticipants` / `removeParticipant` wire contracts + typed
  rejections (`not_creator`, `not_allowed`, `session_not_active`).
- `test/features/minigames/minigame_lobby_screen_test.dart` — lowercase
  AppBar (body no longer repeats the capitalized title), realtime roster +
  host marker, the non-creator "¿Listo?" toggle wiring through
  `set_minigame_ready`, creator-only Start ("Empezar"), creator-only remove
  wiring.
- `integration_test/minigame_lobby_flow_test.dart` (registered in
  `runner.sh`) — creator Start ("Empezar") → init, + creator removal.
- `test/opt-019-minigame-lobby.sh` — ready map on the row, roster resolves
  non-friends, `not_creator` for B/C, wager refund + participants drop +
  invite close on removal.
- pgTAP Section 49g (`schema_test.sql` ×2, plan 765→793) — the 3 RPCs, the
  `ready` column, creator-gated init, `minigame_sessions` realtime.
