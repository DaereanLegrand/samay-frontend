# Header optical alignment — one shared centerline for arrow / title / action

**Branch:** `alignment-header` · **Date:** 2026-09-11

## Goal

The back arrow, title and action must read as vertically aligned **by their
optical (visual) centers**, at any font size and for any glyph, app-wide. Prior
code used per-element magic nudges (`backArrowNudge = actionNudge = 6`) that
merely happened to look right for one font/size and drifted for others.

## Industry standard (research)

- **Optical vs mathematical alignment.** Geometric (bounding-box) centering is
  not what the eye reads. Text lines carry invisible ascent/descent space, so an
  icon that is mathematically centered next to text looks off; you align to a
  visual reference instead (a common ~0.05–0.2 em optical offset).
- **Apple (SF Symbols / HIG Toolbars).** SF Symbol scales are defined
  **relative to the cap height** of the system font; symbol weights match the
  adjacent text weight; symbols ship per-symbol alignment metadata and negative
  side margins. A toolbar is leading (back) + center/trailing (title, actions),
  centered by the system.
- **Material (top app bar).** Leading nav icon + title + trailing actions,
  centered in a fixed bar; icons live on a 24 dp grid inside 48 dp targets.
  Because the grid is optically balanced, centering the icon *box* is correct.
- **Conclusion (Model A).** Define one shared optical reference band from the
  title font, then force every element's band center onto one centerline.
  Elements keep their native heights; only their centers are aligned. This is
  Apple's model and needs no per-icon tuning.

## Font metrics used (from each font file's `OS/2`, unitsPerEm-normalized)

All three fonts set `USE_TYPO_METRICS` (`fsSelection` bit 7), so the typo
ascender/descender are authoritative.

| Family (file) | em | cap | x-height | typo asc | typo desc | natural line |
|---|---|---|---|---|---|---|
| Playfair Display (display titles) | 1000 | 0.708 | 0.514 | 1.082 | 0.251 | 1.333 em |
| Inter (UI / labels) | 2048 | 0.728 | 0.546 | 0.969 | 0.241 | 1.210 em |
| Quicksand (play prompts) | 1000 | 0.700 | 0.503 | 1.000 | 0.250 | 1.250 em |

`cap` and `x` are the ink tops above the baseline; `asc`/`desc` are the run's
natural bounds. `x/(asc+desc)` and `cap/(asc+desc)` give the reference band's
position inside the natural run.

## The key finding: Flutter's rendered baseline ≠ an analytic TextPainter

`VDisplayText` renders Playfair at 40 px with `height: 1.0`, so its line box
(40 px) is **shorter** than the font's natural run (1.333 × 40 = 53.3 px).

- A standalone `TextPainter` laid out with the same style reported
  `computeLineMetrics()` ascent `32.468` / descent `7.53` — i.e. it **scaled**
  the run down to the 40 px box (`40 × 1082/1333 = 32.468`).
- The **actually rendered** `Text` instead placed the baseline at `36.62`,
  matching the **half-leading** model (the natural run is centered in the box,
  negative leading split evenly):
  `baseline = (box − natural)/2 + fontSize·ascent`
  `= (40 − 53.32)/2 + 40·1.082 = 36.62`.

This is why every attempt based on a separate `TextPainter` was a few px high.
The header therefore computes the baseline **analytically from the font file's
natural metrics + the style's line-height**, never from a re-laid-out painter.

Reference-band fractions inside the 40 px title box (x-height reference):
`top = 0.4015`, `middle = 0.6585`, `bottom = 0.9155` — the bands the debug red
lines drew (top of `v/e/a/x`, middle, baseline).

## Design shipped (Model A, global)

- `HeaderOpticalReference { capHeight, xHeight }` — one app-wide switch,
  `VHeaderMetrics.opticalReference` (currently **xHeight**). Apple's default is
  cap height; x-height is chosen because the titles are lowercase.
- `_baselineInBox(style, fontSize)` — natural-metric baseline (half-leading for
  a compressed box, proportional scaling for a taller one).
- `_opticalShift(context, style)` — the down-positive offset that centers
  `style`'s reference band inside its own laid-out single-line box, at the
  ambient `MediaQuery.textScalerOf` (accessibility font scaling). Because the
  `Row` centers every child box, adding this shift lands each element's band
  center on the row's center — the shared centerline.
- `VHeaderTitleRow`:
  - **title** → shifted by its font band;
  - **icon actions / back arrow** → aligned by box center (shift 0): Material
    icons are grid-balanced, so the box center is the correct optical center for
    *every* icon variant;
  - **text actions** (`ButtonStyleButton`) → shifted by their label band;
  - composite/unknown actions → box center;
  - `backArrowNudge` / `actionNudge` remain as fine-tune knobs, default `0`.
- `custom titleWidget` (truth/dare two-line header) is **not** covered yet
  (deferred by user directive).

## Verification (on-device, WayDroid 486×1080, dpr 1.125, density 180)

Pixel-scanned the rendered PNGs. All three element centers coincide:

| Screen | title band mid | back arrow ink | action ink |
|---|---|---|---|
| Home `samay` (icon action) | 76 | — | 76 |
| Chats `chats` (arrow + search icon) | 76 | 76 | 75.5 |
| Cadena de Pokes (arrow only) | 76 | 76 | — |

Computed shifts on device: title `-6.34` px (Playfair 40, h 1.0);
text-label `-1.2712` px (Inter 14, h 1.2) — both consistent with the formula.

## Mistakes / gotchas (searchable)

- **MISTAKE — separate `TextPainter` for the baseline.** A re-created painter
  with the same style did **not** reproduce the rendered baseline when the line
  box was compressed by `height` (scaled the run instead of half-leading). Use
  the font's natural metrics analytically.
- **MISTAKE — `RenderParagraph.getDistanceToBaseline` in a post-frame
  callback.** Asserted at `rendering/box.dart:2479` (`debugCheckingIntrinsics`)
  and crashed the app. Baseline can only be read during layout.
- **MISTAKE — `getBoxesForSelection(BoxHeightStyle.tight)` is not glyph ink.**
  It returns the run's font-metric box (ascent→descent), which for an icon font
  overshoots the visible glyph — gave a "top line in the middle" result.
- **MISTAKE — offscreen rasterization at 1×.** The alpha-bounds ink probe must
  rasterize at the device `devicePixelRatio` and use a solid threshold
  (`alpha > ~180`); at 1× it fetched a different hinting/outline and was ~18%
  taller than the on-screen glyph.
- **MISTAKE — hot reload via the Dart VM service.** Calling `reloadSources`
  through the VM service WS fails without `flutter_tools`
  (`ReasonForCancelling: Error while starting Kernel isolate task`). On-device
  iteration required `flutter build apk --debug --target-platform android-x64
  --dart-define-from-file=.env` + `adb install -r`.
- **MISTAKE — a debug overlay must never be committed enabled.** The probe was
  briefly committed with `kDebugHeaderLayout = true`; it is now `false` and the
  probe scaffolding has been deleted.

## Files

- `lib/shared/widgets/v_header_bar.dart` — Model A alignment; debug probe
  removed.
- `lib/shared/widgets/v_display_text.dart` — added `styleFor(size)` (the exact
  rendered style) and `defaultSize`, so callers measure the same metrics.
- `lib/core/design_tokens/app_typography.dart` — per-family cap/x-height and
  typo ascender/descender ratios + lookup helpers.

## Commands

```bash
dart analyze lib/shared/widgets/v_header_bar.dart \
              lib/shared/widgets/v_display_text.dart \
              lib/core/design_tokens/app_typography.dart   # clean

flutter build apk --debug --target-platform android-x64 --dart-define-from-file=.env
adb -s 127.0.0.1:5556 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s 127.0.0.1:5556 shell screencap -p /data/local/tmp/s.png
# then ffmpeg crop + raw-RGB scan of the header rows to compare guide lines
```
