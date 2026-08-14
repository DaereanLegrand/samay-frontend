# Phase 06 — QR System · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-06-qr-system/*` and
> `docs/specs/steps/cross-references.md`. Read-only planning aid for I-49..I-78.

> **I-57 progress (2026-08-09):** QRAT/QRSC **client foundations landed** —
> `lib/features/qr/attendance_qr_screen.dart` (inactive/server-pending/active/
> expired/ended states, 15s countdown ring, rotation refetch — server rotation
> RPC is EEDG/QEDG future work), `lib/features/qr/qr_scanner_screen.dart`
> (permission flow via `PermissionService`, mobile_scanner camera, torch
> toggle, scan → `validate_qr_token` RPC with the QRSC error copy),
> `lib/features/qr/qr_providers.dart`, `EventService.getMyQrToken` +
> `validateQrToken`, RPC migration `20260809000005_qr_validate_rpc.sql`
> (SECURITY DEFINER, search_path='', FOR UPDATE, authenticated-only) mirrored
> in supabase-testing, pgTAP Section 44, routes `/qr/:eventId` +
> `/scanner/:eventId` flag-gated on `AppFeatureFlag.qr` (disabled keeps the
> coming-soon copy). **Remaining (server-side):** `qr-token-manager` +
> `validate-attendance` Edge Functions (QEDG, blocked by EEDG), rotation RPC
> handoff (see `2026-08-09_I57-qr-foundation.md`), invite-screen QR actions,
> opt-test + pgTAP behavioral coverage when the stack is up.

## Summary

Implement the dynamic **attendance QR** system (distinct from the static invite QR
of EINV). Attendees display a QR that rotates every 15 seconds
(`qr.token_valid_seconds`); promotores/co_promotores scan it with the in-app
scanner (`mobile_scanner` package — already in `pubspec.yaml`). All QR operations
go through Edge Functions — no direct DB access from the app.

Key mechanics (from specs):
- QR activates 30 minutes before `starts_at` (`qr.activation_minutes_before`);
  before that the screen shows a countdown to activation.
- One valid token per user per event; rotation invalidates the previous token
  (`expires_at = now()`) and inserts a new one.
- Scanning validates via `validate-attendance` with `SELECT FOR UPDATE` on the
  token row and a single atomic transaction: token update (`scanned_at`,
  `attendance_confirmed`) + `event_attendances` insert + `event_invites` status →
  `attended`. Prevents double-confirmation/double-shard races.
- Late-joining attendees get their first token on demand — no special handling.
- Config keys: `qr.activation_minutes_before` (30), `qr.token_valid_seconds` (15),
  `qr.display_countdown_seconds` (15), `security.max_qr_token_rotations` (20),
  `security.max_failed_qr_validations` (5) — never hardcode.

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `QRAT` | `ECRT`❌, `QEDG`❌, `ROUT`✅, `DSNG`✅ | 2/4 green | ❌ No code |
| `QRSC` | `ECRT`❌, `QEDG`❌, `DSNG`✅ | 1/3 green | ❌ No code |
| `QEDG` | `DATA`✅, `INFR`✅ | 2/2 green | ❌ No Edge Functions |

`QEDG`'s own deps are green — it only needs `supabase/functions/` infrastructure
(shared with EEDG). Client screens additionally need ECRT (an event to show a QR
for) and ROUT.

## Orchestration agents starting here

| Agent | Scope (per ORCHESTRATION.md / FILE-OWNERSHIP.md) |
|-------|--------------------------------------------------|
| I-57 | `lib/features/qr/attendance_qr_screen.dart` + `qr_scanner_screen.dart` (foundation) — **DONE 2026-08-09** (client screens, RPC contract `validate_qr_token`, flag-gated routes; server rotation RPC handed off to QEDG/EEDG) |
| I-49/I-50/I-51 | Feature flags, repository layer, typed REST client (foundations the QR client calls will use) |
| I-52 | Realtime lifecycle (scan confirmation animation on attendee device) |
| I-76 | Backend opt-test scripts (shared with events/chat/photos — QR flows are exercised by opt-002-events) |
| I-77 | pgTAP expansion (event_qr_tokens/event_attendances invariants) |
| I-78 | Full-matrix sweep |

Edge Functions `qr-token-manager`/`validate-attendance` are specced under both
EEDG (Phase 05) and QEDG (Phase 06) — coordinate so they are implemented once.

## Acceptance checklist (from the step specs)

**QEDG (`QEDG-qr-edge-functions.md`):**
- [ ] `POST /functions/v1/qr-token-manager` (JWT): `get_token` — window check (`now() >= starts_at - activation_minutes_before` AND status IN ('upcoming','live')), generate or return valid token; `rotate_token` — invalidate current (`expires_at=now()`), insert new
- [ ] `POST /functions/v1/validate-attendance` (JWT, scanner = promotor/co_promotor): scanner-role check; event window check; `SELECT * FROM event_qr_tokens WHERE token=$token FOR UPDATE`; validate not expired + not already scanned; atomic transaction (token update + attendance insert + invite status→attended); returns `{status:'confirmed', attendeeUserId, confirmedAt}`
- [x] **SQL stand-in landed (I-57):** RPC `validate_qr_token(event_id, token)` (migration `20260809000005`, mirrored in supabase-testing) implements the validate-attendance semantics 1:1 as a SECURITY DEFINER RPC — scanner-role check, window check, `FOR UPDATE`, atomic 3-write transaction, jsonb status contract (`not_promotor`/`not_in_window`/`invalid_token`/`expired`/`already_scanned`/`not_invited`/`confirmed`). The Edge Function remains the QEDG/EEDG deliverable (client already calls the RPC; swapping to the EF is a one-line change).

**QRAT (`QRAT-dynamic-attendance-qr-attendee.md`):**
- [x] Pre-activation state w/ countdown ("El código QR se activará {X} minutos antes del evento")
- [x] Active state: full-screen black QR (white modules), "Samay" center overlay, countdown ring "Nuevo código en: {s}", auto-rotate at 0 (rotation refetch — server rotate RPC pending)
- [x] Post-event state ("El evento ha finalizado...")
- [x] Token fetch cycle: on activation → get current token; countdown from `qr.display_countdown_seconds`; rotate at 0; server-pending + network-error retries w/ "Reintentar"
- [x] Late-join first-token-on-demand path (same get_token path — no special handling)

**QRSC (`QRSC-qr-scanner-promotor.md`):**
- [x] Full-screen camera via `mobile_scanner`, white scan frame, promotor event name, "Escanea el código QR del asistente" + torch toggle (I-57 mission extension of the spec's "no torch" note)
- [x] Success flow: confirmation animation + attendee name, "Listo" after ~2s
- [x] Error cases (exact strings): expired token → "Código QR expirado...", already scanned → "Este código QR ya fue escaneado.", not invited → "El usuario no está invitado a este evento.", window → "El evento no está activo...", network → "Error de conexión. Reintentar..."
- [ ] Realtime confirmation animation on the attendee device (I-52's realtime provider; the attendee-side listen path is future work)

## Phase exit gate

All 3 steps green in cross-references.md; QR routes no longer render
`VComingSoonScreen`; race-condition (double-scan) covered by opt-test; pgTAP
covers token/attendance invariants; full matrix green.
