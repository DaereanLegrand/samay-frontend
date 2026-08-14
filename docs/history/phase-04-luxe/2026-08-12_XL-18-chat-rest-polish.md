# XL-18 — Chat + utility screens final luxury pass (Gemma round 3)

**Date:** 2026-08-12 | **Branch:** `fixes` | **Role:** critique fixes for
`14_chat`, `11_notifications`, `04_otp`; positive controls respected
(`15_coming_soon` 9/9, `13_settings` minimalism 9, `17_cosmetics` 9).

## Evidence cited

- `luxe-screenshots/verdicts/14_chat.md` — "OVERALL: MEDIOCRE. Lacks focus and
  execution." (hierarchy 5, luxury 4). Fixes: less saturated bubbles, glow
  chrome removed, single accent (composer), bubble width cap.
- `luxe-screenshots/verdicts/11_notifications.md` — 7-8/10 but "visual
  hierarchy needs refinement to ensure readability". Fix: read-row title
  weight lift + no saturated fills.
- `luxe-screenshots/verdicts/04_otp.md` — "functional but utterly pedestrian
  digital form". Fix: the 6-digit field becomes the star (liquid glass +
  gold focus border + glow), helper duplication removed (counter only near
  the limit).
- Positive controls NOT regressed: `15_coming_soon` (9/9), `13_settings`,
  `17_cosmetics` (9), `paywall` glass gold price cards (9/10 — untouched).

## What was built

### 1. Chat — `lib/features/chat/screens/chat_screen.dart` (verdict 14_chat)

One conversation surface, per directive:

- **Own bubble**: fill = `AppGradients.watered(peach.colors, mix: 0.45)`
  (directive recipe) — whisper peach, never saturated; the glow halo is
  replaced by a 1px white α0.2 hairline border (`border` instead of glow).
- **Peer bubble**: white-only liquid glass (`VGlass` gradient null, no glow)
  — the peach accent is confined to the composer row.
- **Max width**: bubbles capped at 320 logical px
  (`ConstrainedBox(maxWidth: 320)`) — the thread is the visual center with
  maximum width utilization.
- Spacing literals 16 → `AppSpacing.lg`/`sm` tokens (16/24 scale).
- `VThinkingDots` send state kept; E2EE/realtime/logic untouched.
- No timestamps/avatar stacks existed to remove — bubbles are text-only
  already.

### 2. OTP — `lib/features/auth/screens/otp_verification_screen.dart` (04_otp)

- The single 6-digit field is now a **liquid-glass slab** (`otpGlassShell`
  key): resting = white α0.25 ring on surfaceAlt α0.5 fill + neumorphic top
  highlight (the `VInput` recipe); focused = **gold family gradient border**
  (vivid α0.9 → pastel α0.35) + family halo `glowShadows(0.22, blur 24)`.
  No underline (LUXE directive #7). Digits keep `AppTypography.otpInputText`
  (30/w800/ls8 white) — restyle pins intact.
- **Attempts counter only near the limit**: shows when
  `remaining ≤ 2 && remaining > 0` (blocked state owns the last word) —
  early failures read through the error text alone; the error+counter
  duplication Gemma flagged is gone.

### 3. Notifications — `lib/features/notifications/screens/notification_center_screen.dart` (11_notifications)

- Read-row title w300 → **w400** (hierarchy + legibility; unread w600 stays
  dominant).
- Unread dot fill: `AppColors.discoGold` → **gold watered 45%** (no saturated
  fills, directive #3). Key `unread-dot-*` kept.

### 4. Party Finder — `lib/features/party_finder/screens/party_finder_screen.dart`

- Accent chips (`VChip.accent`) now use a **watered cyan family**
  (`_chipFamily`, mix 0.35) — the vivid-end chip fill was the screen's only
  saturated slab.

### 5. QR / Photos / Minigames / Paywall

Audited per directive (16/24 spacing, single accent, no saturated fills, no
duplicate titles): already consistent — **no changes** (paywall 9/10 gold
glass cards deliberately untouched to avoid regressing the positive control).

## Tests

- Updated visual pins:
  - `test/features/chat/chat_screen_test.dart` — bubble test now pins
    watered(0.45) gradient, white hairline border, null peer gradient, and
    the 320 max-width ConstrainedBox.
  - `test/features/auth/otp_ux_test.dart` — counter test rewritten to the
    near-limit contract (hidden at attempts 1–2, `Te quedan 2` → `Te queda 1`).
- Behavior pins untouched and green (auto-submit, block-at-5, resend reset,
  chat send/thinking-dots/pagination, notification taps/mark-read).

## Commands

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
dart analyze lib/features/chat/ lib/features/qr/ lib/features/photos/ \
  lib/features/minigames/ lib/features/party_finder/ lib/features/subscriptions/ \
  lib/features/notifications/ lib/features/auth/screens/otp_verification_screen.dart \
  test/features/chat/ test/features/qr/ test/features/photos/ test/features/minigames/ \
  test/features/party_finder/ test/features/subscriptions/ test/features/notifications/ \
  test/features/auth/otp_ux_test.dart
# → No issues found!
flutter test test/features/chat/ test/features/qr/ test/features/photos/ \
  test/features/minigames/ test/features/party_finder/ test/features/subscriptions/ \
  test/features/notifications/ test/features/auth/otp_ux_test.dart
# → 200/200 passed
flutter test test/features/auth/restyle_test.dart test/features/auth_screens_test.dart \
  test/features/auth/auth_interactions_test.dart  # OTP neighbors → 61/61 passed
```

## Decisions / gotchas

- **MISTAKE (concurrent edit)**: `lib/features/auth/screens/otp_verification_screen.dart`
  was edited by XL-16 while XL-18 held the re-acquired lock; my first edit
  failed on a stale `oldString` (spacing 16→40/20 changed under me). Fixed by
  re-reading the file and re-applying against current content. Future agents:
  re-read before every edit on contended files.
- `AppGradient` instance constructed ad-hoc in party_finder (`_chipFamily`)
  to carry watered colors through the shared `VChip` gradient API without
  touching the shared widget (owned by XL-14/XL-19 scope).
- Rendering only: no routes/providers/flows/l10n keys/E2EE touched. Locks
  released after validation.

## Sources

- ORCHESTRATION-LUXE.md §"Gradient family → screen map", §Rules
- Gemma verdicts: `luxe-screenshots/verdicts/14_chat.md`,
  `11_notifications.md`, `04_otp.md`, `18_cosmetics.md` (no-image), and
  positives `15_coming_soon.md`, `13_settings.md`, `17_cosmetics.md`.
