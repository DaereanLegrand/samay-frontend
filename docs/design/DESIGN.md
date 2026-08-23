# Samay — Design System (current)

**Status:** living document. Describes the design language the app ships
**today** and where its source of truth lives in code. Keep it short; when a
token changes in code, change it here in the same commit.

> **Past styles, for the record only:** earlier iterations of this app shipped
> a "disco" look (sharp hairline surfaces, pink-glow accents) and then a
> "disco-luxe" overlay (pastel gradient families everywhere, glass inputs,
> glow widgets). Both are **deprecated** as design directions. Their artifacts
> survive in code only where they still work and are actively used (the
> gradient families in `app_gradients.dart`, `VDisplayText`, `VDiscoDivider`,
> the skeleton system); do not extend them. New UI follows the rules below.

---

## 1. Principles

| # | Rule |
|---|------|
| 1 | **Black always.** Page background is `AppColors.discoBlack` (#000000) on every screen, sheet, and dialog. Gray surfaces (`surface` #0A0A0A, `surfaceAlt` #111111) exist only *under* content as depth — never as the page background. |
| 2 | **Minimal.** One idea per screen. White text on black, generous empty space, no decorative chrome. When in doubt: white-on-black with no accent at all. |
| 3 | **Accents are rare.** Color is used for meaning: error (`error`), status (`statusOnline`, `statusLive`, `statusVip`, `statusRead`, `statusGrey`), currency (`currencyShards`), rank metals (`discoGold/Silver/Bronze`). Never as whole-screen fills or default button colors. |
| 4 | **Type:** Inter for everything functional (UI voice). Playfair Display bold uppercase only for display/hero titles via the shared `VDisplayText` widget. |
| 5 | **Motion is subtle and purposeful** — page fades, spinners, skeleton loaders. Every ambient motion honors `MediaQuery.disableAnimationsOf` (reduced motion → static render, zero tickers). Durations come from `SamayDurations`. **Global kill-switch (ANIM-OFF, 2026-08-14):** `lib/app.dart` force-injects `disableAnimations: true` app-wide, so *all* animation currently renders static; the motion system stays in place for when the flag is lifted. |

## 2. Source of truth (code)

| Layer | File |
|---|---|
| Colors + semantic aliases + contrast helper | `lib/core/design_tokens/app_colors.dart` (`AppColors`, `SamayThemeExtension`) |
| Typography | `lib/core/design_tokens/app_typography.dart` |
| Spacing / radius / elevation / icon sizes | `lib/core/design_tokens/app_spacing.dart`, `app_radius.dart`, `app_elevation.dart`, `app_icon_sizes.dart` |
| Gradient families (legacy but live) | `lib/core/design_tokens/app_gradients.dart` — resolve via `AppGradients.familyOf(screenKey)`; do not invent ad-hoc gradients |
| Motion durations | `lib/core/theme/samay_durations.dart` |
| Theme assembly | `lib/core/theme/app_theme.dart` (dark-only by product decision) |

## 3. Rules that are enforced

- **No raw colors in features.** Screens use `context.samayColors` /
  `SamayThemeExtension` tokens; guards fail builds that introduce literal
  `Color(0x…)` / `Colors.*` into `lib/features/**` and `lib/shared/widgets/`.
- **Pink is not a main.** `glowPink` appears only through
  `AppColors.error`/`errorFill` semantics. Shared-widget accent defaults must
  not reference pink tokens (pinned by `test/widgets/no_pink_defaults_test.dart`).
- **Lists render via builders**, loading/empty/error states use the shared
  views (`VLoadingView`, `VEmptyView`, `VStateView`, skeletons), images go
  through `VNetworkImage`.
- **Routes** are registered in `lib/core/router/route_paths.dart`; screens
  never hardcode path strings.
