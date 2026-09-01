# 2026-09-01 — Round-key K_0 mint race on the host (startMatch own-UPDATE)

## What was built

- **`MinigameGameStateNotifier.startMatch()` now mints + distributes K_0**
  synchronously from the RPC result, instead of relying on the realtime
  listener to observe the countdown → playing flip:

  ```dart
  final result = await _service.startMatch(arg);
  final round = MinigameGameState.fromRow(result).skeleton.round;
  _mintedRound = round;
  await _mintRoundKey(round);
  await refresh();
  ```

- Doc comments on `startMatch` / `_mintRoundKey` / the realtime listener state
  the mint contract + the offline posture.

## Root cause (the race)

The host's K_0 mint was driven ONLY by `ref.listen` on the
`minigame-game-state` realtime channel, keyed to observing the transition
`prevPhase=countdown → phase=playing` (`justStarted`). But the host performs
that flip ITSELF via `startMatch()` → `start_minigame_match` RPC →
`refresh()`. Riverpod dispatches the realtime callback synchronously on the
same microtask queue, so by the time the host's listener runs the UPDATE is
already applied: `prevPhase` reads `playing`, `justStarted` is false, and the
mint never runs.

The subject's submit then self-heals via `ensureRoundKey` →
`getE2eeBundles` → **zero rows** (`selfRecipientBundles=0`) →
`StateError: round key 0 missing` → "Error del servidor". Reproduced on both
devices (Waydroid host + Android emulator subject); the diag commit `8bb512a`
logs confirmed `mintedRound=null` on both hosts at the flip.

## Offline analysis (drives the fix shape)

- Bundles (`minigame_e2ee_bundles`) and prekeys (`e2ee_identity_keys`) are
  SERVER-PERSISTED, so a peer offline at mint time can still be wrapped IF
  its prekeys are published — X3DH reads them via `fetch_prekey_bundle`
  (which consumes one OPK atomically). The offline peer simply cannot decrypt
  the bundle until it returns, then self-heals via `ensureRoundKey`.
- A peer with NO published prekey is skipped (`E2eeCryptoException` caught in
  `_deliverBundle`) and stays missing — retried on the next roster change or
  round bump.
- Round 1+ keeps riding the realtime listener: every server-side advance
  re-mints and re-delivers the FULL cumulative `K_0..K_r`, so an offline
  member who missed K_0 catches up on the next round bump.
- Remaining true limitation (documented, not fixed): a member offline at
  Empezar who returns while STILL in round 0 has no re-delivery trigger
  (roster unchanged, no round bump) — needs a future client-side "re-request
  keys" path. The host must be online at mint time to wrap prekeys.

## Decisions

- **startMatch-only mint** (per user directive): do NOT add an accept-time
  mint seam now. The accept/roster-change safety nets already deliver history
  to newcomers; round-bump re-delivery catches offline players up. Keep the
  diff minimal and focused on the deterministic race.
- **No backend change**: the RPCs, bundle table, RLS and cipher self-heal were
  all correct — the bug was that the host never minted at all. No migration,
  no opt-test changes.

## MISTAKE blocks

**MISTAKE: keying a state transition to a realtime observation the actor
itself produces.** The host flips countdown → playing via its own RPC, so it
can never *observe* that flip as a transition — Riverpod already applied the
UPDATE before its listener runs. Any "when X happens, do Y" logic where the
local actor is the one that makes X happen must run in the ACTOR'S OWN
mutation path, not in a realtime listener.

## Commands

```bash
dart analyze                      # No issues found!
go test ./...                     # ok (cached)
bash test/opt-005-seeds-static.sh # PASS (45 checks)
bash test/opt-007-compose-static.sh  # pre-existing .env SERVICE_KEY mismatch (unrelated)
```

On-device verification still to run (host Android + subject Waydroid):
Empezar → subject submits → expect host `minigame mint triggered round=0`,
subject `round key ready for write source=memory`, no "Error del servidor".
