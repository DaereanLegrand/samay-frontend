# 2026-09-09 — Assisted attendee terminal state ("Ya te registraste")

## What was built

Task C: once a user is **already assisted** for an event, the rotating QR is
never shown again and the Código action is permanently unavailable.

1. **Authoritative assist signal** — `EventService.isAttended(eventId)`
   (`lib/core/services/event_service.dart`): reads the caller's **own**
   `event_attendances` row (`maybeSingle`). That row is the single-confirmation
   marker written by `validate_code` (`060_events/07_code.sql`, step 8). The
   read is RLS-scoped by the pre-existing `ea_read_access` policy
   (`user_id = auth.uid()`), so the client can only see its own row.
2. **Typed provider** — `myAttendanceProvider` (`MyAttendanceNotifier`, a
   `FamilyAsyncNotifier<bool, String>`) in
   `lib/features/events/providers/events_providers.dart`. No raw maps in UI.
3. **Terminal QR state** — `lib/features/qr/screens/attendance_code_screen.dart`
   now gates on `myAttendanceProvider` **before** the code fetch resolves. When
   assisted it renders `_AlreadyAttended`: full-bleed black (consistent with
   `_ActiveCode`), only the floating back affordance (`VHeaderTitleRow`) plus a
   **Regresar** button below the message. No QR, no countdown ring, no code.
4. **Disabled Código action** — `lib/features/events/screens/event_detail_screen.dart`
   watches `myAttendanceProvider`; when assisted the Código button stays visible
   but `onPressed: null` (clearly disabled, no navigation). Scanner (host/staff)
   and Fotos are untouched. The provider is invalidated on detail entry and when
   the roster realtime channel fires (a guest's invite flips to `attended` at the
   same instant their attendance row is written), so the state is live.
5. **l10n** — `codeAlreadyAttended` ("Ya te registraste" / "You're already
   checked in") and `codeAlreadyAttendedReturn` ("Regresar" / "Go back") added
   to `app_es.arb` (template) + `app_en.arb`, regenerated with `flutter gen-l10n`.
6. **Doc-comment fix** — the `_buildConfirmedRoster` comment (and the two other
   roster comments) previously said "invitee of any standing"; corrected to
   "CONFIRMED member (accepted/attended)", matching the Task-B security fix.

No backend/migration change was needed, so opt-027 / pgTAP / the byte-identical
mirrors were **not touched** (Task-B's uncommitted hunks preserved).

## Decisions made and why

- **Signal choice (option b): read own `event_attendances` through RLS via a
  typed provider.** Options were (a) extend `get_my_code` to return
  `already_attended` + a second lightweight read for the detail screen, or
  (b) one typed own-row read via PostgREST/RLS. (b) is the smallest: a single
  provider serves **both** surfaces (terminal QR state + disabled Código),
  it is backend-authoritative (the value is the server's confirmation row, not
  a client guess), and it needs no `CREATE OR REPLACE` on the running DB, no
  mirror edits, and no test-count churn in a tree that currently holds another
  session's uncommitted hunks. The `ea_read_access` policy that permits the
  read is already pinned by pgTAP §23 (`policies_are`).
- **Host/staff rule:** a host/staff member can be confirmed (they have no
  `event_invites` row, so scanning them only writes `event_attendances`). Their
  assisted state is therefore identical to a guest's — Código becomes terminal
  and disabled. Any per-role exception would need a server rule; none is wanted.
- **`event_attendances` is the universal marker, `invite.status='attended'` is
  the guest mirror.** The invite only flips to `attended` inside `validate_code`
  step 8, atomically with the attendance INSERT, so the row covers every case
  (guest + host/staff). We use the row — never the invite status — as the
  authority.
- **Gate on `.when` (loading → spinner) in the QR screen**, not
  `valueOrNull == true`, so an assisted user can never flash a QR while the
  own-attendance read is in flight.
- **Disabled, not hidden, on the detail screen** (explicit user preference):
  the action's existence stays discoverable; only navigation is removed.

## MISTAKE blocks

- **MISTAKE — the invite-status signal alone cannot detect an assisted
  host/staff member.** First instinct was to reuse `myEventInviteProvider`
  (`status == 'attended'`). Hosts/staff have **no** invite row, so their
  attended state would be invisible. The own `event_attendances` row is the
  only role-uniform marker; use it everywhere.
- **MISTAKE — `valueOrNull == true` leaks a QR for one or more frames.** The
  attendance read resolves after the event/code fetches, so checking only the
  resolved value let the active QR render briefly before flipping to terminal.
  The QR screen now branches with `attendedAsync.when` and renders the spinner
  while the assist read is loading.
- **MISTAKE — a cached `FamilyAsyncNotifier` goes stale after a remote scan.**
  The attendee is confirmed by another device; without invalidation the detail
  screen keeps a stale `false`. Invalidated on detail entry and in the
  `event_invites` realtime callback (the same event that flips `attended`).

## Commands run (reproducible)

```bash
export AGENT_NAME=c-assisted
tools/agent_lock.sh list
tools/agent_lock.sh acquire <paths> --owner "$AGENT_NAME"

flutter gen-l10n
dart analyze                                # 0 issues

make build TARGET=android                   # APK built
adb -s localhost:5565 install -r build/app/outputs/flutter-apk/app-debug.apk  # Success
adb -s localhost:5565 shell monkey -p com.qallariy.samay -c android.intent.category.LAUNCHER 1
```

## Issues found / out of scope

- No backend change → opt-027 / pgTAP / mirrors intentionally untouched; the
  running 54382 DB was not modified.
- Concurrent minigame-session hunks (`minigame_service`, `minigames/**`,
  `207_*`, `opt-020/021/023*`, `DATABASE.md`, `README.md`, `schema_test.sql`
  and mirror) and Task-B's uncommitted hunks were preserved; only the lines
  Task C needs were edited.
- Ready for tap-verification on `localhost:5565`.

---

## Hardening follow-up (same day, auditor H1/H2/H3)

The auditor passed Task C but flagged residual risks to its core guarantee
("once assisted, Código can never be pressed/openable again"). Addressed H1–H3.

### H1 — stale `myAttendanceProvider` could show a stale QR

The provider was a non-autoDispose family, so a `false` cached earlier in the
session survived a remote scan, and a `qr_active` notification deep-link to
`/qr/:eventId` (`notifications_providers.dart`) bypasses the detail screen's
entry invalidation — the QR screen could render a stale QR.

- `myAttendanceProvider` is now `AsyncNotifierProvider.autoDispose.family`
  (`MyAttendanceNotifier extends AutoDisposeFamilyAsyncNotifier<bool, String>`),
  matching Task A's `myCodeProvider` pattern.
- The QR screen invalidates it post-frame in `initState`, so every open re-reads
  the `event_attendances` row even when the screen is pushed over a still-mounted
  detail (autoDispose alone would keep the cached value alive).
- The detail screen keeps its entry invalidation (was already present), so
  Código disables correctly after a remote scan + re-entry.
- No fallback introduced: the attendance row remains the only authority.

### H2 — host/staff live flip (backend realtime, done properly)

Only `event_invites` invalidated the provider; host/staff confirmation writes
ONLY `event_attendances`, so an open screen did not live-flip.

- `event_attendances` gets `REPLICA IDENTITY FULL` (`060_events/08_realtime.sql`)
  and joins `supabase_realtime` (`960_realtime/realtime_publications.sql`),
  mirroring the `event_hosts`/`event_invites` pattern exactly.
- `RealtimeService.subscribeToEventAttendances(eventId, …)` — filtered to
  `event_id = <uuid>`; RLS (`ea_read_access`) gates delivery: a caller always
  receives their own row, plus all the event's rows when host/staff or a group
  member. No new data exposure (the same policy already permitted the SELECT).
- The detail screen's `_syncRosterRealtime` now owns a third channel
  (`_attendancesChannel`, unsubscribed on dispose/member-loss) that invalidates
  `myAttendanceProvider`. Because the detail remains mounted under a pushed QR
  route, the QR screen flips live too.
- Both mirrors updated byte-identically; applied to the running 54382 DB
  (`ALTER TABLE … REPLICA IDENTITY FULL` + guarded publication add).
- pgTAP Section 21g: +2 assertions (publication membership + `relreplident='f'`);
  `plan(951)` → `plan(953)`. No opt-test assertion added: Realtime delivery
  cannot be meaningfully exercised by curl (REST) — pgTAP is the correct layer
  for the schema/publication posture, so the 2-layer budget (Flutter analyze +
  pgTAP) holds.

**Known limitation (documented, not a fallback):** a `/qr/:eventId` deep-link
that bypasses the detail screen has no `event_attendances` channel open, so it
will not live-flip while the user stares at the QR; it re-reads correctly on
open (H1) and the scanner's confirmation appears on the next open. Adding a
screen-level channel there was judged disproportionate for the remaining edge.

### H3 — stale spec text

`docs/specs/steps/cross-references.md`: the `EDET` row's "invitee of any
standing sees the organizer list" corrected to "a CONFIRMED invitee
(accepted/attended; a pending invitee reads no roster)".

### Commands run (hardening)

```bash
export AGENT_NAME=c-assisted
tools/agent_lock.sh acquire <paths> --owner "$AGENT_NAME"

dart analyze                                # 0 issues
bash test/opt-027-events-code.sh            # PASS=37 FAIL=0
bash test/opt-025-events-invites.sh         # PASS=30 FAIL=0
make supabase-db-test                       # 953 assertions; only pre-existing test 210 (users empty) fails

PGPASSWORD=postgres psql -h 127.0.0.1 -p 54382 -U postgres -d postgres \
  -c "ALTER TABLE ONLY public.event_attendances REPLICA IDENTITY FULL;" \
  -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='event_attendances') THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.event_attendances; END IF; END \$\$;"

make build TARGET=android
adb connect localhost:5565
adb -s localhost:5565 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s localhost:5565 shell monkey -p com.qallariy.samay -c android.intent.category.LAUNCHER 1
```
