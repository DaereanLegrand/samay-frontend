# Minigame pending-invite context — no roster flash, INVITADO POR

**Branch:** `truth-or-dare-leaderboard` (local) · **Date:** 2026-09-11

## Goal

Two items from the user's review of the latest `alignment-header` merge:

- **B** — rename the minigame picker confirm action `Invitar ({count})` →
  `Enviar ({count})`.
- **C** — a not-yet-accepted invitee must **never** see the participant
  roster (it flashed before the Aceptar/Rechazar card, because the invite
  provider starts `AsyncLoading` and the lobby rendered first). While pending
  the lobby shows only **INVITADO POR** + the inviter's username + profile
  picture, styled like a participant row. Once the invitee accepts, the label
  disappears on the RPC confirmation.

## What was built

### Backend
- New `supabase/migrations/209_minigame_invite_context/invite_context.sql`
  (mirrored byte-identical in `supabase-testing/migrations/209_.../`):
  `get_minigame_invite_context(p_session_id uuid) RETURNS jsonb` —
  `SECURITY DEFINER`, `SET search_path = ''`, authenticated-only. Gates on
  `auth.uid()`, reads the caller's own invite row, resolves the inviter through
  the security-barrier `user_search_view` by `created_by`, and returns
  `{status, inviter:{id,username,avatar_url}, groupName}`. A non-invitee gets
  `invite_not_found` and learns nothing. The function **never reads
  `participants`**, so it cannot leak the roster by construction.
- pgTAP Section 49s (+4; `plan(956)` → `plan(960)`): function exists; is
  SECURITY DEFINER + invitee-scoped + `invite_not_found`; resolves ONLY the
  inviter (never `participants`); anon has no EXECUTE.
- New `test/opt-028-minigame-invite-context.sh` (18 asserts): direct invite
  context (inviter id/username, no roster array), bystander denied, group name
  present, lobby-invite context, anon denied. Auto-discovered by the runner.

### Flutter
- `MinigameService.getInviteContext(sessionId)` → `invite_not_found` maps to
  null.
- `minigameInviteContextProvider(sessionId)`; `accept()`/`decline()` invalidate
  it.
- `MinigameSessionDetailScreen`: the body is now gated on the **authoritative**
  `isParticipant` (derived from `sessionStatusProvider.participants`) instead of
  the invite row. A non-participant shows a spinner while the invite/context
  loads and then `_InviteCard`; only a participant renders `_LobbySection`.
  `_InviteCard` now shows the INVITADO POR row (avatar + username + subtitle,
  same voice as `_ParticipantRow`) and the group name for a group session.
  Accept flips `isParticipant` on the RPC confirmation and the label
  disappears.
- l10n: ES `minigamesInviteCount` → `"Enviar ({count})"`; new
  `minigamesInvitedBy` = `"Invitado por"` / `"Invited by"`.

## Decisions

- **Context RPC over notification-payload extension** (user choice): secure,
  testable, and pre-existing invites get the avatar too — no coupling to
  notification delivery.
- **`isParticipant` is the gate, not the invite row.** The invite provider's
  initial `AsyncLoading` was the exact cause of the roster flash; a participant
  is known synchronously from the session row.
- Participants never fetch the context RPC (the host has no invite row), so the
  new call is paid only by a pending invitee.

## Mistakes / gotchas (searchable)

- **MISTAKE — doc-comment edit dropped a line.** An `edit` oldString spanning
  two comment lines was replaced with a one-line match, silently deleting the
  second line; caught on re-read and restored. Lesson: keep oldString minimal
  but include the full block being changed.
- **MISTAKE — running the focused pgTAP on a dirty DB.** Test 210 ("users table
  empty after init/reset") fails on the running stack because prior opt-tests
  left users behind. Pre-existing, not caused by this change; it clears after
  `make supabase-testing-reset`.

## Files

- `supabase/migrations/209_minigame_invite_context/invite_context.sql`
  (+ `supabase-testing/` mirror)
- `supabase/tests/schema_test.sql` (+ mirror) — Section 49s, plan(960)
- `test/opt-028-minigame-invite-context.sh`, `test/README.md`
- `lib/core/services/minigame_service.dart`
- `lib/features/minigames/providers/minigames_providers.dart`
- `lib/features/minigames/screens/minigame_session_detail_screen.dart`
- `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb` (+ generated localizations)
- `README.md`, the backend `DATABASE.md` (baselines)

## Commands

```bash
flutter gen-l10n

# focused backend loop (migration applied directly for RED→GREEN)
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -f supabase/migrations/209_minigame_invite_context/invite_context.sql
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
  -c "NOTIFY pgrst, 'reload schema';"
make supabase-db-test
bash test/opt-028-minigame-invite-context.sh

# full reset + reseed + re-test (requested)
make supabase-testing-reset
make supabase-db-test
bash test/run_all_backend.sh

# Flutter static gate
flutter analyze
```
