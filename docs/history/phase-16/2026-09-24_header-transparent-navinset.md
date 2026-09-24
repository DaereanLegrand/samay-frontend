# 2026-09-24 — Always-transparent tab headers + nav-bar bottom inset everywhere

Agent: `header-transparent-navinset`. Branch: `truth-or-dare-leaderboard`.

## What was built

Two fixes reported from the iPhone 11 screenshot of the Events tab (scrolled to
the bottom): the header title/actions vanished, and the last card sat under the
floating nav pill.

### 1. `VHeaderSliver` → always transparent, pinned, no collapse

- Removed the iOS large-title collapse and the blurred-glass bar entirely. The
  delegate (`_CollapsingDelegate` → `_TransparentHeaderDelegate`) now keeps
  `minExtent == maxExtent` and always paints the shared title row (title +
  **actions**) over the existing top scrim gradient.
- Deleted the now-unused metrics (`collapsedBarHeight`, `glassFill`,
  `glassSheen`, `glassBlur`) and the `dart:ui` `ImageFilter` import.
- Affects every tab root: Feed, Events, Profile, Notifications, Social
  (Social keeps its pinned segmented `bottom` strip).

### 2. Nav-bar bottom inset on every shell tab

- Added a trailing
  `SliverToBoxAdapter(SizedBox(height: MainShell.navBarInset(context)))` to the
  tab-root scroll views that lacked it: Feed, Events, Notifications, Social's
  Groups and Amigos sub-tabs (Games / Profile already had it).
- `MainShell.navBarInset(context)` = the body's `MediaQuery.paddingOf(context)
  .bottom` + 16. Because the shell `Scaffold` uses `extendBody: true`, Flutter
  sets that `padding.bottom` to the **full nav-bar height**
  (`scaffold.dart:966-980`), so the last item now scrolls clear of the pill.

## Decisions

- Header stays **pinned and transparent** with both title and actions always
  visible (user directive) — no collapse, no glass fill.
- Bottom spacing is exactly `navBarInset` (no extra `xl`), matching Games.

## Commands

```bash
dart analyze lib    # No issues found!
```

## Follow-ups

- Simulator visual check still needs a **hot restart** of the human's `make dev`
  session (agent must not trigger reloads).
- The Events-tab distance slider still has the Slider's built-in vertical inset
  (`SliderThemeData.padding` tweak) pending.
