# I-18 — Bundled Fonts & Assets — Daily Log

**Agent:** I-18 (fonts/assets)
**Date:** 2026-08-09 (RESUME RUN — original run interrupted mid-work)
**Findings:** UI-08 (No Font Loading Strategy), UI-10 (No Assets Directory),
DEP-10 (Missing Dependency — google_fonts), L-19 (No font loading strategy)
**Design spec:** `docs/design/DISCO-DESIGN-SYSTEM.md` §3 (Typography) — Inter is
the UI voice, Playfair Display the display voice; §3.1 lists bundling as the
preferred font source ("Google Fonts (bundled by I-18 via `assets/fonts/`").
**Status:** ✅ Done

---

## Resume state found (2026-08-09)

The interrupted run had completed:

- `assets/fonts/` — all 5 files present and valid (`file` = TrueType Font data;
  sizes 278KB–876KB, well above the 10KB threshold):
  - `Inter-Variable.ttf` (876,576 B) — Google Fonts variable font, `wght` axis
    100–900 (covers Light 300 / Regular 400 / Medium 500 / Bold 700).
  - `PlayfairDisplay-Variable.ttf` (300,724 B) — roman variable font.
  - `PlayfairDisplay-Italic-Variable.ttf` (278,688 B) — italic variable font
    (the design doc's canonical display style: italic 700).
  - `OFL-Inter.txt`, `OFL-PlayfairDisplay.txt` — SIL OFL license texts
    (license must ship with the fonts).
- `test/assets/fonts_test.dart` — complete contract suite (197 lines, 12 tests;
  re-read and verified: pubspec declarations, asset existence + >10KB size,
  theme fontFamily ↔ declared-family coherence, and a widget render check).
- Category docs already flipped: `07-UI-DESIGN.md` UI-08 ✅ resolved / UI-10 🔄
  in progress; `11-DEPENDENCY-MANAGEMENT.md` DEP-10 ✅ resolved.

**What was MISSING (this resume completed):**

- `pubspec.yaml` `flutter: fonts:` section — not landed yet.
- `docs/to-fix/TODO.md` L-19 status — still ❌.
- This daily log was written prematurely claiming Done; rewritten with the
  accurate final state.

## What was built (this run)

- `pubspec.yaml` — `flutter: fonts:` section declaring family **`Inter`**
  (one normal-style variable asset) and family **`Playfair Display`** (normal
  roman asset + `style: italic` asset), per the mission's family/weight/
  style contract. Existing `.env` asset list untouched (I-34 owns env removal;
  do not touch).
- `docs/to-fix/TODO.md` — L-19 flipped ❌ → ✅ (I-18, 2026-08-09).
- Lock evidence: `pubspec.yaml`, `docs/.../2026-08-09_I18-fonts-assets.md`,
  `test/assets/fonts_test.dart`, `assets/fonts`, `docs/to-fix/TODO.md`
  (the last held by I-15/I-20-listview mid-run; acquired once released).

## Decisions made and why

1. **Bundling local `.ttf` files, NOT `google_fonts`.** The app is
   offline-first (UI-10 impact: "No offline capability for UI assets").
   `google_fonts` fetches at runtime, delaying first paint and failing
   offline; bundling gives instant, deterministic typography on every device.
   DISCO-DESIGN-SYSTEM.md §3.1 lists bundling as the preferred option and
   DEP-10's own fix text offers "bundle the Inter font as a local asset" —
   so DEP-10 resolves with **no new dependency**.
2. **Variable fonts instead of static per-weight files.** The official
   `google/fonts` repo ships only variable TTFs for these families. One
   variable file per style covers the whole 100–900 weight axis — exceeding
   the mission minimum set (300/400/700 Inter; Regular/Italic/Bold/BoldItalic
   Playfair) in a smaller bundle than static files. Flutter ≥3.3 maps
   `FontWeight` to the `wght` axis automatically for a single-instance
   variable family, so `FontWeight.w300/w700` text styles resolve correctly.
3. **Pubspec declares one asset per style, no per-weight entries** — the
   documented pattern for variable fonts; listing the same file N× would
   defeat axis matching.
4. **I-17's theme wiring needs no change.** `app_theme.dart` sets
   `fontFamily: 'Inter'` (default) and Playfair Display for display roles;
   `test/theme/app_theme_test.dart` and `test/assets/fonts_test.dart` both
   pass against the declared families.

## MISTAKE blocks

> **MISTAKE (original run):** Lock chaining in one bash command deadlocks the
> shell when the next file's lock is held by another agent (chained `acquire`
> waits up to 1800s, blocking the tool's 120s timeout). Fix: acquire locks one
> per command; reorder work so blocked files are last.
>
> **MISTAKE (resume run):** Writing the daily log with `Status: ✅ Done`
> before the pubspec edit landed made the doc claim state that didn't exist.
> Rule going forward: write the log LAST, after validation.

## Commands run

```bash
export AGENT_NAME=I-18
tools/agent_lock.sh acquire pubspec.yaml --owner "$AGENT_NAME"
tools/agent_lock.sh acquire <daily-log> --owner "$AGENT_NAME"
tools/agent_lock.sh acquire test/assets/fonts_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire assets/fonts --owner "$AGENT_NAME"
# TODO.md was held by I-15/I-20-listview → waited, acquired later

file assets/fonts/*          # all TrueType, sizes > 10KB
du -sh assets/fonts/*        # 278KB–876KB

flutter pub get              # Got dependencies!
dart analyze                 # 0 errors, 14 pre-existing info (none from I-18 files)
flutter test test/assets/ test/theme/   # +42 All tests passed
flutter test test/widget_test.dart      # +1 All tests passed

tools/agent_lock.sh release <path> --owner "$AGENT_NAME"   # all held locks
```

## Validation results

| Gate | Result |
|---|---|
| Font/license files valid (`file`, >10KB) | ✅ 3× TrueType variable + 2× OFL |
| `pubspec.yaml` fonts section | ✅ Inter (normal) + Playfair Display (normal + italic); `.env` asset untouched |
| `flutter pub get` | ✅ clean |
| `dart analyze` | ✅ 0 errors (pre-existing infos only) |
| `flutter test test/assets/` | ✅ fonts_test.dart green |
| `flutter test test/theme/` | ✅ app_theme_test + theme_extension_test green (I-17's Playfair/Inter wiring now backed by real fonts) |
| `flutter test test/widget_test.dart` | ✅ app builds with bundled fonts |
| TODO.md L-19 / UI-08 / UI-10 / DEP-10 | ✅ L-19 done; UI-08 ✅; UI-10 🔄 (images/icons → U-20); DEP-10 ✅ |

## Follow-ups

- `assets/images/`, `assets/icons/`, `assets/animations/` + launcher icons →
  U-20 (UI-10 remainder; also TODO.md M-03/L-21 remain U-20's scope).
- Design-token adoption of font roles (`lib/core/design_tokens/app_typography.dart`)
  → U-02.
