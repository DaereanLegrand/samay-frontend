# Samay — Design System (current)

**Status:** living document. Describes the design language the app ships
**today** and where its source of truth lives in code. Keep it short; when a
token changes in code, change it here in the same commit.

> **Past styles, for the record only:** earlier iterations shipped a "disco"
> look (pink-glow accents), a "disco-luxe" overlay (pastel gradient
> families, glass, glows) and a black-always LUXE v2 pass. All are
> **deprecated**. The gradient system (`app_gradients.dart`) was **deleted**
> on 2026-08-26; do not recreate it.

---

## 1. Principles

| # | Rule |
|---|------|
| 1 | **Monochrome.** Black page (`AppColors.discoBlack` #000000), white text, grey depth surfaces (`surface` #0A0A0A, `surfaceAlt` #111111). No decorative gradients, no glows, no decorative hue — user directive 2026-08-26 ("all color stripped down"). A few functional scrim/overlay gradients remain (see §3), and two minigame screens still carry a pastel/hue palette (`drunk_bottle_screen.dart`, `charades_screen.dart` — see §3). |
| 2 | **Minimal.** One idea per screen. Generous empty space, no decorative chrome. |
| 3 | **Color = meaning only.** The surviving hues are semantic flat tokens: error (`error`), status (`statusOnline`, `statusLive`, `statusRead`, `statusGrey`), currency/rank (`currencyShards`, `discoGold/Silver/Bronze`), VIP (`statusVip`). Never as fills for whole surfaces or default button colors. The two minigame screens named in §3 still use `AppColors.pastel*` / `glowPink` / `mint` as game-surface accents pending cleanup. |
| 4 | **Type:** Inter for everything functional. Playfair Display bold for display/hero titles via the shared `VDisplayText` widget — rendered **verbatim** (no case transformation; 'samay', 'Crea tu cuenta') in flat white. No italics (2026-08-14). |
| 5 | **Motion is subtle and purposeful** — page fades and spinners. Every ambient motion honors `MediaQuery.disableAnimationsOf` (OS-level reduced motion). Durations come from `SamayDurations`. Display text has zero tickers by construction. |

## 2. Source of truth (code)

| Layer | File |
|---|---|
| Colors + semantic aliases + contrast helper | `lib/core/design_tokens/app_colors.dart` (`AppColors`, `SamayThemeExtension`) |
| Typography | `lib/core/design_tokens/app_typography.dart` |
| Spacing / radius / icon sizes | `lib/core/design_tokens/app_spacing.dart`, `app_radius.dart`, `app_icon_sizes.dart` |
| Motion durations | `lib/core/theme/samay_durations.dart` |
| Theme assembly | `lib/core/theme/app_theme.dart` (dark-only by product decision) |

## 3. Rules that are enforced

- **No raw colors in features (convention, not enforced).** Screens and widgets
  use the static `AppColors.*` tokens rather than literal `Color(0x…)` /
  `Colors.*`; theme-aware code resolves the same palette through
  `Theme.of(context).extension<SamayThemeExtension>()`. There is **no automated
  build guard** for this — the old `test/meta/conventions_test.dart` guard was
  deleted with the Flutter test trees (directive 2026-08-31). The raw literals
  left outside the token files are the scrim stops inside the sanctioned
  functional gradients of `truth_dare_screen.dart`
  (`Color(0xFF000000)` / `Color(0xE6000000)` and `Colors.transparent` at lines
  104, 114) and a single `Colors.transparent` in
  `drunk_bottle_screen.dart:547`. `truth_dare_choice_button.dart`,
  `attendance_qr_view.dart`, `v_header_bar.dart` and `finished_leaderboard.dart`
  use `AppColors` tokens. Prefer tokens when touching these files.
- **Segmented control is `VPillTabBar`**
  (`lib/shared/widgets/v_pill_tab_bar.dart`) — an approved control: a glass
  track (`AppColors.surface` at 0.85 alpha + a white at 0.15 hairline, the same
  glass language as the header bars; the floating bottom-nav pill follows
  Juega's `PremiumCard` recipe — `surface` α0.1 fill + white α0.15 sheen +
  blur 20 — so the content behind it reads through) with a stadium radius
  (`trackHeight / 2`, 44 pt tap target) and a white active-segment outline.
  The pill shape + glass are scoped to this control; ordinary surfaces stay
  flat and use the `AppRadius` tokens.
- **No gradients as a system.** The monochrome refactor removed the gradient
  system (`app_gradients.dart`); do not recreate it. Functional scrim/overlay
  gradients are still used inline in a few minigame screens
  (`truth_dare_screen.dart`, `finished_leaderboard.dart`) and a
  `groups_tab_screen.dart` shader — these are the only sanctioned exceptions.
- **Two legacy pastel screens.** `lib/features/minigames/screens/drunk_bottle_screen.dart`
  (bottle slice `AppColors.pastel*` palette + category accents) and
  `lib/features/minigames/screens/charades_screen.dart` (`glowPink` / `mint`
  accents) still use non-monochrome hues. They are documented exceptions, not a
  licence for new hue usage elsewhere.
- **Pink is not a general UI color.** Outside those two legacy screens,
  `glowPink` appears only through `AppColors.error`/`errorFill` semantics.
- **Rounded surfaces are scoped to minigame cards.** `lib/features/minigames/
  widgets/games_deck.dart` renders the Games-tab cards with `AppRadius.card`
  (16) so a card reads as a card in the fanned hand (user directive
  2026-09-21). Each card carries **two circulating name bands**
  (`game_name_band.dart`): one flush to the top edge and one to the bottom,
  scrolling in opposite directions so the copy loops like a ring. A band is a
  repeated `icon + lowercase game name` strip in small Playfair
  (`VDisplayText`, size 18 — below the §3.3 display tokens); the old centred
  icon/24px title was removed (user directive 2026-09-21). Bands freeze under
  reduced motion. Each card also carries a background-less **white play glyph**
  (`Icons.play_arrow_rounded`, no container) at its centre and, scattered
  around it, **nested match bubbles** (`match_bubble_field.dart`): one mega
  bubble per recent match, sized by its player count, each nesting up to six
  randomly-sized `ProfileAvatar` bubbles plus a white `+N` overflow. The mega
  bubbles are a deterministic, collision-free scatter that avoids each other,
  the play glyph and the two name-band zones; the newest matches are tried
  first and only the ones that fit are drawn (cap 5). The 2 Lies statement
  cards (`two_lies_screen.dart`) use the same `AppRadius.card` so an input
  reads as a card; every other surface stays sharp
  (`AppRadius.none`) and every other title stays Inter. The deck stays strictly
  monochrome: every card is a `surfaceAlt` fill outlined by a 1px `muted`
  border (profile photos are the same sanctioned exception as the feed's
  cluster). The Games tab is a
  vertical finger-tracked stack: the current game is a centred card (width
  0.8×, height 0.72× ×1.1 of the base, aspect ≈0.727, scaled 1.5×); `cur - 1` sits
  behind and lower (under the nav pill, blurred through it) and `cur + 1`
  behind and higher (under the header), each with a stable random tilt +
  sideways shift. A **vertical drag is two-phase**: the centred card follows
  the finger while its horizontal offset is LOCKED to a quadratic-Bézier arc
  (`x = t² · targetX`), then — once it crosses half a slot — the rest of the
  deck catches up along its own arcs; the release velocity drives a
  `SpringSimulation` settle (snap back below the arrival point) and a tap
  opens the centred game (`2026-09-21`, `games-deck-vertical-bezier`). The
  offset is **unbounded**: dragging past a slot keeps cycling and a hard throw
  is projected through several slots, so the deck keeps flipping instead of
  locking at one card.
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
  Custom title widgets share the same line: the minigame two-line
  `MinigameHeaderTitle` positions its line 1 with
  `VHeaderMetrics.opticalShiftFor`, so a two-line minigame header sits at the
  exact same glyph position as every plain header.
- **Primary CTA voice is `VButton.dark`** (black fill, white text, white
  hairline); `emphasized` (white fill, black text) for auth-form submits;
  `outlined` for secondary actions.
- **Lists render via builders**, loading/empty/error states use the shared
  views (`VLoadingView`, `VEmptyView`, `VStateView`), images go
  through `VNetworkImage`.
- **Routes** are registered in `lib/core/router/route_paths.dart`; screens
  never hardcode path strings.
