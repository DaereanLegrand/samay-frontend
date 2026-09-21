# Samay — Design System (current)

**Status:** living document. Describes the design language the app ships
**today** and where its source of truth lives in code. Keep it short; when a
token changes in code, change it here in the same commit.

> **Past styles, for the record only:** earlier iterations shipped a "disco"
> look (pink-glow accents), a "disco-luxe" overlay (pastel gradient
> families, glass, glows) and a black-always LUXE v2 pass. All are
> **deprecated**. The gradient system (`app_gradients.dart`) was **deleted**
> on 2026-08-26; do not recreate it (the conventions guard fails any lib/
> reference).

---

## 1. Principles

| # | Rule |
|---|------|
| 1 | **Monochrome.** Black page (`AppColors.discoBlack` #000000), white text, grey depth surfaces (`surface` #0A0A0A, `surfaceAlt` #111111). No gradients, no glows, no decorative hue — user directive 2026-08-26 ("all color stripped down"). |
| 2 | **Minimal.** One idea per screen. Generous empty space, no decorative chrome. |
| 3 | **Color = meaning only.** The surviving hues are semantic flat tokens: error (`error`), status (`statusOnline`, `statusLive`, `statusRead`, `statusGrey`), currency/rank (`currencyShards`, `discoGold/Silver/Bronze`), VIP (`statusVip`). Never as fills for whole surfaces or default button colors. |
| 4 | **Type:** Inter for everything functional. Playfair Display bold for display/hero titles via the shared `VDisplayText` widget — rendered **verbatim** (no case transformation; 'samay', 'Crea tu cuenta') in flat white. No italics (2026-08-14). |
| 5 | **Motion is subtle and purposeful** — page fades and spinners. Every ambient motion honors `MediaQuery.disableAnimationsOf` (OS-level reduced motion). Durations come from `SamayDurations`. Display text has zero tickers by construction. |

## 2. Source of truth (code)

| Layer | File |
|---|---|
| Colors + semantic aliases + contrast helper | `lib/core/design_tokens/app_colors.dart` (`AppColors`, `SamayThemeExtension`) |
| Typography | `lib/core/design_tokens/app_typography.dart` |
| Spacing / radius / elevation / icon sizes | `lib/core/design_tokens/app_spacing.dart`, `app_radius.dart`, `app_elevation.dart`, `app_icon_sizes.dart` |
| Motion durations | `lib/core/theme/samay_durations.dart` |
| Theme assembly | `lib/core/theme/app_theme.dart` (dark-only by product decision) |

## 3. Rules that are enforced

- **No raw colors in features.** Screens use `context.samayColors` /
  `SamayThemeExtension` tokens; guards fail builds that introduce literal
  `Color(0x…)` / `Colors.*` into `lib/features/**` and `lib/shared/widgets/`.
- **No gradients, anywhere.** The monochrome refactor removed the gradient
  system; the convention is documented in `docs/process/` (the old
  `test/meta/conventions_test.dart` guard was deleted with the Flutter test
  trees — directive 2026-08-31).
- **Pink is not a UI color.** `glowPink` appears only through
  `AppColors.error`/`errorFill` semantics.
- **Display copy routes through `VDisplayText`** — verbatim case, white
  glyphs, size-token mapping (64/40/32/28).
- **Header vertical alignment is optical, not geometric.** Every header routes
  its back arrow / title / actions through `VHeaderTitleRow`, which centers all
  three on **one shared optical centerline** derived from the title font's
  natural metrics (cap- or x-height; switch in `VHeaderMetrics.opticalReference`).
  Icons align by their grid-balanced box, text by its font band, so it holds at
  any font size. Never add per-screen vertical nudges; the fine-tune knobs are
  `VHeaderMetrics.backArrowNudge` / `actionNudge`. Full rationale in
  `docs/history/phase-16/2026-09-11_header-optical-alignment.md`.
- **Primary CTA voice is `VButton.dark`** (black fill, white text, white
  hairline); `emphasized` (white fill, black text) for auth-form submits;
  `outlined` for secondary actions.
- **Lists render via builders**, loading/empty/error states use the shared
  views (`VLoadingView`, `VEmptyView`, `VStateView`), images go
  through `VNetworkImage`.
- **Routes** are registered in `lib/core/router/route_paths.dart`; screens
  never hardcode path strings.
