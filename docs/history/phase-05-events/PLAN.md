# Phase 05 — Events · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-05-events/*` and
> `docs/specs/steps/cross-references.md`. Read-only planning aid for I-49..I-78;
> the step specs remain the authoritative reference.

## Summary

Build the event lifecycle: a multi-step creation wizard (Casual / Juerga / Tono),
event detail + edit screens, an event status machine (draft → upcoming → live →
ended, cancelled), invite links + static invite QR, and the Deno Edge Functions
that run lifecycle operations (`event-status-poll`, `shard-distribution`,
`qr-token-manager`).

Key mechanics (from specs):
- `invite_token` (random UUID) generated on submit; a `chats` row with
  `type='event'` and `reference_id=event.id` is auto-created.
- Preshard pool only for Juerga/Tono (Casual forced to 0 by DB CHECK constraint);
  `dynamic_qr_enabled` maintained by trigger when pool > 0.
- Daily event creation limits from `app_config`: `events.free_daily_limit` 3,
  `events.pro_daily_limit` 10, `events.vip_daily_limit` 100 — never hardcoded.
- Cancellation returns the full preshard contribution to each promotor
  (`preshard_ledger`, `reason=event_pool_returned`).
- Shard distribution: `expected_per_user = min(floor(P/Y), cap)`, remainder
  `return` vs `redistribute`, 3 retries with exponential backoff, pool-integrity
  check per attempt, `preshards_distributed` guard.
- Status transitions are cron-driven (`events.status_poll_cron`, default `* * * * *`).

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `ECRT` | `AUTH`⚠️, `GROU`⚠️, `SBAS`✅, `DSNG`✅, `DATA`✅, `ROUT`✅ | 4/6 green | ❌ No code |
| `EDET` | `ECRT`❌, `SBAS`✅, `DSNG`✅ | — | 🔄 I-55 landed the screens (2026-08-09); ECRT still has no code, so EDET's data layer is provider/service-only (fixtures in tests) — server-side cancel pool-return + invitee/QR actions deferred to EEDG/EINV/ESTA |
| `ESTA` | `ECRT`❌, `EEDG`❌, `DATA`✅ | — | ❌ No code, blocked by `EEDG` |
| `EINV` | `ECRT`❌, `ROUT`✅, `DSNG`✅ | — | ❌ No code |
| `EEDG` | `DATA`✅, `INFR`✅, `CRON`✅ | 3/3 green | ❌ No Edge Functions (`supabase/functions/` absent) |

Critical path into this phase: `REPO→INFR→DATA→SBAS→AUTH→GROU→ECRT` — GROU ⚠️
(missing promotor-transfer/co-promotor UI) does not block ECRT per the dep graph,
but AUTH's missing pieces (avatar upload, OTP UX) are not ECRT blockers either.

## Orchestration agents starting here (I-49..I-78)

| Agent | Scope (per ORCHESTRATION.md / FILE-OWNERSHIP.md) |
|-------|--------------------------------------------------|
| I-49 | Feature flags + release gating provider (pre-req for gated shipping) |
| I-50 | Repository layer (providers → repos → services) |
| I-51 | Typed REST client wrapper (PostgREST envelope) |
| I-52 | Realtime lifecycle provider (reconnect/backoff) — needed by ESTA reactive updates |
| I-54 | `lib/features/events/create_event_screen.dart` (ECRT foundation) |
| I-55 | `lib/features/events/event_detail_screen.dart` + `event_edit_screen.dart` (EDET foundation) |
| I-66 | Deep-link handler (`samay://`) — needed for invite links (EINV) |
| I-72/I-73/I-74 | Pagination / form validation / shared state widgets (wizard form needs these) |
| I-76 | `test/opt-002-events.sh` (backend opt-test) |
| I-77 | pgTAP expansion for new event migrations |
| I-78 | Full-matrix sweep |

Note: `EEDG` Edge Functions are not covered by a single I-agent in the 4.2 list —
I-76's backend opt-tests and I-77's pgTAP will pressure-test whatever lands;
flag to the orchestrator if an EEDG agent needs to be dispatched.

## Acceptance checklist (from the step specs — do not expand scope)

> **ECRT status (I-54, 2026-08-09):** foundation landed —
> `create_event_screen.dart` + `event_form_data.dart` wired to
> `/group/:groupId/create-event`; details in
> `docs/history/phase-05-events/2026-08-09_I54-event-create.md`.

**ECRT (`ECRT-event-creation-flow.md`):**
- [x] Type selector (Casual / Juerga / Tono cards)
- [x] Details step: name, description, starts_at/ends_at (ends > starts), location → `location_name`/`lat`/`lng`, optional cover upload to `events/{event_id}/cover`
- [x] Visibility (public vs group-scoped from user's promotor/co_promotor groups) + join_mode (open/approval, public only; group-scoped → NULL)
- [x] Juerga location warning modal, explicit confirm
- [x] Preshards config (Juerga/Tono only): pool from own balance, optional cap, remainder action; hidden + forced 0 for Casual
- [ ] Invite promotores step (creator auto-promotor, roles promotor/co_promotor) — deferred (needs EINV/EDET)
- [x] Submit: validation + daily-limit check from `app_config`; inserts `events` (upcoming or draft) + `event_promotores` + `chats`; generates `invite_token`; static invite QR available
  - ⚠ `createEvent` already performs the 3-table insert + `invite_token` + `dynamic_qr_enabled` derivation; the **daily-limit check** and **static QR rendering** remain open (EEDG/EINV/I-55).

**EDET (`EDET-event-detail-edit.md`):**
- [x] Detail screen: cover, name/desc/type badge, date range, tappable location, pool status, promotores row w/ roles, attendees, own invite status, context actions (invitee: accept/decline/QR; promotor: edit/cancel/scanner; co_promotor: scanner/attendees), tabs "Invitados/Chat/Fotos", status badge colors — **I-55 (2026-08-09)**: cover/name/desc/type+status badges/date range (intl, locale-aware)/pool status/promotores w/ roles/own invite status/edit+cancel (promotor, pre-live)/status colors landed. **Deferred to EINV/QRAT/ESTA:** invitee accept/decline/QR, promotor scanner, co_promotor scanner/attendees, tabs, maps-launch (needs `url_launcher` direct dep — flagged).
- [x] Edit (promotores, pre-live): name/desc/cover/location/visibility/join mode; pool/cap/remainder until starts_at; invitee add/remove → push notifications — **I-55 (2026-08-09)**: name/desc/location/dates + pool/cap/remainder (editable until `starts_at`, hidden for casual, lock notice after) landed. **Deferred:** cover upload (EINV/ECRT media path), visibility/join-mode pickers, invitee add/remove → push (EINV). I-54's `event_form_data.dart` reuse once ECRT lands.
- [x] Post-live: read-only except cancel (confirmation → cancelled → preshard return) — **I-55 (2026-08-09)**: cancel button hidden for ended/cancelled; cancel confirm dialog → `status=cancelled` via `EventService.updateEvent`. ⚠ **Pool return is server-side (Go admin `CancelEvent` / EEDG)** — client has no refund path; flagged for S-07/EEDG.
- [x] Co_promotor capability limits enforced — **I-55 (2026-08-09)**: co_promotores get no edit/cancel buttons; scanner/attendees deferred to QRAT.

**ESTA (`ESTA-event-status-machine.md`):**
- [ ] Status display per state (draft/upcoming/live/ended/cancelled) incl. countdown + "En vivo" + collage window + cancel banner w/ reason
- [ ] Realtime subscription to `events` changes; subtle transition animation
- [ ] Cancellation flow: confirm dialog (warns preshard return + invitee notification), reason input, preshard return + `preshards_pool=0`
- [ ] CLI cancellation path (`samay events cancel`) already exists — audit-logged

**EINV (`EINV-event-invites-static-qr.md`):**
- [ ] `invite_share_screen.dart`: `samay://event/{invite_token}` link, system share sheet, static QR via `qr_flutter` w/ "Samay" center overlay, exportable, "solo para compartir" notice
- [ ] Invite acceptance: open mode (auto invitee, status pending), approval mode (promotor approves/declines w/ notifications), group-scoped (explicit invites only)
- [ ] `invite_management_screen.dart`: statuses list, add/remove invitees, copy link, revoke notification
- [x] Deep link `samay://event/{invite_token}` → event lookup — **I-66 (2026-08-09)**: the `/event/:inviteToken` vs `/event/:eventId` route shadowing is RESOLVED — ONE `/event/:eventId` route branches by param shape (UUID → detail as today; token → `EventInviteRoute` resolve via `EventService.getEventByInviteToken` → detail/not-found/error); `DeepLinkHandler` + `deepLinkStreamProvider` seam + `DeepLinkListener` + **app_links ^7.0.0** wired in main.dart (stream-only; initial link delivered once via `uriLinkStream`); platform config (Android intent-filter / iOS Associated Domains, placeholder host `app.samay.example.com`) is **M-27/M-28 handoff** — see `docs/history/phase-05-events/2026-08-09_I66-deep-links.md`. Full suite 1462/0.

**EEDG (`EEDG-edge-functions-event-lifecycle.md`):**
- [ ] `event-status-poll` (upcoming→live, live→ended on `events.status_poll_cron`)
- [ ] `shard-distribution` (triggered on status→ended): expected_pool snapshot, Y/N counts, N=0 full return, per-user math w/ cap, remainder split, ledger entries, pool=0 + distributed=true, promotor push, retry 3× backoff, integrity abort w/ admin_audit_log
- [ ] `qr-token-manager` (initial batch 30 min before, rotate w/ `qr.token_valid_seconds`, validate w/ `SELECT FOR UPDATE` + atomic 3-write transaction) — shared with Phase 06 QEDG

## Phase exit gate

All 5 steps green in cross-references.md (update after implementation), all
screens replacing their `VComingSoonScreen` placeholders, opt-002 + pgTAP green,
`flutter test` + `dart analyze` + `go test ./...` passing.
