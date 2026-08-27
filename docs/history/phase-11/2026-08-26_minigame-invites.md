# 2026-08-26 — Minigame player invites (participant select)

## What was built

User invites for minigames — the GMCR "participant select" step. Anyone from
the user-search pool can be invited (friends prioritized in the picker), the
invitee gets a realtime notification, and accepts are only possible while the
session is `active`.

**Backend (migration `140_minigame_invites`, both stacks mirrored):**
- `minigame_invites` table (FORCE RLS, invitee+creator read, UNIQUE
  `(session_id, invitee_id)`) + `mini_game_invite_status` enum.
- `create_minigame_session` extended to 4-arg with `p_invitees uuid[]`: the
  3-arg baseline is DROPPED (CREATE OR REPLACE cannot change the arg list),
  per-invitee blocked/deleted + friends-only gates enforced atomically, one
  pending invite row per invitee, dedup + 20-invitee cap.
- `users.minigame_invite_friends_only` (default OFF) + `set_*` RPC
  (profile-RPC lockdown: clients never hold UPDATE on `users`).
- `accept_minigame_invite` (escrow mirror + **`session_finished`** closure) +
  `decline_minigame_invite` (idempotent).
- `ms_read_invitee` SELECT policy on `minigame_sessions` so non-member
  invitees can render the session detail.
- Notification trigger moved from `minigame_sessions` INSERT to
  `minigame_invites` INSERT (notifies the INVITEE, not the creator).
- `notifications` + `minigame_invites` joined `supabase_realtime`
  (**GO-realtime**: invites land live in the invitee's notification center).

**Flutter:**
- Reusable `UserPickerView` (`lib/features/friends/widgets/`) — the /chat
  reusable-widget architecture (ChatThreadView thin-scaffold pattern) over
  the `searchResultsProvider` plumbing + `SearchScreen` row shape; friends
  first sort + excluded-ids; adopted by the new invite picker. The group
  `InviteScreen` is the future second adopter.
- `MinigameInviteScreen` (thin scaffold over the picker, pops selected ids),
  `MinigameSessionDetailScreen` (accept/decline, finished-closed state); the
  hub create action now opens the picker first; session-card tap → detail.
- `minigameInviteProvider` + `minigameInviteFriendsOnlyProvider`;
  settings "Juegos" section with the friends-only invite privacy switch.
- Notifications: `minigame_invite` deep link → `/minigames/session/:id`;
  new route + `isRegisteredRoutePath` updated.

**Tests:** pgTAP plan(617)→`plan(649)` (Section 45 update, new 49b, NTRG#7
moved, realtime memberships); static guard `minigame_rpc_migration_test`
(36 tests, green); service/provider/widget/screen tests; opt-016 curl test
(needs the stack + migration applied).

## Decisions & why

- **Invitees need not be group members** — the invite targets the session, not
  the group; `ms_read_invitee` is the narrowest read that lets them render and
  accept. Members still join through the group-scoped model.
- **Accept-only-while-active** (`session_finished`): the game may start before
  the invitee accepts; once finished the invite closes.
- **Friends-only gate enforced server-side** in `create_minigame_session`; the
  picker's friends-first sort is cosmetic only, never trusted.
- **Realtime via `notifications`** (not a bespoke `minigame_invites`
  subscription): the notification center already subscribes to `notifications`
  inserts, and the trigger emits one per invite.

## MISTAKE blocks

- **MISTAKE (router splice):** inserting the session-detail GoRoute swallowed
  the preceding route's closing `),`; `dart analyze` caught "too many
  positional arguments" at `GoRoute(`. Fixed by re-adding the closing paren —
  verify the byte structure when splicing routes.
- **MISTAKE (pgTAP needle):** `contains("'minigame_invites has FORCE ROW
  LEVEL SECURITY'")` with a trailing quote fails because the real label
  continues `… (140_minigame_invites)`. Drop the trailing quote from `contains`
  needles unless the label really ends there.
- **MISTAKE (widget tests):** `tester.pageBack()` does not find the Material
  back button under the Spanish locale (tooltip is `Volver`); use
  `find.byType(BackButton)`. And `pumpAndSettle` does NOT advance a plain
  `Timer` (the search debounce) — advance the fake clock explicitly
  (`pump(350ms)`) or the search never fires.
- **MISTAKE (settings tile):** a poorly-chosen `oldString` gutted
  `_ReadReceiptsTile` (left a class with no body); restored the full widget
  and inserted the new tile AFTER it. Insert siblings after the closing
  brace, not by replacing the opening.

## Commands run

```bash
export AGENT_NAME=minigame-invites
tools/agent_lock.sh acquire <path> --owner minigame-invites   # per touched path
flutter gen-l10n
flutter test test/features/minigames/       # 96 pass
flutter test test/features/friends/ test/features/profile/ test/features/notifications/
flutter test test/perf/list_view_builder_test.dart
flutter test test/accessibility/a11y_test.dart
flutter test test/meta/conventions_test.dart
flutter test test/                          # full unit suite: 2452 pass / 0 fail
dart analyze lib test integration_test     # 0 issues
flutter analyze                             # 0 issues
go test ./...                              # green (188)
go vet ./...
bash tools/check_migrations.sh            # layout + parity pass; 140 flagged UNTRACKED until committed
bash -n test/opt-016-minigames-invites.sh  # syntax OK

# NOT run (need the Docker stack + migration 140 applied):
#   bash test/run_all_backend.sh
#   supabase db test
#   bash integration_test/runner.sh
```