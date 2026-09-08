# 2026-09-08 — Events Stage 4: animated swirl attendance code (attendee side)

## What was built

### Backend — `060_events/07_swirl.sql` (mirrored byte-identical)
- `event_swirl_keys(event_id, user_id, secret)` — ONE random 32-byte HMAC
  secret per (event, attendee), issued lazily inside the activation window.
  FORCE RLS with **zero client policies and zero table grants** (the only
  handle is the SECURITY DEFINER RPC). UNIQUE (event_id, user_id); secret
  CHECK `^[0-9a-f]{64}$`.
- `event_swirl_code(secret text, counter bigint)` — immutable SQL helper:
  `left(hex(hmac_sha256("samay.swirl.v1:" || counter, secret)), 24)`. Grant:
  service_role only (opt cross-check), never PUBLIC.
- `get_my_swirl_code(p_event_id)` — attendee issue (host/staff/live invite
  gate + activation window via `qr.activation_minutes_before`). Returns
  `{code, secret, counter, windowSeconds, windowStart, windowEnd}` so the
  device regenerates windows locally (authenticator style).
- `validate_swirl_code(p_event_id, p_code)` — host/staff-only; recomputes
  every attendee secret for counter ±1 (clock-skew tolerance) and confirms
  ONCE: `event_attendances` is the single-confirmation marker, guests' invite
  flips to `attended`. Statuses `not_host/not_in_window/invalid_code/
  not_invited/already_scanned/confirmed`.
- Key-purge triggers on `event_invites` DELETE (declined / converted) and
  `event_hosts` DELETE (removed staff) → a revoked attendee's code dies
  instantly (guest→staff conversion purge is a benign forced refresh).
- `swirl.window_seconds` (30) added to both seed-config.sql copies (app_config
  46 → 47 rows).

### Flutter — attendee swirl replaces the attendee QR
- `lib/features/qr/logic/swirl_code.dart` — `SwirlSession`/`SwirlFetch` +
  `deriveSwirlCode` (HMAC-SHA256 via the existing `cryptography` dep),
  byte-identical to the SQL helper.
- `lib/features/qr/providers/swirl_providers.dart` — `mySwirlSessionProvider`.
- `lib/features/qr/widgets/swirl_pattern_view.dart` — the animated pattern:
  24 radial-length tick bars over 24 sectors encode the 24 hex digits (16
  radial steps between two faint anchor rings; cyan origin dot). Whole field
  rotates/breathes; code regeneration is a 900 ms bar-length morph (no hard
  swap). Encode contract documented for the Stage-5 decoder (radial scheme
  chosen over angular: an angular 16-state layout lands sub-pixel per state).
- `lib/features/qr/screens/attendance_swirl_screen.dart` — replaces
  `attendance_qr_screen.dart` (deleted). Countdown ring + hex readout;
  derives the next window locally at the boundary via a 1 s ticker.
- `EventService`: `getMySwirlCode` added; legacy `getMyQrToken`/`rotateQrToken`
  removed (client-side dead after the QR attendee screen went away).
- `qr_providers.dart` trimmed to the scanner mapping; router + auth-scope
  reset switched to the swirl screen/provider; l10n: dead attendee-QR keys
  removed, `swirl*` keys added (es template + en), `flutter gen-l10n`.

## Tests
- `test/opt-027-events-swirl.sh` (new, auto-discovered): issue + determinism +
  per-user distinctness + helper cross-check (A/B), outsider/attendee gates
  (C), `not_in_window` before activation (D), staff attendee parity + single
  confirmation (E), guest invite-flip + fresh-window double-confirm blocked
  (F), malformed/unmatched codes (G), secret never leaks via REST (H).
  **PASS=28 FAIL=0.**
- pgTAP: new Section 21d (+10 asserts), plan(943) → plan(953); `app_config`
  count 46 → 47. **All pass.**
- `flutter analyze` 0 issues.

## MISTAKE blocks
- The swirl fetch listener originally called `setState` on first frame inside
  `build` (a ref.listen fires post-frame). Anchor inline in the data branch
  instead (`_applySession` without setState); the listener re-anchors only on
  real code changes.
- `field_of` (helper taking `$1` as the JSON) was piped stdin in one call →
  `$2 unbound`. Pass the JSON as the argument like the rest.
- A stray l10n edit duplicated `qrEventEnded` in `app_es.arb` before the block
  was removed — caught by re-reading the region before regenerating. Always
  re-read the arb region after multi-key deletions.
- Initial swirl "encoder" idea (angular 16-phase dots on one ring) would land
  at ~0.9° per state → sub-pixel at arm's length, unreadable by a camera.
  Switched to 16 discrete RADIAL steps (each >4px at display size). Documented
  in `swirl_pattern_view.dart` so Stage 5 builds on the radial contract.

## Commands run (reproducibility)
- `bash test/opt-027-events-swirl.sh` (RED: PGRST202 before the migration)
- `cp supabase/{seed-config.sql,migrations/060_events/07_swirl.sql}` →
  `supabase-testing/...` (mirrors)
- `psql -p 54382 -f supabase-testing/migrations/060_events/07_swirl.sql` +
  `-f seed-config.sql` (supabase-testing stack)
- `supabase db test --db-url ".../postgres?sslmode=disable"` (pgTAP 953)
- `flutter gen-l10n`, `flutter analyze`

## Follow-ups (NOT in this session)
- Stage 5: host/staff CAMERA scan/decode of the animated swirl (radial-length
  ring contract is documented in `swirl_pattern_view.dart`); the scanner today
  still reads QR (`validate_qr_token`).
- Stage 6: closing docs/baselines/security pass for the whole feature.

## Session record
- Design confirmed with the user: Stage 4 only · TOTP-style derivation ·
  replace the attendee QR display with the swirl now.
