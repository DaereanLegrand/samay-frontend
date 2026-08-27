# 2026-08-27 — Minigames hub fixes: group header, red-circle badges, Premium navbar

## What was built

Fixes on the minigames hub screen plus a Premium (Juega-style) floating nav
bar and a red-circle badge voice.

### Minigames screen (`lib/features/minigames/screens/minigames_screen.dart`)
- **Group name now shows when "Grupo" is selected.** The scope row gained the
  selected group's name + circular banner (height == width, 20px — no taller
  than the Directa/Grupo chips) at its left, resolved from `myGroupsProvider`.
- **"Elige un juego" sits immediately below the AppBar** — the first body row,
  before the Directa/Grupo scope switch.
- **Switch-groups icon** (`Icons.swap_horiz`) at the right of the scope row,
  carrying the red pending-invite badge. It reopens the group picker.
- The scope row is a **fixed 40px box** so switching Directa ↔ Grupo never
  changes the row height (the banner/name/icon all center inside the same box).
- Directa/Grupo chips are **compact** (`VChip.compact`) — smaller height/width/
  padding, `labelSmall` text.
- Group picker rows use the same circular banner avatar.

### Red-circle badge (`lib/shared/widgets/v_count_badge.dart`)
- Replaced the violet sharp-square badge with a **solid red circle**
  (`AppColors.badgeRed` `#E53935`, no border) + white count text.
- Diameter scales per digit (20/26/32…) so it stays a true circle.
- New token `AppColors.badgeRed` + `statusPending` semantic alias
  (`app_colors.dart`). User directive overrides the 2026-08-26 monochrome
  rule for this one semantic element.

### Pending minigame-invite count
- `pendingMinigameInvitesProvider` derives the count from unread
  `minigame_invite` notifications (the 140 migration already inserts them) —
  no new DB/API.
- `MinigameInvitesRealtimeListener` (shell-root, mirrors the friendships
  listener) invalidates `notificationsProvider` on live inserts so the badge
  updates across the app.
- Wired into `pendingCountsProvider` so the NavBar badge includes it.

### Premium floating pill navbar (`lib/core/router/main_shell.dart`)
- Ported Juega's `PremiumCard` pill: `SafeArea` → `Padding(24,0,24,20)` →
  glass pill (blur 20, `surface` α0.85 fill, inner padding 12×10) →
  `spaceAround` Row of `AnimatedContainer` tabs (16×8 padding).
- Selected tab = white icon + 4×4 white dot below (no fill background).
- Sharp corners (`BorderRadius.zero` — user directive removed the rounding).
- `Semantics(button + selected + label)` per tab — keeps 4.1.2 names/roles/
  states for screen readers.
- `extendBody: true` + `MainShell.navBarInset` (bottom padding on shell-tab
  scroll bodies; applied to the profile list so the last row clears the pill).

### Tests regenerated
- `v_count_badge_test.dart` — red circle (fill, circle shape, no border,
  per-digit growth).
- `app_colors_test.dart` — palette now includes `badgeRed` (26 → 27).
- `friends/restyle_test.dart` — badge assertion → red circle.
- `main_shell_test.dart` — floating pill structure, tooltip labels, selected
  dot, red badge on the Grupos tab; stub `notificationsProvider`.
- `app_router_test.dart` — pill assertions + `notificationsProvider` stub.
- `a11y_test.dart` — 4.1.2 nav semantics via the pill's Semantics buttons.
- `integration_test/ui_smoke_test.dart` — shell test targets the pill
  (tooltips/icons + red badge scoped to the pill).
- `profile_screen.dart` — navbar bottom inset.

## Validation
- `flutter test`: **2471 pass / 0 fail** (baseline 2470 → +1; README updated).
- `go test ./...`: green.
- `make check`: dart analyze 0, flutter analyze 0, go vet clean, secrets PASS,
  ports STRICT PASS.
- `make test`: the 2 backend-static failures are **pre-existing** — the
  documented SERVICE_KEY-vs-`.env` drift (opt-001..006) and the
  `supabase/.temp/cli-latest` parity gap; both untouched by this work.
- Integration: `minigames_flow_test` (both flows) and the ui_smoke shell test
  pass.

## MISTAKE blocks
- **MISTAKE (navbar geometry)**: hand-tuning pill height/width drifted from
  Juega's anatomy. Fix: port Juega's `main_shell.dart` structure verbatim
  (same padding/radius/dot), then measure with a probe — fixed 312×70 at every
  tab index. Do NOT improvise spacing when a reference implementation exists.
- **MISTAKE (icon choice)**: `Icons.compare_arrows` for the switch-groups icon
  was rejected — reverted to `Icons.swap_horiz`.
- **MISTAKE (badge color)**: `dangerBright #FF4D4D` with a white border was
  rejected; the user wanted a different red and NO border. Final: `badgeRed
  #E53935`, borderless.

## Pre-existing failures (reported, not fixed — out of scope)
- `ui_smoke_test`: OTP attempts counter (`Te quedan 4 intentos`), feed landing
  (`FeedScreen`/`Juerga en casa`), groups `Solicitudes`, profile sign-out
  dialog (`¿Cerrar sesión?`).
- `feed_flow_test`: `Juerga en casa` (featured event) not found.
- `luxe_screenshots_test`: screenshot suite (monochrome refactor moved the
  visuals).
These are in flows/screens untouched by this work (branch `fixes` mid-refactor).

## Commands run (reproducibility)
```
dart analyze <changed files>
flutter test test/widgets/v_count_badge_test.dart test/router/main_shell_test.dart test/router/app_router_test.dart test/accessibility/a11y_test.dart test/features/friends/restyle_test.dart test/features/cosmetics/cosmetics_navigation_test.dart test/design_tokens/app_colors_test.dart
flutter test            # 2471 pass
make check
go test ./...
flutter test -d macos integration_test/minigames_flow_test.dart
flutter test -d macos integration_test/ui_smoke_test.dart --plain-name "shell: all five tabs render..."
```
