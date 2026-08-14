# 2026-08-12 — XL-15: LUXE v2 Screenshot Harness

**Agent:** XL-15 | **Campaign:** LUXE v2 UI overhaul | **Branch:** `fixes`

Built the screenshot harness: a `flutter drive` integration flow that walks
every key screen on the **iPhone 17 Pro simulator** and captures 18 PNGs into
`luxe-screenshots/`. All 18 captures succeeded (18/18, one sequential run,
00:42).

---

## What was built

| File | Change |
|---|---|
| `integration_test/luxe_screenshots_test.dart` | NEW — the harness flow (two `testWidgets`: pre-auth walk + authenticated walk) |
| `test_driver/luxe_screenshots.dart` | NEW — `integrationDriver` with `onScreenshot` writing `luxe-screenshots/<name>.png` |
| `docs/history/phase-04-luxe/2026-08-12_XL-15-screenshot-harness.md` | this log |

NOT registered in `runner.sh` on purpose (screenshot-only, driven by
`flutter drive`, not `flutter test`). `ui_smoke_test.dart` + the support
harness (`support/fake_supabase.dart`, `support/test_app.dart`) untouched.

### The flow (18 stops)

```
01_welcome → 02_login → 03_signup → 04_otp → 05_age_gate →
06_privacy_terms → 07_profile_setup → 08_feed → 09_groups →
10_events → 11_notifications → 12_profile → 13_settings → 14_chat →
15_coming_soon → 16_shard_ledger → 17_cosmetics → 18_cosmetics (equipped)
```

- **Pre-auth walk** (01–07): one unauthenticated container; taps exactly like
  `ui_smoke_test.dart` (`Iniciar sesión` → `Crear cuenta`), then the typed
  extras via `router.go`: `VerifyExtra` (OTP), `AgeGateExtra`,
  `PrivacyTermsExtra`, `ProfileSetupExtra` (the U-29 codec round-trips them).
- **Authenticated walk** (08–18): one container
  (`AuthState(authenticated: true, hasProfile: true, user: {id: …})`) with the
  hermetic provider overrides copied from the smoke + feature-specific fakes:
  - feed: `_FakeEventService` (featured + plain rows) + `FakeAppConfigNotifier`
  - groups/shell badge: `friendRequestsProvider` / `groupInvitesProvider` /
    `myGroupsProvider` stubs (same fixtures as the smoke: 2+1 → badge "3")
  - notifications: `_FakeNotificationService` returning 3 unread rows (real
    `NotificationsNotifier` maps them through `NotificationItem.fromJson`)
  - chat: `_ScreenshotChatRepository extends ChatRepository` — 3 decrypted
    rows (own + peer bubbles), `subscribe` returns a never-connected
    `Supabase.instance.client.channel(...)` (dispose-safe)
  - shard ledger: `_FakeShardsService` with 3 shard + 1 preshard `LedgerEntry`
  - cosmetics: same `_FakeShardsService`; `featureFlagsProvider`
    `cosmeticsSection: true`; stop 18 = buy ("Comprar — 50" → confirm →
    "Equipar") so the shop shows the equipped state
- **`capture()` helper**: `pumpAndSettle` → `pump(400ms)` (mid-glow-cycle,
  the `VBreathingGlow` alternates 1.5s up/down with a static settle) →
  `binding.takeScreenshot(name)`. On iOS `takeScreenshot` needs no surface
  conversion (that's Android-only).

### Command run

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter drive \
  --driver=test_driver/luxe_screenshots.dart \
  --target=integration_test/luxe_screenshots_test.dart \
  -d A7F4AF05-4D06-4602-9C1C-806E2A3E64C8
```

Result: **PASS** — `00:42 +4: All tests passed!` (2 runs; run 2 captured to
`/tmp/xl15_drive2.log`). Screenshots: `luxe-screenshots/` (repo root),
18 PNGs, 212–676 KB each (all > 5 KB), all 1206×2622 (iPhone 17 Pro native),
dark% 51–75 with full 0–255 value range — content rendered, no black frames.

---

## Decisions

- **Two containers, not one** — `FakeAuthNotifier.build` returns the initial
  state deterministically and never transitions (by design), so the
  pre-auth → post-auth boundary needs two containers. Mirrors the smoke's
  one-testWidgets-per-phase structure.
- **Provider overrides via real feature providers where possible** — the
  notifications/cosmetics screens run their REAL notifier stacks over the
  faked services (`notificationServiceProvider` / `shardsServiceProvider`),
  so the screenshots exercise the production data path, not a stub.
- **Chat via repository subclass** — the E2EE `ChatService` is fully wired;
  subclassing `ChatRepository` and overriding `loadMessages`/`subscribe`
  renders the thread without the mocktail Supabase-server dance of
  `chat_flow_test.dart`.

---

## MISTAKE

1. **`const` on `DateTime`** — `final _aug1 = DateTime(...)` — `DateTime` has
   no const constructor (`const_initialized_with_non_constant_value`). Caught
   by `dart analyze` before the run.
2. **Overrides I didn't need** — I initially stubbed
   `notificationsProvider` / `cosmeticsCatalogProvider` / `myCosmeticsProvider`
   directly; the real notifiers read the faked services and the direct stubs
   would have shown the EMPTY state (worse screenshot, double-wiring).
   Removed them (caught by reading `cosmetics_providers.dart`).
3. **Missing imports** — `routerProvider` (app_router.dart),
   `chatE2eeRepositoryProvider` (features/chat, not core),
   `VButton` (v_button.dart), `RestClient`, `ConfigService`, `Event` model —
   all caught by `dart analyze`.

## Environment gotchas (MISTAKE — out of my control)

4. **Concurrent campaign agent editing `v_button.dart`** — run 2's first
   Xcode build failed with `lib/shared/widgets/v_button.dart:352: Expected
   ';'` — another agent's mid-edit state. Flutter's retry
   ("Application failed to start on attempt: 1") picked up the fixed file
   and the run passed. Do NOT re-run the harness while the campaign is
   actively editing `lib/` — the kernel_snapshot failure is a false alarm.
5. **Hive theme-cache WARN floods the log** — every run logs
   `Theme mode cache unreadable (HiveError: Box not found)… using dark` with
   a provider stack dump. Handled in-app (falls back to dark), NOT a failure;
   the screenshots render the dark theme as designed.
6. **First iOS build is slow** — ~3 min to build + run; subsequent builds are
   incremental (~1 min). Give `flutter drive` up to 20 min on a cold build.

---

## Validation

- `dart analyze integration_test/luxe_screenshots_test.dart
  test_driver/luxe_screenshots.dart` → **No issues found**
- `flutter drive` → **PASS**, 18/18 PNGs, sizes 212–676 KB
- Pixel spot-check (python, every 7th row): no black frames — dark% 51–75
  (black-minimalist theme), full 0–255 channel range (bright text/glow).

## Next steps

- Add `luxe-screenshots/` to `.gitignore` (task says it will be gitignored
  later; I did not touch `.gitignore`).
- LUXE v2 visual review pass over the 18 PNGs (the LUXE agents' inputs —
  gradients/glass/typography — land on these exact screens).
- Re-run the harness after each LUXE batch merges, before the phase gate.
