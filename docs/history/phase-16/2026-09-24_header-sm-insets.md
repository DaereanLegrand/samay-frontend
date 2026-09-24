# 2026-09-24 — Always-8px header insets (outer, not in `barHeight`)

Agent: `header-sm-insets`. Branch: `truth-or-dare-leaderboard`.

## What was built

Every header presentation now adds `AppSpacing.sm` (8px) **above and below**
the bar, on every device. The gap lives *outside* the bar's geometry:

- `VHeaderMetrics.headerOuterPad = AppSpacing.sm` — the external gap.
- `VHeaderMetrics.barOuterHeight(statusTop)` = `headerOuterPad + barHeight +
  headerOuterPad`, the total footprint a fixed header occupies below the OS
  safe-area inset (used by call sites that reserve space under a header).
- `heroTopPad`, `barHeight`, `collapsedBarHeight`, `titleRowHeight` are
  **unchanged** — the OS top inset is additional, and the per-device fallback
  (16px only when `statusTop == 0`) stays inside the bar.

### Surfaces

- `VHeaderBar`: the bar is wrapped in
  `Padding(vertical: headerOuterPad)`; the bar itself is untouched.
- `VHeaderSliver`/`_CollapsingDelegate`: `headerOuterPad` is added above the
  title band and to both `minExtent`/`maxExtent`; the expanded title row is
  padded `statusTop + headerOuterPad + heroTopPad`, and the compact glass title
  is centered on the 48px row at `statusTop + headerOuterPad`. Collapse range
  is still `heroTopPad`, so on phones (inset > 0) the sliver still does not
  collapse and Social (pinned segment strip) stays expanded.
- Floating-header overlays (`attendance_code_screen`,
  `attendee_assist_animation`, `two_lies` finished, `truth_dare` finished,
  `minigame_leaderboard_screen`) gain `headerOuterPad` above the 48px row.
- `finished_leaderboard` content insets add `headerOuterPad * 2` around the
  floating row.
- Height-reserving call sites (`games_tab_screen`, `two_lies` list,
  `truth_dare` `screenHeaderBottom`) now use `barOuterHeight`.

## Resulting layout

| Device | Top | Bar | Bottom | Title starts at |
|---|---|---|---|---|
| iPhone (`statusTop > 0`) | `statusTop + 8` | 48 | 8 | `statusTop + 8` |
| Desktop (`statusTop == 0`) | `8 + 16` | 80 | `16 + 8` | `24` |

## Decisions

- **Spacing outside the bar** (user directive): `barHeight` must not change, so
  the 8px is laid out around it rather than folded in. This keeps every
  existing `barHeight` consumer's meaning intact and makes the gap independent
  of the OS inset.
- **`heroTopPad` kept** (user choice): desktop/web keeps its 16px in-bar
  fallback; the outer 8px is added on top.
- Sliver bands include the 8px on both sides so a pinned scroll header and a
  fixed `VHeaderBar` share one footprint.

## Commands

```bash
export AGENT_NAME=header-sm-insets
# lock the 10 touched paths (v_header_bar.dart + 7 screens/widgets + DESIGN.md
# + this log), edit, then release
dart analyze lib    # No issues found!
```

## Mistakes / gotchas

- **MISTAKE — `dart format` (Dart 3.12) does not match this repo's committed
  formatting.** Running it reformatted unrelated pre-existing code (the new
  tall style vs the committed short style). The 6 affected files were reverted
  with `git checkout --` and only the intended edits re-applied. Do **not**
  blanket-format; match the surrounding code by hand. `dart analyze` is the
  gate that matters here.

## Notes / follow-ups (out of scope)

- `finished_leaderboard.dart` uses the same `insets` for a SafeArea-wrapped
  branch (pinned chrome) and a non-SafeArea branch (empty state) — the latter
  appears to under-pad by `statusTop` pre-existing. Not touched here.
- `minigame_header_title.dart:21` has a stale doc reference
  `[VHeaderBar.barHeight]` (the metric lives on `VHeaderMetrics`).
