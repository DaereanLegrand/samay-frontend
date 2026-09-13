# 2026-09-08 — Events Stage-5 pivot: dynamic QR attendance code (attendee side)

## What was built

### Backend — `060_events/07_code.sql` (mirrored byte-identical)
- `event_code_keys(event_id, user_id, secret)` — ONE random 32-byte HMAC
  secret per (event, attendee), issued lazily inside the activation window.
  FORCE RLS with **zero client policies and zero table grants** (the only
  handle is the SECURITY DEFINER RPC). UNIQUE (event_id, user_id); secret
  CHECK `^[0-9a-f]{64}$`.
- `event_code(secret text, counter bigint)` — immutable SQL helper:
  `left(hex(hmac_sha256("samay.code.v1:" || counter, secret)), 24)`. Grant:
  service_role only (opt cross-check), never PUBLIC.
- `get_my_code(p_event_id)` — attendee issue (host/staff/live invite
  gate + activation window via `qr.activation_minutes_before`). Returns
  `{code, secret, counter, windowSeconds, windowStart, windowEnd}` so the
  device regenerates windows locally (authenticator style).
- `validate_code(p_event_id, p_code)` — host/staff-only; recomputes
  every attendee secret for counter ±1 (clock-skew tolerance) and confirms
  ONCE: `event_attendances` is the single-confirmation marker, guests' invite
  flips to `attended`. Statuses `not_host/not_in_window/invalid_code/
  not_invited/already_scanned/confirmed`.
- Key-purge triggers on `event_invites` DELETE (declined / converted) and
  `event_hosts` DELETE (removed staff) → a revoked attendee's code dies
  instantly (guest→staff conversion purge is a benign forced refresh).
- `code.window_seconds` (30) added to both seed-config.sql copies (app_config
  tuning rows: 46→47 for the +1 code-window key, then back to 46 when the
  legacy `qr.token_valid_seconds` row was dropped in the same sweep).
- **Legacy QR-token surface removed**: the static token table, its
  rotate/validate RPCs, their ACLs/pgTAP assertions and the `qr.token_valid_seconds`
  config row are gone. ONE rotating-code flow remains.

### The pivot: the bespoke animated radial visual was abandoned
The attendee side was first prototyped as a **bespoke animated radial
device-linking ring** (24 radial-length bars over 24 angular sectors encoding
the hex digits). That visual concept was **reversed the same day** and
replaced by a **plain rotating QR** (`qr_flutter` `QrImageView`) encoding the
current 24-hex code — the QR camera path already existed and is far more
reliable. The radial-ring painter was deleted (its file removed from the tree);
the attendee screen is `attendance_code_screen.dart`, route `/qr/:eventId`.

### Domain rename: the "code" family
The whole attendance-code domain is named **code**, not the abandoned visual
name: `event_code_keys`, `event_code`, `get_my_code`, `validate_code`,
`purge_event_code_key`, triggers `code_key_purge_on_invite_delete` /
`code_key_purge_on_host_delete`, config `code.window_seconds`, HMAC domain
`samay.code.v1:`, migration `060_events/07_code.sql`. Flutter kept the rename:
the code-logic file → `lib/features/qr/logic/code.dart`
(`CodeSession`/`CodeFetch` + `deriveCode`), the provider file →
`code_providers.dart` (`myCodeProvider`), the screen →
`attendance_code_screen.dart`; l10n keys `codeActivatesIn`, `codeCaption`,
`codeLoadError`, `codeEventEnded`, `codeNotInvited`, `codeServerPending`,
`codeServerPendingBody`; scanner key `qrScanInvalidToken` → `qrScanInvalidCode`
and the unused `qrScanExpired` removed. The old attendee-QR screen/provider and
the token RPCs they called are gone (client-side dead after the token surface
went away).

## Tests
- `test/opt-027-events-code.sh` (the events-code opt-test, renamed from the
  Stage-4 name the same day): issue + determinism + per-user distinctness +
  helper cross-check (A/B), outsider/attendee gates (C), `not_in_window`
  before activation (D), staff attendee parity + single confirmation (E),
  guest invite-flip + fresh-window double-confirm blocked (F),
  malformed/unmatched codes (G), secret never leaks via REST (H). opt-026
  TEST G updated to the code family. **PASS=28 FAIL=0.**
- pgTAP: Section 21d rewritten to the code family (13 legacy QR-token
  assertions removed), plan(953) → **plan(940)**; `app_config` tuning rows 46.
  **All pass.**
- `flutter analyze` 0 issues.

## MISTAKE blocks
- The original bespoke radial-ring idea (16 radial steps over 24 sectors) was
  an attractive visual but a bespoke camera-decode target; reversed the same
  day for the plain rotating QR, which reuses the working QR scanner. Deleted
  the bespoke painter rather than carrying a dead visual.
- The fetch listener originally called `setState` on first frame inside
  `build` (a ref.listen fires post-frame). Anchor inline in the data branch
  instead (`_applySession` without setState); the listener re-anchors only on
  real code changes.
- `field_of` (helper taking `$1` as the JSON) was piped stdin in one call →
  `$2 unbound`. Pass the JSON as the argument like the rest.
- A stray l10n edit duplicated `qrEventEnded` in `app_es.arb` before the block
  was removed — caught by re-reading the region before regenerating. Always
  re-read the arb region after multi-key deletions.
- During the rename, some abandoned-name identifiers survived in tests/docs at
  first; a repo-wide grep sweep caught the stragglers before commit.

## Commands run (reproducibility)
- `bash test/opt-027-events-code.sh` (RED: PGRST202 before the migration)
- `cp supabase/{seed-config.sql,migrations/060_events/07_code.sql}` →
  `supabase-testing/...` (mirrors)
- `psql -p 54382 -f supabase-testing/migrations/060_events/07_code.sql` +
  `-f seed-config.sql` (supabase-testing stack)
- `supabase db test --db-url ".../postgres?sslmode=disable"` (pgTAP 940)
- `flutter gen-l10n`, `flutter analyze`

## Follow-ups (NOT in this session)
- Stage 6: closing docs/baselines/security pass for the whole feature.

## Session record
- Design confirmed with the user: attendee side is a **plain rotating QR**
  (the bespoke animated radial visual was abandoned) · TOTP-style derivation ·
  rename the attendance-code domain to "code" · delete the legacy static
  QR-token server surface so only ONE code flow remains.
