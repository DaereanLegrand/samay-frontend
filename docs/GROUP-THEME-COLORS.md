# Group theme colour contract

How a group's theme colour reaches the screen, and the math that keeps every
surface readable. Server side lives in
`backend/supabase/migrations/240_group_theme/01_group_theme.sql`.

## Where the colours come from

The server owns exactly **four** values per group (`get_group_theme`):

| Field | Meaning |
|---|---|
| `background_color` | page colour the host picked (`#RRGGBB`) |
| `foreground_color` | primary text/icon colour, derived server-side |
| `accent_color` | accent fill (badges, selected markers) |
| `accent_foreground_color` | text on the accent |

`background_color` is **clamped dark** server-side (`theme_clamp_dark`, max
relative luminance 0.12) so the app's white-on-dark body copy keeps its
contrast. Both foregrounds are derived with `theme_best_foreground` = whichever
of black/white contrasts more — for any background one of the two is always
≥ 4.58:1.

## The dark rendition

A themed group is painted **75% darker** than the host's pick, with the white
ink replaced by the background's **opposite hue**:

| Server value | Painted as |
|---|---|
| `background_color` | the pick × 0.25 (75% darker) — `darkenAmount` |
| `accent_color` | the pick × 0.25 |
| `foreground_color` (white-ish) | `complement(background_color)` — a blue page gets warm sand text — brightened only as far as AA needs |
| `accent_foreground_color` | `complement(accent_color)`, same clamping |

Example — `#1E3A8A` (blue) becomes `#080F23` with `#E1C575` text (11.3:1).

## What the client derives (and why)

A themed screen cannot only paint the page: cards, bubbles, chips and dividers
need their own tones, and hardcoding the app's `#0A0A0A`/`#111` turns them into
black boxes on a coloured page. So the client derives the rest mathematically
from those darkened values
(`lib/features/groups/theme/group_theme_palette.dart`):

| Role | Rule | AA requirement |
|---|---|---|
| `surface` | darkened background lifted 6% toward the final foreground | primary text ≥ 4.5:1 |
| `surfaceAlt` | darkened background lifted 13% toward the final foreground | primary text ≥ 4.5:1 |
| `mutedForeground` | largest blend of the foreground toward `surfaceAlt` that still reaches 4.5:1 | secondary text ≥ 4.5:1 on **both** steps |
| `hairline` | foreground blended to 1.25:1 against `surfaceAlt` | decorative only |
| `border` | foreground blended to 3.0:1 against `surfaceAlt` | non-text control indicator ≥ 3:1 |

Two guards make this safe for any host pick:

- **Lift is capped.** `_liftWithin` reduces the 6%/13% step until the primary
  text still clears AA, so a light-ish background cannot wash its own text out.
- **Steps stay distinct.** If the AA cap collapses `surfaceAlt` onto `surface`,
  the alternate step is nudged away (toward black on a light theme, white on a
  dark one) so cards still read as raised.

Because `mutedForeground`/`border`/`hairline` are solved against the **lightest**
step (`surfaceAlt`), they are automatically safe on every darker step.

`test/group_theme_palette_test.dart` asserts all of the above for the whole
server palette (`#000000` … `#164E63`) and several accents.

## Where it is applied

`GroupThemeSurface` (`lib/features/groups/theme/group_theme_theme.dart`) is the
single entry point. It mounts two things:

1. `GroupThemeScope` (an `InheritedWidget`) — shared widgets read
   `GroupThemeScope.paletteOf(context)`, which returns
   `GroupThemePalette.standard` (the exact design tokens) when no scope exists,
   so every other screen is byte-identical to before.
2. A re-mapped `ThemeData` (`groupThemeTheme`) — because `GroupThemeScope` only
   serves widgets that ask for it, while Material itself keeps resolving the
   app-wide black defaults: `Chip` wraps itself in a colourless `Material` that
   falls back to `Theme.canvasColor` (black), which is why unselected chips used
   to paint a black box on a coloured page. The themed `ThemeData` sets
   `canvasColor: transparent` (chips reveal the page), plus the scaffold,
   divider, colour-scheme, text/icon, chip, dialog, popup, snackbar, text-button,
   input and tooltip roles.

Surfaces that mount it:

- **Group detail** — banner identity strip, description, action row, events
  section, header menu; loading/error/invited states too.
- **Group chat**.
- **Member list**.
- **Group theme editor**.
- **Group minigames** — hub (`/minigames/:groupId`), the partida lobby and every
  play screen (truth/dare, 2 lies, charades, bottle) and the finished
  leaderboard, via `MinigameSessionSurface` (resolves the session's `group_id`;
  a DIRECT partida stays on the standard theme).

Widgets that are theme-aware:

`VCard` · `VChip` · `VButton` · `VBadge` · `VInput` · `ProfileAvatar` ·
`VEmptyView` · `RankBadge` · `MinigameHeaderTitle` (display voice) ·
chat bubbles (own/peer), date chip, day-divider band, composer bar, timestamps
and delivery ticks · `MinigamePoolAmount` · minigame game/session cards, scope
row and group banner avatar · the group surfaces' own inks.

The donate action is an **overlay** on group detail
(`showDonateToGroupDialog` in `lib/features/groups/widgets/donate_shards_dialog.dart`):
a centered themed `Dialog` over a dimmed barrier — it is not a route.

`test/group_theme_palette_test.dart` pins the derivation math and the themed
`ThemeData` (canvas transparency, chip fills, palette roles). UI-level widget
tests are intentionally not kept (see `frontend/AGENTS.md`: testing is
backend-only apart from these light math/theme assertions).

## Adding a new surface

1. Wrap the screen in `GroupThemeSurface(groupId: …, child: Scaffold(
   backgroundColor: palette.background, …))` — or, for a minigame,
   `MinigameSessionSurface(sessionId: …)`.
2. Use the palette for fills/borders/text instead of `AppColors` constants; add
   a themed branch to a shared widget if it paints its own fill
   (`MinigameInks.of(context)` is the minigame-side helper).
