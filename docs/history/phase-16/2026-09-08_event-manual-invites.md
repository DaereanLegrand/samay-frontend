# 2026-09-08 — Events Stage 2: manual guest invites (minigame mechanism reuse)

## What was built

### Backend — `060_events/05_manual_invites.sql` (mirrored byte-identical)
- `invite_event_guests(p_event_id, p_invitees[])` — SECURITY DEFINER; the event
  creator or an `event_hosts` host/staff invites specific users. Per-invitee
  gates mirror the minigame family (live user, not blocked either direction,
  self skip, dedupe, cap 20); already-pending/accepted/attended invitees and
  existing host/staff are skipped idempotently. **Seat-reservation capacity**:
  `event_hosts` + every live `event_invites` row + the NEW invitees must fit
  `events.capacity` (`capacity_reached` otherwise). Each insert fires the
  existing `notify_event_invite` trigger (invitee notification).
- `accept_event_invite(p_invite_id)` — invitee (self only, ownership folded
  into the lookup) flips pending → accepted with `responded_at`. Idempotent;
  declined/attended reject; ended/cancelled event → `event_closed`.
- `decline_event_invite(p_invite_id)` — invitee (self) DELETES the pending
  row (2026-09-02 directive: declined = never happened), freeing the seat so
  the host can invite someone else / re-invite the guest as a fresh INSERT.
- RLS on `event_invites`: dropped the legacy client `ei_update_own` (accept/
  decline now live only in the SECURITY DEFINER family) and added
  `ei_read_event_access` (hosts/staff read the full guest roster; everyone
  else keeps `ei_read_own`).
- ACL hardening for the Stage-1 capacity helpers (`event_seats_used`,
  `assert_event_capacity`): they were SECURITY DEFINER without revoking the
  default PUBLIC EXECUTE — revoked now (service_role only). Discovered via the
  pgTAP anon-EXECUTE gate on the reset stack; Stage-1 gap, fixed in this file.

### Flutter
- `EventService`: `inviteEventGuests`, `acceptEventInvite`,
  `declineEventInvite` (typed `AppError` mapping, I-57 jsonb statuses) and
  `getEventGuests` (host/staff roster; `user_search_view` embed disambiguated
  with `!event_invites_user_id_fkey` — the table has two FKs to users).
- `events_providers.dart`: `myEventInviteProvider` gains `accept()`/`decline()`;
  new `eventGuestsProvider` (roster) with `inviteGuests()`.
- New `EventInviteScreen` (thin scaffold over the shared `UserPickerView`,
  mirroring `MinigameInviteScreen`) with an "invitada/sent" tag on users who
  already hold an invite.
- `event_detail_screen.dart`: hosts/staff get the "Invitados" card (per-status
  roster + "Invitar personas"); a PENDING invitee gets the accept/decline card.
- l10n keys added to `app_es.arb` (template) + `app_en.arb`; `flutter gen-l10n`.

## Tests
- `test/opt-025-events-invites.sh` (new, auto-discovered): invite + pending
  rows + notifications (A), idempotent re-invite (B), seat-reservation capacity
  (C), non-host reject (D), decline-frees-seat + re-invite + freed seat admits
  a previously-rejected invitee (E), accept semantics + foreign/deleted-invite
  rejection + `event_seats_used` (F), roster RLS host-vs-outsider (G).
  **PASS=25 FAIL=0.**
- pgTAP: Section 21 policy list updated (own-row + `ei_read_event_access`);
  new Section 21b (RPC presence + no-anon-EXECUTE); `app_config` count fixed
  42 → 46 (Stage-1 +4 capacity keys); plan(934) → plan(938). **All pass.**
- `dart analyze` 0 issues. `opt-024` re-run green (13 PASS).

## MISTAKE blocks
- PostgREST RPC responses now carry whitespace (`{"id": "…"}`); the original
  opt-024 parsing (`grep '"id":"'`) broke after the stack reset. Fixed by
  adding the `norm_json` helper (opt-016 pattern) to opt-024's RPC helpers —
  it was already failing against the reset stack (PGRST202 + `capacity` column
  absent) before Stage-2 started.
- `event_invites` embeds two FKs to `users` (`user_id`, `invited_by_user_id`);
  the first `getEventGuests` embed (`user_search_view!inner`) hit PGRST201
  (ambiguous). Disambiguate: `users:user_search_view!event_invites_user_id_fkey(username)`.
- A helper test asserted `"id":"` on a live create body that omitted several
  `create_event` args → PGRST202; keep the full 15-arg base in scratch probes.

## Commands run (reproducibility)
- `make supabase-testing-reset` (running stack was stale vs the current
  baseline — Stage-1 capacity objects were missing).
- `bash test/opt-025-events-invites.sh`, `bash test/opt-024-events-capacity.sh`
- `make supabase-db-test` (pgTAP 938)
- `dart analyze`, `flutter gen-l10n`
- `psql -f supabase/migrations/060_events/05_manual_invites.sql` (+ live ACL
  hardening statements) after editing both mirrored stacks.

## Follow-ups (NOT in this session)
- Stage 3: host designates staff; Stage 4/5: swirl attendance codes + scanning.
- A standalone invite SHARE screen (invite-token deep link) is still pending
  (`EINV`), distinct from this host-facing guest-invite flow.
