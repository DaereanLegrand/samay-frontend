# 2026-09-09 — Attendance QR screen restyle (inverted QR + draining border) + 10-s code window

## What was built

### Flutter — `lib/features/qr/screens/attendance_code_screen.dart`
- **Active-state restyle** (`_ActiveCode`): the white `surface` card and the
  white rounded backing behind the QR are GONE. The QR is now rendered
  **inverted** — white modules/eyes on the black page
  (`QrImageView` `backgroundColor: transparent` + white `eyeStyle` /
  `dataModuleStyle`; avoids the deprecated `foregroundColor`).
- **Header**: no title on this screen — `VHeaderBar` back arrow only
  (`qrAttendanceTitle` key kept — still used by event-detail's QR button).
- **Countdown ring removed** (`_CountdownRing` + `_RingPainter` deleted,
  `SamayDurations` import dropped).
- **Replacement: draining 3px border** — new `_BorderProgressPainter` draws a
  3 px white border around all four sides of the QR square; the remaining
  perimeter length = `remaining / window` (full at code generation → empty at
  the next code), repainted by the existing 1-s heartbeat. No animation
  (reduced-motion safe).
- **Plain-text readout + caption removed** below the QR (SelectableText hex +
  `codeCaption`). Final page = back arrow + QR + draining border only.
- `displayWindow` fallback `?? 30` → `?? 10`.

### l10n
- Removed now-unused `qrNewCodeIn` and `codeCaption` keys from `app_en.arb` +
  `app_es.arb` and regenerated (`flutter gen-l10n`).

### Window 30 s → 10 s (full stack)
- `code.window_seconds` seed value + `default_value` `'30'` → `'10'` in both
  `seed-config.sql` mirrors (byte-identical). `07_code.sql` mirror comment
  updated (seed 10); SQL fallbacks/guard left untouched (config row is
  authoritative; no function churn on live DBs).
- Applied to the running `samay-testing` stack with an explicit
  `UPDATE app_config` (seed re-apply is `ON CONFLICT DO NOTHING` and would not
  change an existing row).
- `test/opt-027-events-code.sh` expectations updated: `WS=10` +
  "10-s window" strings. PASS=28 FAIL=0 unchanged → README baselines stable.
- Docs sweep: `cross-references.md` (10-s window), `DATABASE.md` (seed 10),
  `SECURITY.md` (10-s replay window ×2), `FLMT` spec (10-s window), `code.dart`
  seed comments.

## Decisions
- User chose a **draining 3px border on all 4 sides** of the QR (rectangle
  replacement for the circle ring) and a **real 10-s rotation window**.
- Inverted QR (white-on-black) is intentional per the user; some scanners are
  picky about inverted codes — posture kept as instructed.

## Commands run
- `flutter gen-l10n`
- `PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
  -c "UPDATE app_config SET value='10', default_value='10' WHERE key='code.window_seconds'"`
- `flutter analyze` (clean)
- `bash test/opt-027-events-code.sh` → PASS=28 FAIL=0

## Follow-up (same day) — near-midnight event creation + code-screen wording
User reported an event ("eveve") they created "starts at 23:04" (at 23:05)
showing "El código se activará 1408 minutos antes del evento / Se activa en
23:28:11" — nonsense. DB forensics proved the event was stored starting
**tomorrow** 23:04 local (UTC Sep 10 04:04, created UTC Sep 9 04:05), so the
QR screen math was actually correct (activation = start − 30 min ≈ 1408 min).

**Root cause:** the create form's default start is `now + 1h`
(`create_event_screen.dart:_defaultStarts`). At 23:0x that rolls past midnight,
so the default DATE silently became tomorrow while the user only edited the
clock time (their earlier mid-evening events stayed same-day — compare
"otro evento": start 21:10, created 21:11, live).

**Fixes:**
- `create_event_screen.dart`: default start clamps to TODAY (`now`) when the
  +1h candidate crosses midnight — a near-midnight "starts now" event no
  longer lands a day out. The server accepts a just-past start (only
  `ends > starts` is enforced) and the code window opens immediately.
- `attendance_code_screen.dart` + l10n: the pre-activation copy no longer
  interpolates the remaining minutes into a "…activates N minutes before the
  event" sentence (that produced the absurd 1408). Replaced `codeActivatesIn`
  key with static `codeNotReadyYet` ("Tu código de asistencia aún no está
  listo.") + the existing "Se activa en HH:MM:SS" countdown caption.
- `flutter gen-l10n` + `flutter analyze` clean.

## Follow-up (same day) — QR screen UI polish
- QR box narrowed 340 → 300 ("a little smaller").
- **Full-screen vertical centering**: the active QR state no longer renders
  inside the shared `VHeaderBar` body (whose `Expanded` shrank the centering
  box by the 80 px header band). `_ActiveCode` is now its own black full-bleed
  `Scaffold`: a floating back arrow (`VHeaderTitleRow` inside `SafeArea`,
  matching the shared header metrics) overlays the top, and the QR is `Center`d
  on the WHOLE screen. Content is wrapped in a `FittedBox(scaleDown)` so it
  shrinks instead of clipping on tiny screens.
- **Silky + eased drain**: the border no longer repaints in 1-s steps from the
  parent heartbeat (which was visibly choppy over a 10-s window). A per-frame
  `Ticker` in the new `_CountdownQr` StatefulWidget reads the wall clock
  against `boundaryMs`, feeds a `ValueNotifier<double>`, and the
  `_BorderProgressPainter` repaints off that notifier (only the canvas
  repaints, not the QR). The raw remaining fraction passes through
  `Curves.easeInOutCubic` on the elapsed side, so the drain is slow right
  after a new code appears and slow as the next approaches — fastest mid
  window. Dead `_remaining` bookkeeping and the `dart:math` import were
  dropped. `flutter analyze` clean.

## Follow-up (same day) — tile look, fill direction, stale-first-window
User iteration on the active QR:
- **Direction flipped to FILL**: the black border now starts EMPTY at a fresh
  code and fills to full exactly when it rotates (was: full → drain).
- **White tile + black border**: the QR module area (white modules on a dark
  square) sits centered on a rounded WHITE tile over the black page. The 3px
  countdown border is BLACK, drawn on the tile's white padding flush against
  the module square — the old quiet-zone gap between QR and border is gone
  (`QrImageView` `padding: EdgeInsets.zero`; geometry constants
  `_qrTileSide/_qrTileRadius/_qrTilePadding/_qrBorderStroke`). NOTE: this
  removes the QR quiet zone — scan-reliability trade-off accepted per the
  user's explicit "no spacing" requirement.
- **Stale first window fix**: the code screen now `ref.invalidate`s
  `myCodeProvider` on every entry so `get_my_code` re-issues the session and
  `windowSeconds` always reflects the live server config — a session cached in
  memory from before the 30→10 s seed change could otherwise keep the first QR
  frozen for a full stale (30 s) window.
- `flutter analyze` clean.

## Follow-up (same day) — no big tile, white only behind the border
User rejected the big rounded white tile ("black border and white tile have
the same dimension … it must be literally behind the black border, no more no
less, no rounding"). Reworked the active QR:
- **No tile, no rounding.** The QR code (white modules) sits directly on the
  black page again (`_qrWidgetSide`), with `QrImageView padding: zero` so the
  modules run flush to the framing ring.
- **Ring = white track + black fill, same 3px dimension**
  (`_qrRingWidth`). `_BorderProgressPainter` first draws a full WHITE ring
  along the QR's perimeter path (that thin ring is the only "white", exactly
  the border's own path — no extra area), then draws the BLACK countdown fill
  over it empty → full per window. Sharp corners; the old
  `_qrTileSide/_qrTileRadius/_qrTilePadding/_qrBorderStroke` constants are
  gone (replaced by `_qrRingWidth`).
- `flutter analyze` clean.




