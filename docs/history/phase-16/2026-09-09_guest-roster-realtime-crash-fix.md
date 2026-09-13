# 2026-09-09 — QR entry crash + Invitados roster staleness (device-test round)

Session: agent `qr-realtime-fix`. Two device-test bugs after commit `55aee2c`
(attendee QR restyle) + `a0e9d07` (QR 300→250):

1. **Invitee taps Código → crash** `dependOnInheritedWidgetOfExactType
   <UncontrolledProviderScope>() ... before initState() completed` at
   `_AttendanceCodeScreenState.initState` — `ref.invalidate` is illegal there.
2. **Host's "Invitados" list never showed the invitee**, not even after the
   invitee accepted on their own device.

## What was built

### 1. QR crash — post-frame invalidate (attendance_code_screen.dart)
`ref.invalidate(myCodeProvider(eventId))` moved out of `initState` into a
post-frame callback (the repo's `login_screen` pattern). The intent survives:
every entry re-issues the session from the server so a stale in-memory window
can't freeze the first QR. Ref writes are only legal once the element has
joined the inherited `ProviderScope`.

### 2. Guest-roster staleness — realtime (industry-standard fan-out)
Root cause investigation: `opt-025` (25/25) proved the backend invite/accept/
decline/RLS pipeline is correct — the bug was **client-side cache staleness**:
`eventGuestsProvider` is non-autoDispose, fetched once, with no push seam and
no refetch-on-reopen, and the post-invite refresh is throttle-skippable
(15s window). An invitee accepting on their own device therefore never reached
the host's open screen. This is exactly the class of bug the codebase already
solves with Supabase Realtime (friendships 2026-08-14, group_members 2026-08-17,
minigame_sessions 2026-09-02) — the roster was simply never wired in.

Fix (matches that pattern):
- **Migration `060_events/08_realtime.sql` (mirrored byte-identical into
  `supabase-testing/`)**: `event_invites` REPLICA IDENTITY FULL so UPDATE/
  DELETE realtime payloads carry the full row (the filtered channel needs
  `event_id` present in every record).
- **`960_realtime/realtime_publications.sql` (both stacks)**: guarded
  `ALTER PUBLICATION supabase_realtime ADD TABLE event_invites` (idempotent).
- **pgTAP Section 21e** (+2 assertions, plan 940→942, both test mirrors):
  publication membership + REPLICA IDENTITY FULL.
- **`realtime_service.subscribeToEventInvites(eventId, onChange)`**: one
  event's `event_invites` stream, INSERT/UPDATE/DELETE, filtered
  `event_id = <uuid>`, RLS-gated delivery (host/staff full roster, invitee
  own row only).
- **`event_detail_screen.dart`**: while the current user is host/staff of the
  event the screen subscribes the `event-invites:<eventId>` channel and
  invalidates `eventGuestsProvider` on every event → remote accept/decline
  flips the "Invitados" list live. Subscribe lifecycle is ref.listen-driven
  (hosts resolve, staff added/removed, account switch) and dispose-safe
  (in-flight join unsubscribes rather than leaking).
- **Entry refetch**: every mount post-frame invalidates
  `eventGuestsProvider` + `myEventInviteProvider`, so a re-opened detail is
  never a stale cache (the Reconciliation leg of the pattern).

Realtime is best-effort by design; pull-to-refresh / entry-refetch / the
host's own action refresh remain the fallback (failures are logged).

## Tests
- `dart analyze` (touched Dart files) — 0 issues.
- `make supabase-db-test` (pgTAP, live testing stack): 942 tests run;
  **the single failure is pre-existing test 200** ("users table empty after
  init/reset") — real device user rows exist in the testing DB, unrelated to
  this change. The two new Section 21e assertions pass.
- `bash test/opt-025-events-invites.sh` — 25/25 (regression).
- Migration mirrors: `diff -rq` clean across `supabase/migrations` and
  `supabase-testing/migrations` + tests.

## MISTAKE blocks

> **MISTAKE** First version of `subscribeToEventInvites` was written `async`
> and awaited — the lint `await_only_futures` flagged the non-Future
> `RealtimeChannel` return. Realtime joins are fire-and-forget
> (`channel.subscribe()` is async internally); only `unsubscribe()` returns a
> Future worth awaiting (and only in the in-flight-cancel branch).

> **MISTAKE** I initially considered only "refetch on reopen" (the Minimal
> option). That would NOT have fixed the reported symptom — the host is
> watching the open Invitados list while the invitee accepts elsewhere; only a
> push seam updates that screen. The user's question ("how do games/industry
> implement this") correctly pushed toward authoritative-state + narrow
> pub/sub + reconciliation, i.e. the realtime path this codebase already used
> for friendships/groups/minigame sessions.

## Commands
```
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase-testing/migrations/060_events/08_realtime.sql
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase-testing/migrations/960_realtime/realtime_publications.sql
make supabase-db-test        # 942 subtests; only pre-existing #200 (user rows) fails
bash test/opt-025-events-invites.sh   # 25/25
dart analyze lib/core/services/realtime_service.dart lib/features/events/screens/event_detail_screen.dart lib/features/qr/screens/attendance_code_screen.dart
diff -rq supabase/migrations supabase-testing/migrations   # clean
diff -rq supabase/tests supabase-testing/tests             # clean
```

---

## Session B (same day) — accept didn't reflect on the inviter's screen; no attendee-side roster

Second device-test round: on the host the accept now shows as "aceptada" (realtime),
but the ACCEPTING user's own screen only got the snackbar — the pending
"Aceptar"/"Rechazar" card lingered until a later re-entry — and the attendee saw
no participant list nor host/staff list (which they require, realtime).

### 1. Own accept/decline never flipped the pending card (definite bug)
`MyEventInviteNotifier.accept()/decline()` called the THROTTLED `refresh()`
(15s skip window). Accepting within that window → no reload → stale pending card
kept rendering. Fix: accept/decline now invalidate the own-invite provider
DIRECTLY (`ref.invalidateSelf()`, bypassing the throttle), matching the mixin's
own doctrine that "action results never get throttled". The card flips to
"Tu invitación: aceptada" the moment the RPC returns.

### 2. Attendee roster — "confirmed people only" (directive, option chosen)
Industry-standard confirmed-people-only visibility for event members:
- Migration `060_events/09_attendee_roster.sql` (mirrored):
  - `event_roster_membership_view` — security-barrier view projecting the
    events the CALLER belongs to (own `event_invites` rows), owner-run so RLS
    policies can reference it without the event_hosts↔event_invites recursion
    (same trick as `event_host_access_view`). Grants anon/authenticated/
    service_role; REVOKE FROM PUBLIC.
  - `event_hosts` REPLICA IDENTITY FULL.
  - `ep_read_member_roster` (event_hosts): invitees read the organizer roster.
  - `ei_read_confirmed_roster` (event_invites): members read the event's
    accepted/attended rows only — other people's pending stays invisible.
- `960_realtime`: `event_hosts` joins `supabase_realtime` (guarded).
- pgTAP Section 21f (+5: view + 2 policies + event_hosts replica identity +
  publication), policy-list arrays updated (Sections 20/21), plan 942→947.
- opt-025 **TEST H** (29/29): accepted attendee D reads ONLY its confirmed row
  (no pending leak); pending invitee B reads own pending + D's accepted (2 rows);
  member D reads the organizer roster; outsider X reads zero invite AND zero
  event_hosts rows.
- Client (`event_detail_screen.dart`): the detail now subscribes BOTH
  `event-invites:<eventId>` and `event-hosts:<eventId>` channels while the
  viewer BELONGS to the event (host/staff OR any invitee) — listeners drive the
  channels off hosts + own-invite + auth state; realtime invalidates
  `eventGuestsProvider`/`myEventInviteProvider` (guests) and
  `eventHostsProvider` (hosts). A NON-privileged member gets a read-only
  "Asistentes" card (`_buildConfirmedRoster` — confirmed rows only); the
  organizer "Anfitrión y staff" card now populates for members too. Realtime
  service gains `subscribeToEventHosts`. New l10n:
  `eventAttendeesTitle/Empty/LoadError` (es/en).
- Fixed by Session A's migration 08 too: the own accept flips the attendee into
  the confirmed list via realtime + entry refetch.

### Tests (Session B)
- `dart analyze` whole repo — 0 issues.
- pgTAP plan(947) exact (only pre-existing env test 205 — "users empty" — fails).
- opt-025 29/29.

## MISTAKE blocks

> **MISTAKE** I initially "fixed" the attendee-UI report by assuming the host
> card was intentionally host-only ("guests see none here") — but the user
> explicitly required attendees to see participants + organizers, live. The
> clean pattern (confirmed-people-only RLS + per-event realtime channels for
> members) is what events apps do; ask first, don't assume the old comment was
> the intent.

> **MISTAKE** Postgres RLS would reject a policy cycle the moment both
> `event_hosts` and `event_invites` policies reference each other's base
> tables (infinite recursion at query time). Routing the membership check
> through an owner-run security-barrier VIEW avoids it — verified behaviorally
> by opt-025 TEST H rather than trusting a comment.

## Commands (Session B)
```
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase-testing/migrations/060_events/09_attendee_roster.sql
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase-testing/migrations/960_realtime/realtime_publications.sql
bash test/opt-025-events-invites.sh   # 29/29
make supabase-db-test                 # plan(947)
flutter gen-l10n
dart analyze                          # 0 issues
diff -rq supabase/migrations supabase-testing/migrations
diff -rq supabase/tests supabase-testing/tests
```

---

## Session C (same day) — accept/decline must stay busy-locked

Requirement: tapping "Aceptar"/"Rechazar" must show loading on BOTH buttons and
lock them until the RPC (plus the state refresh) is done — a double-tap into a
stale window previously re-sent accept → server `already_accepted`.

The buttons already shared a single `_inviteBusy` lock
(`_buildInviteActions`: both `loading: _inviteBusy`, `onPressed: null` while
busy). The gap: `_acceptInvite`/`_declineInvite` cleared busy as soon as the
RPC returned, while `MyEventInviteNotifier`'s `ref.invalidateSelf()` reload was
still async — the pending card (retained old value) remained tappable for one
network round trip. Fix: `accept()`/`decline()` now `await
ref.read(myEventInviteProvider(arg).future)` after invalidating, so the method
returns only once the reloaded invite reflects the new state; the busy lock
therefore spans RPC + reload and the card flips (accepted row / gone) while the
spinners are still up. No double-tap window remains.

## Commands (Session C)
```
dart analyze     # 0 issues
```


