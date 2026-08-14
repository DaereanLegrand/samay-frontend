# XL-13 — Remaining Features + Coming-Soon (LUXE v2)

**Date:** 2026-08-12 | **Agent:** XL-13 | **Branch:** `fixes`
**Role:** Restyle the remaining feature screens + the shared coming-soon widget
to the LUXE v2 design language (ORCHESTRATION-LUXE.md).

---

## What was built

All 9 feature screens + `v_coming_soon.dart` restyled to their per-screen
gradient family. **No pink mains anywhere** (2026-08-12 directive). Behavior
byte-identical: routes, providers, flags, gating, RPC calls, copy, keys and
pump seams untouched.

| Screen | Family | LUXE treatment |
|---|---|---|
| `attendance_qr_screen.dart` | cyan | 1 VAurora (α0.06); QR on a cyan glass panel (radius 20, glow 0.3); countdown ring arc = **cyan gradient stroke** (`shader` on the CustomPainter, was flat glowPink); message states on cyan glass with family-tinted icon + family-gradient retry buttons |
| `qr_scanner_screen.dart` | cyan | camera/permission flow untouched (VEmptyView panels kept); scan frame corners stay white; **new cyan gradient scan line** sweeping top→bottom on the idle-safe engine (2.4s sweep + 300ms rest — `pumpAndSettle`-safe, reduced-motion → static center line); result banners on cyan glass; confirmed ✓ stays `discoCyan`; error text via `AppColors.error` (pink alias legal as error semantic) |
| `photo_gallery_screen.dart` | mint | 1 VAurora (α0.05); upload-window-closed notice on mint glass strip; upload IconButton mint-tinted; like heart `glowPink → AppColors.mint`; report dialog input: underline → filled liquid-glass field (LUXE #7), still a `TextField` (test contract) |
| `shard_ledger_screen.dart` | gold | 1 VAurora (α0.06); balance header + every tile on gold `VGlassCard` (tiles glow 0.1); **positive deltas/net render as gold gradient text** via `ShaderMask` (`_GradientDelta` helper) — negatives stay mutedStrong strikethrough; gold shard diamond kept |
| `cosmetics_shop_screen.dart` | violet | 1 VAurora (α0.06); balance bar + cards on violet glass; **equipped badge → `VBadge.accent(gradient: violet)`** (owned-idle keeps muted flat accent); equipped card gets stronger glow (0.32); buy/equip buttons take the violet gradient |
| `minigames_screen.dart` | peach | 1 VAurora (α0.06); "Elige un juego" → `VDisplayText` 28 peach; game cards on peach glass with peach selection accent (was glowPink); create CTA → `VButton.glowAccent(filled, peach)` (still a `TextButton` inside — test contract); session cards on peach glass |
| `party_finder_screen.dart` | cyan | 1 VAurora (α0.06); opt-in `SwitchListTile` on cyan glass card; match rows on cyan glass; interest chips → `VChip.accent(gradient: cyan)`; block icon stays mutedStrong |
| `paywall_screen.dart` | gold (brand moment) | 1 VAurora (α0.07); **redundant AppBar title removed** — `paywallHeader` is now the single `VDisplayText` hero (32, gold, directive #8); tier cards = glass price cards with gold gradient borders + glow (VIP 0.4 / current 0.28 / idle 0.16); "Actual" badge → `VBadge.accent(gold)`; **all RevenueCat behavior kept**: `purchase`/`restore` calls, stub mode → 3 disabled buttons + 3 "Próximamente" tooltips |
| `notification_center_screen.dart` | gold | 1 VAurora (α0.05); unread rows on gold glass (read rows white-only glass); unread icon/dot gold (was glowPink); `ValueKey('unread-dot-…')` + bold-title rule kept (never color-only) |
| `v_coming_soon.dart` | violet default | glass panel (radius 20, glow 0.22) instead of the bare column; "PRÓXIMAMENTE" via `VDisplayText` (32, family gradient, MAYUS enforced); **public API kept + additive `family` param (default violet, never pink)**; back-button behavior identical (canPop → pop, tab-level → `mainFeed`); scroll-safe LayoutBuilder pattern kept |

One VAurora per screen at α0.05–0.08 as instructed (quiet utility screens);
heroes use `VDisplayText` (uppercase family gradient); cards/tiles use
`VGlassCard`; CTAs use `VButton` with the family gradient.

## Decisions

- **AppBar titles kept on utility screens** (attendance QR, scanner, photos,
  shards, cosmetics, minigames, party_finder, notifications): they carry the
  back affordance and no hero exists to duplicate. Only the **paywall** had a
  redundant title (AppBar + header) — it now uses the single hero (directive
  #8: "one hero per screen max").
- **No `repeat()` animations anywhere**: the scan line and all glows use the
  idle-safe engine (finite animation + `motionCycleRest` settle), so
  `pumpAndSettle`-based tests land deterministically (same contract as
  VBreathingGlow/VAurora).
- **VAurora vs pumpAndSettle tension:** a `pumpAndSettle` on a screen with a
  VAurora pumps ~10s of fake time (one drift orbit), which runs a 4s snackbar
  through its full lifecycle and dismisses it. Tests that assert snackbars
  now use bounded pumps (`pump()` + `pump(400ms)`) — the same pattern the QR
  scanner tests already used. Behavior assertions unchanged.
- **Pink survives only as error semantics** (`AppColors.error` in the scanner
  error banner) — the directive's explicit carve-out. Every other pink accent
  (heart, ring arc, unread dot, game selection, VIP border, badge) moved to
  the screen family.
- Gold gradient deltas use `ShaderMask` + `AppGradients.textShader` (the
  documented gradient-text path), not raw hex or flat color.

## Web research (cited)

- Behance, "luxury dark ui 2026" search — 10,000+ projects; recurring traits:
  black canvases, gold/cyan accents, glass panels over dark imagery, one
  oversized display word per screen (e.g. AURELIA jewelry, Bluedot EV app,
  Empire gaming): https://www.behance.net/search/projects?search=luxury%20dark%20ui%202026
  → informed the gold paywall "brand moment" and single-hero rule.
- Apple, "Auto-renewable Subscriptions" — billing amount must be the most
  prominent element; subscription name/duration/services + renewal price
  clearly shown; restore path present: https://developer.apple.com/app-store/subscriptions/
  → the paywall keeps prices prominent and the restore CTA.
- Toptal, "Empty States: The Most Overlooked Aspect of UX" — empty states
  must explain what/why/what-to-do, keep CTAs to one or two, guide first
  use: https://www.toptal.com/designers/ux/empty-state-ux-design
  → the per-screen empty states (VEmptyView with a single action) were kept
  verbatim on glass-family screens.

## Tests

`flutter test test/features/qr/ test/features/photos/ test/features/shards/
test/features/cosmetics/ test/features/minigames/ test/features/party_finder/
test/features/subscriptions/ test/features/notifications/
test/widgets/v_coming_soon_test.dart`

**Result: +218 passed, 1 failed** (out of scope — see Issues).

Updated tests:
- `test/widgets/v_coming_soon_test.dart` — headline assertions moved to the
  LUXE display voice: `PRÓXIMAMENTE` (MAYUS), `VDisplayText` default gradient
  == violet, Playfair italic 32, halo = DecoratedBox glow inside VDisplayText
  (not text shadows); added a `family:` param test (cyan re-accents glass +
  headline). Back-nav, tab-fallback, icon, AppBar and description tests
  unchanged and green.
- `test/features/cosmetics/cosmetics_navigation_test.dart` — coming-soon
  fallback assertion: `'Próximamente'` → `'PRÓXIMAMENTE'`.
- Snackbar tests switched to bounded pumps (VAurora drift explanation above):
  cosmetics_shop_screen (2), minigames_screen (4), party_finder_screen (2),
  photo_gallery (2).

`dart analyze lib/features/qr/ lib/features/photos/ lib/features/shards/
lib/features/cosmetics/ lib/features/minigames/ lib/features/party_finder/
lib/features/subscriptions/ lib/features/notifications/
lib/shared/widgets/v_coming_soon.dart` → **0 issues**.

## Issues (out of scope)

1. `cosmetics_navigation_test.dart` — "profile → cosmetics navigation the
   flag-gated profile section navigates to the shop" FAILS: the tap on the
   profile's "Cosméticos" row misses (hit-test warning, offset y≈764).
   **Verified pre-existing**: fails identically with XL-13's files stashed.
   Root cause is the in-flight profile screen restyle (XL-08 owns
   `profile_screen.dart`, uncommitted in the working tree). Handed to XL-08/
   orchestrator.
2. Transient compile break during the run: a concurrent agent's mid-edit
   window on `app_colors.dart`/`samay_durations.dart` briefly removed the
   pastel tokens + `auroraDrift` (foundation flicker). Re-ran after they
   settled — clean. No action taken (their files).

## Files

- `lib/features/qr/screens/attendance_qr_screen.dart`
- `lib/features/qr/screens/qr_scanner_screen.dart`
- `lib/features/photos/screens/photo_gallery_screen.dart`
- `lib/features/shards/screens/shard_ledger_screen.dart`
- `lib/features/cosmetics/screens/cosmetics_shop_screen.dart`
- `lib/features/minigames/screens/minigames_screen.dart`
- `lib/features/party_finder/screens/party_finder_screen.dart`
- `lib/features/subscriptions/screens/paywall_screen.dart`
- `lib/features/notifications/screens/notification_center_screen.dart`
- `lib/shared/widgets/v_coming_soon.dart`
- `test/widgets/v_coming_soon_test.dart`
- `test/features/cosmetics/cosmetics_navigation_test.dart`
- `test/features/cosmetics/cosmetics_shop_screen_test.dart`
- `test/features/minigames/minigames_screen_test.dart`
- `test/features/party_finder/party_finder_screen_test.dart`
- `test/features/photos/photo_gallery_test.dart`

Locks acquired and released for all of the above (`tools/agent_lock.sh`).
No commits made.

## Commands

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
dart analyze lib/features/qr/ lib/features/photos/ lib/features/shards/ \
  lib/features/cosmetics/ lib/features/minigames/ lib/features/party_finder/ \
  lib/features/subscriptions/ lib/features/notifications/ \
  lib/shared/widgets/v_coming_soon.dart
flutter test test/features/qr/ test/features/photos/ test/features/shards/ \
  test/features/cosmetics/ test/features/minigames/ \
  test/features/party_finder/ test/features/subscriptions/ \
  test/features/notifications/ test/widgets/v_coming_soon_test.dart
```
