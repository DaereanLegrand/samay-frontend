# 2026-08-17 — Crash recovery banner: move to bottom above NavBar

## What was built

Relocated the `CrashRecoveryBanner` from the top of the screen (inside the
builder `Column`) to the bottom, positioned directly above the `BottomNavigationBar`.

### Problem

1. **Margin push**: The banner sat in the top `Column` above the `Expanded`
   Navigator, pushing the title screen and back arrow down when visible.
2. **Status bar occlusion**: The banner was behind the OS status bar
   (Dynamic Island / notch / status icons), making the OK dismiss button
   unreachable on both iOS and Android.

### Solution

Changed `lib/app.dart` builder layout from `Column` to `Stack`:

- **Navigator** fills the screen via `Positioned.fill` — no margin push from
  banners.
- **`ConnectivityBanner`** stays at the top as a `Positioned(top: 0)` overlay.
- **`CrashRecoveryBanner`** moved to `Positioned(bottom: kBottomNavigationBarHeight + MediaQuery.padding.bottom)` — sits directly above the NavBar,
  clear of the status bar, Dynamic Island, and home indicator on all devices.

### Files changed

| File | Change |
|------|--------|
| `lib/app.dart` | `Column` → `Stack`; banner repositioned to bottom |
| `test/widgets/crash_recovery_banner_test.dart` | Updated test name and reason string to reflect bottom positioning |

## Decisions

- **Stack overlay vs Column**: Using `Stack` with `Positioned` lets banners
  overlay content instead of pushing it. This eliminates the margin issue
  and is the standard Flutter pattern for global banners.
- **Safe-area aware positioning**: `mediaQuery.padding.bottom` accounts for
  the home indicator on notched iPhones. `kBottomNavigationBarHeight` (56.0)
  is the standard Material NavBar height.
- **No changes to `CrashRecoveryBanner` widget**: The widget itself is
  position-agnostic (just renders a visible/invisible banner). Only its
  parent layout changed.

## Mistakes / gotchas

None.

## Commands run

```bash
dart analyze lib/app.dart lib/shared/widgets/crash_recovery_banner.dart
flutter test test/widgets/crash_recovery_banner_test.dart
```

## Test counts

- `crash_recovery_banner_test.dart`: 5 passed (3 banner-direct + 2 SamayApp
  wiring) — unchanged count, all green.

## Deviations

- 3 pre-existing `info` hints in `lib/core/extensions/error_mapper.dart`
  (`prefer_const_constructors`) — unrelated to this change.
