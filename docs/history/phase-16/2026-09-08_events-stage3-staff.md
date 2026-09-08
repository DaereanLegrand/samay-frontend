# 2026-09-08 — Events Stage 3: host designates staff

## What was built

### Backend — `supabase/migrations/060_events/06_staff.sql` (mirrored
byte-identical into `supabase-testing/`)

- **`designate_event_staff(uuid, uuid[])`** SECURITY DEFINER RPC — the host
  (creator **or** role=host member) adds staff to an event. Gates: auth,
  event open (not ended/cancelled), host-only (`not_host` for staff/outsiders),
  per-candidate live-user gate + self/already-privileged skip (idempotent,
  `added` count), and a **capacity check** against the frozen `events.capacity`
  (host seats + live guest seats + new staff seats). A candidate who already
  holds an `event_invites` row is **converted**: their invite is DELETEd and
  the seat moves into `event_hosts` — seat-neutral, never double-counted
  (mirrors the "declined invite is deleted" semantics of Stage 2).
- **`remove_event_staff(uuid, uuid)`** SECURITY DEFINER RPC — host removes a
  staff row (frees its seat). Idempotent `ok` when the member is already gone;
  the HOST row can never be removed (`host_not_removable`).
- **`ep_insert_host` DROPPED** — the legacy client INSERT policy let an event
  host insert arbitrary event_hosts rows (even role `host`) bypassing capacity.
  event_hosts writes are now exclusively the SECURITY DEFINER RPC family
  (`create_event`, `designate_event_staff`). opt-002 TEST E rewritten: a direct
  INSERT is RLS-denied even for the creator.
- **`ep_read_event_access`** SELECT policy — hosts AND staff read the FULL
  host/staff roster (the "Anfitrión y staff" card), while everyone else keeps
  reading only their own rows (`ep_read_own`).
  - MISTAKE/GOTCHA: a SELECT policy that self-references `event_hosts`
    recurses infinitely (`infinite recursion detected in policy for
    relation`). Verified empirically in the running DB. The membership check
    goes through a **security-barrier view `event_host_access_view`**
    (owner = postgres, rolbypassrls). The view carries NO grants, so no client
    can query it directly — only the RLS policy subquery reaches it.
- **`rotate_qr_token` / `validate_qr_token`** redefined (CREATE OR REPLACE,
  ACLs preserved): the attendee gate now admits `event_hosts` members
  (host + staff) too, not only invited guests — everyone on the event
  generates their own attendance code and can be confirmed (`event_attendances`
  records every confirmed person; the invite flip no-ops for host/staff).

### Flutter

- `EventService.designateStaff` / `removeStaff` (RPC wrappers → typed
  [AppError]s, same style as the Stage-2 invite family).
- `EventHostsNotifier.designateStaff` / `removeStaff` (refresh after mutation).
- `EventStaffScreen` (new) — thin scaffold over the reusable `UserPickerView`,
  excludes existing hosts/staff + self, pops the selection for the host.
- `event_detail_screen.dart` — the "Anfitrión y staff" card now lists every
  host/staff row (avatar + username + role label) instead of bare avatars; a
  role=host member on an open event gets an "Añadir staff" action and a remove
  affordance per STAFF row (confirm dialog). The scanner button now shows for
  staff too (`_isPrivileged` = host OR staff; `validate_qr_token` already
  gates role IN host/staff).
- l10n: 10 new keys (es template + en), regenerated via `flutter gen-l10n`.

### Tests / baselines

- `test/opt-026-events-staff.sh` (new, 34 PASS): designate/idempotency,
  capacity (cap 7 = 1 host + 6 staff), staff/outsider `not_host`, removal +
  host-not-removable + idempotent re-removal, accepted-guest → staff
  conversion is seat-neutral (`event_seats_used` stays 2), staff/host can
  rotate a QR token and a host validates a staff token (confirmed, attendance
  recorded, re-scan `already_scanned`), roster RLS (host reads 3 rows, staff
  reads 3, outsider reads 0).
- pgTAP §20 updated (`event_hosts` policies = ep_read_own + ep_read_event_access)
  + §21c new (designate/remove presence + no-anon-EXECUTE + view + FORCE RLS)
  → **plan(943)**, mirrors synced.
- `test/opt-002-events.sh` TEST E rewritten for the dropped `ep_insert_host`.

## Decisions
- Designate/remove are HOST-only (role=host), not staff-manageable — matches
  "the host can designate staff"; staff already have invite rights from Stage 2.
- Staff designation converts an existing invite instead of double-counting the
  person — capacity stays honest; removing them does NOT resurrect a guest
  invite (consistent with decline-deletes).
- Closed (ended/cancelled) events reject designate/remove (roster is frozen).
- Guests still see only their own `event_hosts` row (i.e. nothing) — roster
  visibility is host/staff-only, by design (matches the Stage-2 guests note).

## Commands run
```
cp supabase/migrations/060_events/06_staff.sql supabase-testing/migrations/060_events/06_staff.sql
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -f supabase-testing/migrations/060_events/06_staff.sql
bash test/opt-026-events-staff.sh            # 34 PASS (RED first: 22 FAIL on missing RPCs)
bash test/opt-002-events.sh                  # 22 PASS
bash test/opt-001-rls-security.sh            # 44 PASS
bash test/opt-003-chat.sh                    # 32 PASS
bash test/opt-024-events-capacity.sh         # 13 PASS
bash test/opt-025-events-invites.sh          # 25 PASS
cp supabase/tests/schema_test.sql supabase-testing/tests/schema_test.sql
make supabase-db-test                        # pgTAP 943/943 PASS
flutter gen-l10n
dart analyze                                 # 0 issues
flutter analyze                              # 0 issues
go test ./...                                # green
bash test/opt-005-seeds-static.sh            # 45 PASS
bash test/opt-007-compose-static.sh          # 1 pre-existing env failure (SERVICE_KEY drift on opt-001..006)
bash tools/check_ports.sh --strict           # STRICT PASS
bash tools/check_secrets.sh                  # PASS
```
pgTAP first reported test-190 ("users table empty") because the LIVE opt runs
leave public.users residue (opt-001 cleans only auth.users); deleted the
leftover test rows and re-ran → clean 943/943.

## Issues found / pre-existing
- opt-007 static gate fails its 8.4.3 "opt-test SERVICE_KEY defaults == .env
  dev value" alignment on opt-001..006 — local `supabase/.env` dev keys were
  rotated after the 2026-08-25 baseline; runtime runs pass. Out of Stage-3
  scope (already noted in README's opt-007 note).
