# 2026-09-03 — Round-key request ring (206_minigame_key_request)

## What was built

A **server-blind re-key heal** for the minigame E2EE round keys
(`206_minigame_key_request`). Closes the exact bug reported on-device: a
participant whose device-local E2EE state was wiped (app reinstall / data
clear / account switch regenerates the identity + republishes it) can never
decrypt the host's OLD-identity pairwise bundles — the self-heal dead-ends on
the `recipient identity does not match` DROP, so the subject's own screen
showed only "waiting X/Y reactions…" with no answer, while every intact
participant read it fine.

The logs proved it:
```
minigame ensureRoundKey … round=0 selfRecipientBundles=2
e2ee init envelope DROPPED …c5c2cba7… recipient identity does not match this device (delivery binding §6.5; the sender initiated against a stale published bundle)
minigame e2ee round key missing after self-heal round=0 bundles=2
```

Design (Signal-faithful — server COMPLETELY blind, any participant serves):
- `state.key_requests` jsonb uuid[] rides INSIDE the game-state payload (no
  new column — streams on the existing realtime channel). It is a REQUEST
  MARKER only; no key material ever crosses an RPC.
- `request_minigame_round_keys(uuid)` (SECURITY DEFINER, participant-only,
  active session, dedup) appends the caller.
- `resolve_minigame_key_request(uuid, uuid)` (SECURITY DEFINER, participant-
  only, NEVER self-clear, idempotent) removes a served peer.
- ANY participant (not just the host) who still holds the key history observes
  a new requester, re-wraps `K_0..K_<latest>` to the requester's CURRENT
  identity via the existing `minigame_e2ee_bundles` seam (fresh X3DH init),
  then clears the marker. The marker persists across rounds (advance does NOT
  drop it) so a round-0 requester is still healed in round 1 via additive
  delivery.
- The requester side polls its own-recipient bundles until the fresh re-wrap
  lands; `_AnswerPreview` shows a friendly "Waiting for another participant
  to connect to decrypt…" spinner, then a Reintentar state when no holder is
  online — no more silent blank.

Files: `supabase/migrations/206_minigame_key_request/key_request.sql` +
byte-identical `supabase-testing/` mirror; pgTAP Section 49q (plan 909 → 921);
`test/opt-022-minigame-key-request.sh` (19 asserts); `MinigameCipher`
(`hasRoundKey` / `requestRoundKeyShare` / `shareRoundHistoryWith`,
`_deliverBundle` now returns success); `MinigameGameStateNotifier`
(`_serveKeyRequests`, requester-set delta gating); `GameTurnSkeleton.keyRequests`;
`MinigameService.requestMinigameRoundKeys` / `resolveMinigameKeyRequest`;
`_AnswerPreview` recovery UI + `_KeyRecovery`; l10n `minigamesKeyRequesting` /
`minigamesKeyMissing`.

## Decisions and why

- **Server blind.** The server only brokers a marker; the round keys still
  travel pairwise-encrypted between devices. Requirement "server must not know
  what users do or say" holds — no WhatsApp-style server key custody, no KDF
  dependency, no invariant rewrite.
- **Any holder serves, not just the host.** Matches "not only host would be
  able to re-mint but any participant". The host stays the mint authority for
  NEW rounds; recovery of EXISTING keys is any-holder.
- **Marker inside `state` jsonb, not a column.** Rides the existing realtime
  channel + skeleton parse; no schema column to keep in sync across
  create/init/advance. Advance's key-drop list deliberately does NOT include
  `key_requests`, so the marker survives round bumps (additive heal).
- **Serve gated on a requester-set delta** (not every realtime emission) so a
  persistent unserved requester doesn't re-trigger a serve pass on every
  unrelated UPDATE.

## MISTAKE blocks

**MISTAKE: opt-022 negative grep on the whole RPC response.** Asserting "B no
longer present" with `! grep -q UUID_B` over the whole payload failed because
UUID_B was the round-0 `subject_id` elsewhere in the state. Fixed by grepping
only the `"key_requests":[...]` array.

**MISTAKE (diagnosis, not this change): a reinstall is the phone-side
equivalent of Signal losing its primary device.** The reactors saw answers
because they were intact installs holding their keys; the wiped device could
not. The deferred limitation in `2026-09-01_round-key-mint-race.md` ("offline
at Empezar who returns in round 0 has no re-delivery trigger") is what this
ring closes for the reinstall case.

## Tests / commands

- `bash test/opt-022-minigame-key-request.sh` → **19/19 PASS** (live stack,
  migration applied via psql).
- `make supabase-db-test` → **920/921**; the single failure is test 181
  ("users table empty after init/reset") — a pristine-DB precondition that
  fails on a populated stack (4 pre-existing tester users), unrelated to this
  change. All 12 new Section 49q assertions pass (plan 909 → 921).
- `go test ./...` → cached ok.
- `dart analyze lib` → No issues found.
- `bash test/opt-005-seeds-static.sh` → PASS (45).
- `bash test/opt-007-compose-static.sh` → pre-existing SERVICE_KEY `.env`
  drift on opt-001..006 (documented baseline), unchanged.

## Remaining true limitation (documented, unchanged)

If the ONLY device that ever held `K_r` is offline at request time, no holder
can serve — the requester sees the friendly "no one connected" state and a
Reintentar. This is the Signal-primary-offline case and is accepted.
