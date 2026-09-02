# 2026-09-01 — Lobby invite RPC (`205_minigame_invite_lobby`)

## What was built

Invites moved OUT of match creation into the partida lobby. The host now
creates a match with ZERO invitees, lands in the lobby (the session detail /
`180_minigame_lobby`), and invites players from an AppBar button at the
title's right while waiting.

**Backend — new `invite_minigame_players(p_session_id uuid, p_invitees uuid[])`**
(`supabase/migrations/205_minigame_invite_lobby/invite_lobby.sql`, mirrored
byte-identical into `supabase-testing/`):

- SECURITY DEFINER + `SET search_path = ''`, typed jsonb statuses (I-57).
- **Creator-only** via `participants[1] <> auth.uid()` → `not_creator`
  (mirror of `start_minigame_match` / `remove_minigame_participant`).
- Mirrors the create-time per-invitee gates: live user + not-blocked →
  `invitee_not_allowed`, friends-only privacy → `invitee_friends_only`,
  self-skip, cap 20 → `too_many_invitees`.
- **Idempotent**: skips self / already-participant / already-pending invitees
  (the `(session_id, invitee_id)` UNIQUE would also reject them) — a repeated
  lobby tap reports `invited: 0`.
- Re-checks the session's frozen `player_limit` (participants + pending +
  new) → `player_limit_reached`.
- The existing `notify_minigame_invite` AFTER-INSERT trigger fires for each
  new row, so the invitee notification (direct + group payload with
  wager/inviter) works unchanged.

`create_minigame_session` KEEPS `p_invitees` (backward compatible; the user
noted it will be premium-gated later — e.g. >10 players needs a subscription).

**Flutter:**

- `minigame_detail_screen.dart` — create wizard drops the invite step
  (`_inviteeIds`, `_pickInvitees`, `_InviteesSummary` removed); the wizard now
  pops the created session id and the detail page auto-enters the lobby.
- `minigames_screen.dart` — hub `_create()` drops the pre-create player picker
  and auto-enters the lobby after create.
- `minigame_session_detail_screen.dart` — `VHeaderBar` gains a host-only
  Invite icon button (`Icons.person_add_alt`, right of the title), shown when
  `isCreator && !isFinished`; tapping opens `MinigameInviteScreen` with the
  current participants excluded, then calls the RPC.
- `minigame_service.dart` — `invitePlayers(sessionId, inviteeIds)` RPC wrapper
  mapping typed statuses.
- `minigames_providers.dart` — `MinigameInviteNotifier.invitePlayers(...)`
  invalidates `myPendingInvitesProvider` + `sessionStatusProvider` so the
  invitee's rows/badge follow.
- l10n: `minigamesInviteSent` (en/es).

**Tests (RED-first):**

- pgTAP Section 49o (10 asserts) in `supabase/tests/schema_test.sql` (+ mirror):
  `has_function` 2-arg, `is_definer`, `search_path=""`, typed lifecycle
  statuses, creator-only `participants[1]`, blocked/friends-only gates,
  frozen-cap re-check, idempotent pending-skip, ACL posture. `plan(903)`.
- `test/opt-016-minigames-invites.sh` TEST I (11 asserts): zero-invitee create
  → RPC ok + pending row + notification; idempotent re-invite; `not_creator`;
  already-participant skip; friends-only; over-cap; notification dispatch.

## Decisions made and why

- New RPC instead of a plain INSERT policy: matches the typed-jsonb RPC family
  and lets the server enforce blocked/friends-only/cap atomically (an INSERT
  policy could not).
- Creator-only invite (not every participant): consistent with Start/Remove
  being creator-gated; the host curates the waiting room.
- Auto-enter the lobby after create: the 2026-09-01 flow is "invite after
  match creation while waiting in the lobby", so the host should land there.
- Kept `p_invitees` on `create_minigame_session` (premium-gated later).

## Mistakes / gotchas

- **MISTAKE**: the idempotency subquery used `unnest(v_clean_invitees) AS
  t(v_invitee)`, colliding with the PL/pgSQL variable `v_invitee` →
  `column reference "v_invitee" is ambiguous` (code 42702). Fixed by aliasing
  the column to `t(v)` and filtering on `t.v`. Caught by opt-016 TEST I.
- **MISTAKE**: `supabase-docker-reset` (prod stack) collides with the running
  `supabase-testing` stack on ports 54382/54386 — the reset failed with "port
  is already allocated". The opt-tests run against the TESTING stack; use
  `make supabase-testing-reset` for a clean pgTAP/opt run, never the prod
  reset while testing is up. Also left the prod stack's containers `Created`;
  cleaned up with `make supabase-docker-stop`.

## Commands run

```bash
# RED: pgTAP (plan 893 → 903) + opt-016 TEST I written first
dart analyze                       # 0 issues
go test ./...                      # green (unchanged surface)

# Apply the new migration to the RUNNING TESTING stack, then validate
make supabase-testing-reset        # fresh DB, all 43 migrations incl. 205
make supabase-db-test              # pgTAP 903/903 PASS
bash test/opt-016-minigames-invites.sh   # 49/49 PASS (TEST I included)

# Static gates
bash test/opt-005-seeds-static.sh  # PASS (45 checks)
bash test/opt-008-makefile-static.sh    # PASS
bash tools/check_ports.sh --strict # STRICT PASS
bash tools/check_secrets.sh        # PASS

# NOTE: opt-007-compose-static.sh reports a PRE-EXISTING SERVICE_KEY-vs-.env
# drift on opt-001..006 (local .env rotated after 2026-08-25) — documented in
# README; not caused by this change.
```
