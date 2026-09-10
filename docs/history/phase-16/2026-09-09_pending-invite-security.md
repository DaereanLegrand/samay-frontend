# 2026-09-09 — A PENDING invitee is NOT an attendee (security)

## What was built

The attendance-code flow treated **any** live `event_invites` row — including
`pending` — as attendee membership. A merely-invited person could open Código,
mint a rotating QR, and be scanned as attendee (the scan flipped their invite
`pending → attended`), and could read the organizer + confirmed rosters. Fixed
end-to-end:

1. **`get_my_code` attendee gate** (`060_events/07_code.sql`): an attendee is
   host/staff (`event_hosts`) OR an invite with `status = 'accepted' OR status
   = 'attended'`. A `pending` row → `not_invited`.
2. **`validate_code` step 6** (same file): the target attendee must satisfy the
   same rule — a target whose only invite row is `pending` answers
   `not_invited`, never `confirmed`, and no write happens. Host/staff (no invite
   row) stay valid.
3. **`event_attendances` is never written for a pending invitee** — enforced by
   (2) returning before the INSERT/UPDATE (proved in opt-027 TEST C2).
4. **Member roster tightened** (`060_events/09_attendee_roster.sql`):
   `event_roster_membership_view` now projects only CONFIRMED memberships
   (`accepted`/`attended`), so a pending invitee no longer reads the organizer
   roster (`ep_read_member_roster`) nor the confirmed-attendee roster
   (`ei_read_confirmed_roster`). `ei_read_own` is untouched — a pending user
   still reads their own row for the accept/decline card.
5. **Flutter UI** (`lib/features/events/screens/event_detail_screen.dart`):
   a pending invitee (own invite `pending`, not host/staff) sees only the
   accept/decline card — `_buildLiveActions` early-returns (no Código, no
   Fotos), the host/organizer card and the confirmed-roster card are hidden,
   and `_syncRosterRealtime` no longer subscribes them (confirmed membership
   only). New helpers `_isConfirmedMember` / `_isPendingInvite`.

Mirrors (`supabase-testing/migrations/060_events/07_code.sql`,
`09_attendee_roster.sql`) updated byte-identically (verified with `diff`).

## Decisions made and why

- **Reused the existing `event_roster_membership_view`** rather than adding a
  second policy predicate. The view is the single recursion-free membership
  projection; adding the status filter there tightens both member-read policies
  at once and keeps `ei_read_own` intact.
- **Explicit `status = 'accepted' OR status = 'attended'`** (not `IN (...)`) in
  the RPC bodies so `pg_get_functiondef` deparses to a stable, greppable form
  for the pgTAP assertion (`pg_get_functiondef` rewrites `IN` to
  `= ANY (ARRAY[...])`).
- **opt-027 TEST C2 seeds the leak scenario via accept → mint → revert-to-
  pending**: `event_code_keys` is intentionally unreadable/unwritable by
  `service_role` through PostgREST (zero client grants), so the test mints a
  real code while temporarily accepted, then uses `service_role` PATCH to put
  the invite back to `pending` and proves the host scan still answers
  `not_invited` with no attendance row and the invite left `pending`.
- **opt-025 TEST H updated** (not just opt-027): its old assertion that a
  pending invitee reads "own pending + D's accepted" encoded the vulnerable
  behavior. Rewritten to confirmed-membership-only (pending B sees only their
  own row, plus a new assertion that pending B reads zero `event_hosts` rows).

## MISTAKE blocks

- **MISTAKE — `REVOKE ALL ON event_code_keys FROM service_role` means the opt
  test cannot seed a pending invitee's key via PostgREST.** First instinct was
  `svc_post event_code_keys`; that 403s. Had to structure the RED test around a
  real mint + revert. Keep this in mind for any future code-key test.
- **MISTAKE — pgTAP cannot assert the source text of an `IN (...)` gate.**
  `pg_get_functiondef` normalizes `status IN ('accepted','attended')` to
  `= ANY (ARRAY[...])`. Wrote the RPC conditions as explicit ORs so the
  assertion pattern (`%status = ''accepted'' OR status = ''attended''%`) is
  stable; the view (SQL view, not plpgsql) deparses with `::invite_status`
  casts, so its assertion matches that form.

## Commands run (reproducible)

```bash
export AGENT_NAME=b-security
tools/agent_lock.sh list
tools/agent_lock.sh acquire <paths> --owner "$AGENT_NAME"

# RED (old DB): 5 failures matching the flaw
bash test/opt-027-events-code.sh            # PASS=32 FAIL=5

# Apply the fixed RPCs + view to the running 54382 DB (CREATE OR REPLACE,
# ACLs re-asserted: authenticated/service_role EXECUTE, no anon/PUBLIC)
PGPASSWORD=postgres psql -h 127.0.0.1 -p 54382 -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -f /tmp/.../apply_pending_invite_fix.sql

# GREEN
bash test/opt-027-events-code.sh            # PASS=37 FAIL=0
bash test/opt-025-events-invites.sh         # PASS=30 FAIL=0
bash test/opt-026-events-staff.sh           # PASS=34 FAIL=0

# pgTAP: 951 assertions; only the known pre-existing "users table empty"
# (test 208) fails
make supabase-db-test

# Flutter
dart analyze                                # 0 issues
make build TARGET=android
adb -s localhost:5565 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s localhost:5565 shell monkey -p com.qallariy.samay -c android.intent.category.LAUNCHER 1
```

## Issues found / out of scope

- Pre-existing pgTAP failure `users table empty after init/reset` (test 208) —
  unrelated to this change, left as-is.
- Concurrent minigame session's uncommitted hunks (`207`, `minigame_service`,
  `opt-020/021/023`, `DATABASE.md`, the `plan(948)`/`last_tap_at` README text)
  were preserved; only the lines this change needs were edited.
