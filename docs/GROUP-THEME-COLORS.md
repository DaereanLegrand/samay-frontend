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

## What the client derives (and why)

A themed screen cannot only paint the page: cards, bubbles, chips and dividers
need their own tones, and hardcoding the app's `#0A0A0A`/`#111` turns them into
black boxes on a coloured page. So the client derives the rest mathematically
from the four server values
(`lib/features/groups/theme/group_theme_palette.dart`):

| Role | Rule | AA requirement |
|---|---|---|
| `surface` | background lifted 6% toward the foreground | primary text ≥ 4.5:1 |
| `surfaceAlt` | background lifted 13% toward the foreground | primary text ≥ 4.5:1 |
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

`GroupThemeScope` (an `InheritedWidget`) is mounted by the three surfaces the
owner decision names: **group chat**, the **member list** and **group
minigames** (plus the theme editor, which is part of that surface). Shared
widgets read `GroupThemeScope.paletteOf(context)`, which returns
`GroupThemePalette.standard` — the exact design tokens — when no scope exists,
so every other screen is byte-identical to before.

Widgets that are theme-aware:

`VCard` · `VChip` · `VButton` · `VBadge` · `VInput` · `ProfileAvatar` ·
`VEmptyView` (icon tint) · chat bubbles (own/peer), date chip, day-divider band,
composer bar, timestamps and delivery ticks · `MinigamePoolAmount` ·
minigame game/session cards, scope row and group banner avatar.

`test/group_theme_widgets_test.dart` pins each of these in both states (inside
and outside a scope).

## Adding a new surface

1. Mount `GroupThemeScope` around the screen body (and set
   `Scaffold.backgroundColor: palette.background`).
2. Use the palette for fills/borders/text instead of `AppColors` constants; add
   a themed branch to the shared widget if it paints its own fill.
3. Add a widget test asserting the themed fill is `palette.*` and that the
   un-themed fallback is still the design token.
