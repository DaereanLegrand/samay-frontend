# Samay — Disco Design System (DISCO-DESIGN-SYSTEM)

**Owner:** D-11 (spec author) → implemented by U-01..U-30 (see §8) → finalized by U-30
**Status:** v1.0 — authoritative spec. Read-only reference; implementers may not silently deviate.
**Date:** 2026-08-09
**Upstream specs:** `docs/planification/samay_mvp_spec.md` §1 (Product Vision & Positioning / Design Language), `docs/implementation/phase-02-flutter-foundation/DSNG-design-system-theme.md`, `docs/to-fix/categories/07-UI-DESIGN.md`, `docs/to-fix/LESSONS_FROM_JUEGA.md`, `docs/implementation/cross-references.md` (row D-11).

> **Brand directive (user):** *This is a DISCO AND SOCIAL LIFE app. Background ALWAYS black. A lot of soft disco colors WITH contrast — or just white — but keep MINIMALIST. Fancy/ultra-fancy titles use the **Playfair Display** serif font.* The signature is a **soft pink glow on black**. Samay is **not** Juega — different colors, same high bar of UI/flow quality.

---

## 1. Brand Pillars

| # | Pillar | Rule |
|---|--------|------|
| P1 | **Black always** | `scaffoldBackgroundColor` is `#000000` in every screen, every sheet, every dialog. No light mode, no gray app background. Gray `#0A0A0A`/`#111111` surfaces are allowed only *under* content as depth (cards, overlays), never as the page background. |
| P2 | **Minimalist** | One idea per screen. Generous black space. No decorative chrome, no gradients in chrome, no rounded pastels, no drop shadows on boxes (flat + hairline only). White core, gray for hierarchy. |
| P3 | **Disco glow accents** | Pink glow is the brand signature — **display titles and brand moments only** (see §3.4 usage rules). Accent colors are always used *with contrast* against black, never for whole-screen fills. When in doubt: **white**. |
| P4 | **Premium editorial** | Mirror of `samay_mvp_spec.md` §1: "luxury streetwear brand meets nightlife app. No rounded pastel. No friendly startup. Sharp, clean, aspirational." Serif display type (Playfair Display) is the editorial voice; Inter is the UI voice. |
| P5 | **Disco, not carnival** | Motion is subtle and fast; the only "breathing" is the glow. Respect `MediaQuery.disableAnimations` (see §6, §7). |

**White-only mode (P2 fallback):** when a screen's accent needs are unclear, render it fully white-on-black (white text, white hairlines, white icons). Accent colors are privileges, not defaults.

---

## 2. Color Palette Tokens

### 2.1 Neutrals (core)

| Token | Hex | Usage | Contrast vs `#000000` |
|---|---|---|---|
| `discoBlack` | `#000000` | Page background — **always** | 1:1 (n/a) |
| `surface` | `#0A0A0A` | Card/overlay fills, bottom nav background | 1.06:1 (depth only) |
| `surfaceAlt` | `#111111` | Raised surfaces (sheets, menus, skeleton base) | 1.11:1 (depth only) |
| `hairline` | `#1A1A1A` | Card borders, dividers (decorative) | 1.21:1 (decoration — see §7.2) |
| `border` | `#333333` | Interactive outlines (unselected chips, avatar rings) | 1.66:1 (non-text 3:1 rule applies where the outline *is* the control indicator — see §7.2) |
| `muted` | `#666666` | Placeholder text, disabled text, unselected nav icons | 3.66:1 — **large text only** (AA-large); see §2.4 |
| `mutedStrong` | `#999999` | Secondary/label text, hints | 7.37:1 — AA |
| `white` | `#FFFFFF` | Primary text, icons, emphasized fills | 21:1 — AA/AAA |

### 2.2 Signature glow pink

| Token | Hex | Usage | Contrast vs `#000000` |
|---|---|---|---|
| `glowPink` | `#FF2E88` | **The signature.** Display titles with glow, brand accents, selected/highlight states, glow buttons | **6.00:1 — AA** |
| `glowPinkBright` | `#FF5CA8` | Glow halo layers, pressed/hover accent tint | 7.35:1 — AA |
| `glowPinkDeep` | `#C2185B` | Pressed state of pink fills, dark-on-pink text pairing | 3.58:1 — AA-large only |

**Rationale for `#FF2E88`:** a hot pink in the saturated magenta family — the canonical "neon disco" hue (references: the brand CSS uses `--pink`; `#FF2E88` is the middle of the classic hot-pink range). Computed relative luminance `L = 0.250` gives **6.00:1 on black**, exceeding WCAG 2.2 AA for normal text (4.5:1) and approaching AAA (7:1). Alternatives considered: `#E91E63` (Material pink, 4.83:1 — passes but muddier, reads more "Material" than disco), `#FF4D9E` (6.81:1 — softer; reserved as a lighter tint family, not the signature). `#FF2E88` is the *brightest* hot pink that still passes AA at normal size — the most "glow" the brand can legally afford.

### 2.3 Soft disco accents (status/icons only)

Contrast-first usage rules in §2.5. All pass AA or better as text on black.

| Token | Hex | Usage | Contrast vs `#000000` |
|---|---|---|---|
| `discoViolet` | `#8B5CF6` | VIP/subscription tier, premium badges, "pro" features | **4.96:1 — AA** |
| `discoCyan` | `#00E5FF` | Live/online indicators, realtime dots, info links | **13.65:1 — AAA** |
| `discoGold` | `#FFC94D` | **Shards currency** (replaces white diamond in `VShardIcon`), rank tier 1, leaderboard top | **13.71:1 — AAA** |
| `discoSilver` | `#C0C0C0` | Leaderboard tier 2, secondary ranks | 11.54:1 — AAA |
| `discoBronze` | `#CD7F32` | Leaderboard tier 3, bronze ranks | 6.68:1 — AA |

### 2.4 Muted-text rule (important)

`muted #666666` on black is **3.66:1** — it fails WCAG 1.4.3 for normal-size text (needs 4.5:1). It is legal only for:
- Placeholder/hint text inside inputs **that is never the only source of meaning** (the `labelText`/`hintText` must be re-declared on the field itself, which is white text), or
- Disabled controls (inactive UI components are exempt per WCAG 1.4.3 "Incidental"), or
- Text ≥ 24px (or ≥ 18.5px bold).

Any *informational* text below those sizes must use `mutedStrong #999999` (7.37:1) or white. `#666666` remains the correct **icon** color for unselected bottom-nav items (non-text contrast 3:1 — 3.66:1 passes).

### 2.5 Contrast-first usage rules

1. **Accent = text/icon on black, or black text on accent fill.** All accents ≥ 4.5:1 as *text on black*, so accent text is always legal at normal size. On accent *fills*, use black text (pink fill + black text = 6.00:1).
2. **Never white text on a pink/violet fill** — white-on-`#FF2E88` is 3.50:1, failing 1.4.3. (Exception: `glowPinkDeep` fill with white text = 5.87:1, allowed for dark-red pressed states.)
3. **Never use an accent where white suffices.** Accent budget: max ~10% of any screen's pixels; glow titles count as one accent zone.
4. **Never pair two accents** as foreground+background (e.g., violet text on cyan fill) — luminance math is not predictable; use accent + black/white only.
5. **Color is never the only signal** — every accent-coded state (online, VIP, rank, shard balance) also carries a text label, icon, or position change (WCAG 1.4.1 Use of Color).
6. **`glowPinkDeep` and any accent at opacity < 1** may only be used decoratively (glow halos, pressed scrims) — never as the sole text color.

---

## 3. Typography

### 3.1 Font roles

| Font | Role | Source |
|---|---|---|
| **Playfair Display** (serif) | **Display/fancy titles ONLY** — italic + bold. See exact usages §3.2. | Google Fonts (bundled by I-18 via `assets/fonts/`, wired by U-02; `google_fonts` fallback permitted) |
| **Inter** | Everything else: UI text, body, buttons, inputs, labels, nav, numbers. | Google Fonts / bundled (current `fontFamily: 'Inter'` in `lib/core/theme/app_theme.dart:21`; keep it as the default) |

### 3.2 Playfair Display — exact usages (exhaustive)

Use italic 700. **Nowhere else.** If a text role isn't in this list, it's Inter.

| Screen / element | Where | Size |
|---|---|---|
| Welcome screen wordmark ("SAMAY") | `lib/features/auth/welcome_screen.dart` (currently `Text('VIVE')` + `displayLarge`) | 64 |
| Auth flow big headers ("Crea tu cuenta", "¿Cuál es tu fecha de nacimiento?", "Verificar edad"…) | `signup_contact_screen.dart`, `age_gate_screen.dart`, `otp_verification_screen.dart`, `privacy_terms_screen.dart` | 40 |
| Feed hero header ("SAMAY" / "Eventos") | `feed_screen.dart`, `app_router.dart` shell AppBar titles | 32 |
| Event titles — featured/hero cards | Phase 05 `ECRT/EDET` event screens (future) | 28 |
| Leaderboard podium group names (top 3) | `leaderboard_screen.dart` | 28 |
| Group names on detail hero | `group_detail_screen.dart` | 28 |
| Coming-soon "Próximamente" | `v_coming_soon.dart` | 32 |

**Do NOT use Playfair for:** button labels, inputs, chips, badges, list tiles, body copy, settings rows, dialogs, tab labels, notification text, numbers, prices.

### 3.3 Type scale table (Flutter `TextTheme` + tokens)

Implement in `lib/core/design_tokens/app_typography.dart` (U-02). All sizes are *minimums* — text scaling multiplies them; never fix a height that clips.

| Flutter style | Family | Size | Weight | Letter-spacing | Height | Usage |
|---|---|---|---|---|---|---|
| `displayLarge` | Playfair Display | 64 | w700 *italic* | -1.9 (~-0.03em) | 1.0 | Welcome wordmark (glow) |
| `displayMedium` | Playfair Display | 40 | w700 *italic* | -1.2 (~-0.03em) | 1.0 | Auth flow big headers (glow) |
| `displaySmall` | Playfair Display | 32 | w700 *italic* | -1.0 | 1.05 | Feed hero, coming-soon, section heroes |
| `headlineLarge` | Playfair Display | 28 | w600 *italic* | -0.8 | 1.1 | Event titles, podium names, group hero |
| `headlineMedium` | Inter | 24 | w700 | -0.3 | 1.2 | Screen headers (current `headlineMedium`) |
| `headlineSmall` | Inter | 20 | w600 | -0.2 | 1.3 | Card titles |
| `titleLarge` | Inter | 18 | w600 | 0 | 1.4 | List item titles |
| `titleMedium` | Inter | 16 | w500 | 0 | 1.4 | List subtitles |
| `bodyLarge` | Inter | 16 | w300 | 0 | 1.5 | Body copy (keep light per MVP spec) |
| `bodyMedium` | Inter | 14 | w300 | 0 | 1.5 | Secondary body |
| `bodySmall` | Inter | 12 | w400 | 0 | 1.5 | Captions, timestamps |
| `labelLarge` | Inter | 14 | w700 | 1.2 (uppercase) | 1.2 | Button labels (current `labelLarge`) |
| `labelMedium` | Inter | 12 | w600 | 0.8 (uppercase) | 1.3 | Chips, small buttons, tab labels |
| `labelSmall` | Inter | 10 | w500 | 1.2 (uppercase) | 1.3 | Badges, rank labels, overlines |
| `otpInputText` | Inter | 30 | w800 | 8 | 1.5 | OTP code input |

### 3.4 Glow text style spec (the signature)

Rendered via Flutter `TextStyle.shadows` (equivalent to the user's CSS `text-shadow: 0 0 0.35em/0.7em/1em var(--pink)`). In Flutter, `em` is relative to font size; `Shadow.blurRadius` is in logical px. **Canonical stacks:**

| Variant | Shadows (blurRadius = f(fontSize)) | Use |
|---|---|---|
| `glow-strong` | 3 layers: `glowPink` α0.9 · `fontSize×0.35` · α0.5 at `fontSize×0.7` · α0.25 at `fontSize×1.0` | Display titles ≥ 32px (welcome wordmark, auth headers) |
| `glow-soft` | 2 layers: `glowPink` α0.6 · `fontSize×0.3` · α0.25 at `fontSize×0.6` | Headlines 28px (event titles, podium) |
| `glow-hairline` | 1 layer: `glowPink` α0.35 · `fontSize×0.25` | Small brand accents, icon halos |

Exact constants live in the typography/theme tokens (U-02/U-04). **Legibility contract:** the text fill is ALWAYS full-opacity (never blur-only text, never translucent glyphs) — the shadow is strictly *behind* the glyphs (Flutter shadows render behind the fill). Per WCAG 1.4.3, a wide halo counts as *background* for contrast evaluation, so the fill itself carries the ratio — `glowPink` fill on black = 6.00:1 (AA). See §7.4 for the animation amplitude floor.

---

## 4. Tokens (design tokens, implemented by U-03)

### 4.1 Spacing — `app_spacing.dart`

8-step scale + semantic aliases (mirrors Juega's *structure*; values are Samay's own):

```
none 0 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48
```

| Semantic | Value | Notes |
|---|---|---|
| `screenHorizontal` | xl (24) | matches current screens |
| `screenVertical` | xl (24) | |
| `cardPadding` | lg (16) | matches `v_card.dart` |
| `buttonPadding` | lg (16) | matches `v_button.dart` |
| `inputPadding` | lg (16) | |
| `listGap` | sm (8) | |
| `sectionGap` | xl (24) | |
| `avatar` / `avatarLarge` | 40 / 80 | |
| `scale(context, v)` | `v * MediaQuery.textScalerOf(context).scale(1)` | responsive spacing (finding UI-09) |

### 4.2 Radius — `app_radius.dart` (SHARP — per MVP spec "no rounded pastel")

```
none 0 · xs 2 (unused) · sm 4 (unused) · md 8 (unused) · lg 12 (unused)
```

**Every UI component radius = `0`.** Buttons, cards, chips, inputs, dialogs, sheets, badges — all sharp. Exceptions (only these): avatars `full` (circle), live/online dots (circle), `BottomSheet` top corners 0 (flush), progress spinners (natively round). `#333333` hairline borders carry the geometry; no rounded pastel anywhere.

### 4.3 Elevation — `app_elevation.dart` (flat)

No drop shadows on boxes. `List<BoxShadow>`:

| Token | Value |
|---|---|
| `none` | `[]` |
| `card` | `[]` (hairline border instead — flat editorial) |
| `glowPink` | `[BoxShadow(color: glowPink α0.45, blurRadius: 24), BoxShadow(color: glowPink α0.2, blurRadius: 48)]` — brand moments only (featured card behind a CTA) |
| `glowCyan` | same stack with `discoCyan` — live indicators, QR scanner ring |

### 4.4 Icon sizes — `app_icon_sizes.dart`

```
xs 12 · sm 16 · md 20 · lg 24 · xl 32 · xxl 48 · avatar 40 · avatarLarge 80
```

### 4.5 Durations — `lib/core/theme/samay_durations.dart` (source of truth, U-18)

| Token | Value | Use |
|---|---|---|
| `fast` | 150ms | button press, chip select, icon swaps, focus states |
| `standard` | 250ms | page transitions, dialog/sheet open, snackbar |
| `slow` | 500ms | hero/display fade-in, glow *settle* |
| `defaultCurve` | `easeOutCubic` | all transitions |
| `glowBreath` | 3000ms | disco-glow breathing (see §6.2) |
| `shimmer` | 1200ms | skeleton shimmer sweep |
| `pageTransition` | `standard` (250ms) | `PageRouteBuilder` fade-through |

---

## 5. Component Specs

Component map → existing widgets in `lib/shared/widgets/` (restyled by U-05/U-06) + `lib/shared/widgets/state_views.dart` (I-74).

### 5.1 Buttons — `v_button.dart` (U-05)

| Variant | Spec | Tokens |
|---|---|---|
| `VButton` (outlined, default) | 1px white border (`BorderSide(color: white)`), transparent fill, white text `labelLarge`, sharp corners, full-width, 14px vertical padding | `border white` · `text white` |
| `VButton.emphasized` | White fill, black text `labelLarge`, sharp, full-width | `fill white` · `text discoBlack` |
| `VButton.glowAccent` (NEW, U-05) | Pink 1px border OR pink fill + black text; text may carry `glow-hairline` shadow. Pressed: `glowPinkDeep` fill + white text (5.87:1). Use ≤ 1 per screen — always a primary action | `border/fill glowPink` · `text discoBlack` · pressed `glowPinkDeep` |
| Loading | same shape, `CircularProgressIndicator(strokeWidth: 2)` in foreground color (current behavior) | |
| Disabled | `onPressed: null`; outline/text drop to `#666666` (exempt from contrast as inactive component) | `muted` |
| Press feedback | `fast` (150ms), white/black overlay at α0.1 — no scale, no bounce | |

### 5.2 Inputs — `v_input.dart` (U-05)

- **Underline style** (current): no box, no border radius, 1px white bottom rule; focused = 2px white rule.
- Labels `labelStyle`: `mutedStrong #999999` (fix from `#666666` — current label fails 1.4.3 at normal size; see §2.4).
- Hints: `#666666` allowed (they are placeholders re-declared by labels; keep label legible).
- Text: white, `bodyLarge`. Focus accent variant (U-05 opt-in): focused rule + label in `glowPink` when the field is brand-primary (login password, shard amount).
- Error text: white on `glowPinkDeep` chip or `glowPink` text at ≥4.5 (pink text on black 6.0 — legal). Never raw `Colors.red` on black alone (red-on-black protanopia advisory; use `glowPink`/`glowPinkDeep` instead).
- `textScaler` honored; multiline inputs wrap.

### 5.3 Cards — `v_card.dart` (U-05)

- Black fill (`#0A0A0A` over black), **hairline borders** (`#1A1A1A` 1px), sharp corners, `cardPadding` 16.
- Hairline is *depth decoration* (see §7.2 boundary rule). A card is never the only indicator of interactivity — the tile text/chevron carries that.
- Featured/hero card (new `VCard.featured`, U-06): `glowPink` 1px border or faint `glowPink` α0.15 fill — reserved for the event of the night / featured feed card.

### 5.4 Chips — `v_chip.dart` (U-05)

- Default: transparent, 1px white border, white `labelMedium`; selected = white fill + black text (current).
- `VChip.accent`: 1px `glowPink` border + pink label; selected = `glowPink` fill + black text. Sharp corners. `fast` selection animation.
- Tier chips on `leaderboard_screen.dart` keep default white-on-white-select (minimal); accent only where the app brand asks for it.

### 5.5 Badges — `v_badge.dart` + `rank_badge.dart` (U-05)

- `VBadge`: sharp, `#333333` fill + white text (borders don't need contrast if the badge shape+fill+text identify it — fill vs black = 1.66:1, so the *text* carries the info). Emphasized variant: white fill + black text.
- `VBadge.accent` (status): `glowPink`/`discoCyan`/`discoViolet` border + same-color text; fill stays black. Accent fills only for "NEW"/"LIVE" urgency with black text.
- `RankBadge`: keep `#333333` fill + white bold 11px label, uppercase, sharp. Podium enhancement (U-05): rank bracket labels on the **top-3 leaderboard rows** get gold/silver/bronze accent: `discoGold`/`discoSilver`/`discoBronze` border + label color (all AA on black). Non-top rows stay white.
- Live/online dot: `discoCyan` 8px circle (13.65:1 — clearly visible non-text indicator), with a text label nearby (1.4.1).

### 5.6 Shard icon — `v_shard_icon.dart` (U-05)

- `Icons.diamond`, **`discoGold #FFC94D`** at 16px default (was white). Gold is the currency color (13.71:1 on black; as an icon it far exceeds the 3:1 non-text requirement).
- White-only mode: white diamond. Sizes: `xs 12` (inline in list subtitles) · `sm 16` (default) · `lg 24` (balance cards).

### 5.7 Coming-soon screens — `v_coming_soon.dart` (U-12)

- Keep structure; restyle: AppBar transparent/black, icon at `xxl 48` in `#333333` (or faint `glowPink` α0.5 for hero-topic screens like Party Finder), "Próximamente" in Playfair Display italic 32 with `glow-soft`, description `mutedStrong`, back button outlined.
- Never show a full-screen accent; never animate more than the icon fade (`slow` 500ms) + glow breathing (respecting reduced motion).

### 5.8 Loading states — `state_views.dart` (I-74) + skeletons (U-22)

- Full-screen load: white `CircularProgressIndicator` (24px) centered on black, optional `mutedStrong` caption. Accent variant: `glowPink` spinner for brand moments (welcome, checkout).
- Skeleton/shimmer: `surfaceAlt #111111` blocks, sharp corners, shimmer sweep `shimmer` 1200ms, α 0.5→0.9. No color; keep gray. Disable shimmer animation when `disableAnimations`.
- **Never** a full-screen colored overlay; the loading overlay (I-74) is black α0.6 + card.

### 5.9 Empty states — `state_views.dart` (U-21)

- Icon `xxl 48` in `#333333`, `headlineSmall`/`bodyMedium` text in `mutedStrong`, optional outlined CTA. Centered, `sectionGap` spacing. No accent unless the CTA is the only element (then `VButton.emphasized`).

---

## 6. Motion

### 6.1 Principles (mirror of DSNG + MVP §1 "no cartoon animations")

- Subtle, fast, fade/slide only. **No scale, bounce, elastic, or rotation.**
- Transitions: `PageRouteBuilder` fade-through, `standard` (250ms), `easeOutCubic`.
- Micro-interactions: button press overlay 150ms, chip select 150ms, list item fade-slide-in `slow` (500ms) staggered ≤ 60ms apart, snackbar/dialog `standard`.

### 6.2 Disco-glow breathing animation (the one allowed ambient motion)

- **Scope:** display titles with `glow-strong` (welcome wordmark, auth headers) and the coming-soon icon halo. One breathing element per screen, max.
- **Spec:** animate the glow *opacity/alpha* (not the glyphs) on a 3000ms `easeInOut` `alternate` loop, amplitude α **0.75 → 1.0** of the canonical stack. Implementation: `AnimatedBuilder`/`AnimationController` multiplying shadow alpha, or `flutter_animate`'s `.animate().then().shimmer()` — U-18 chooses; must be testable and honor reduced motion.
- **Legibility floor:** effective luminance at α0.75 = 0.75 × 0.250 = 0.188 → contrast vs black = **(0.188+0.05)/0.05 = 4.75:1 ≥ 4.5** — still AA. Never animate below α0.75; never blur the glyph fill.
- **Reduced motion:** if `MediaQuery.disableAnimationsOf(context)` is true → **static glow** (shadows fixed at α1.0, no animation). Same for `MediaQuery.disableAnimations` in widget tests (U-27/U-29 will assert this).

### 6.3 Micro-interaction list

| Element | Effect | Duration |
|---|---|---|
| Button | α0.1 overlay on press | `fast` |
| Chip | border→fill crossfade | `fast` |
| List item | fade + 8px slide-in, stagger 60ms | `slow` |
| Card (featured) | static glow, no motion | — |
| Live dot | 1.5s α pulse 0.6→1.0 (disabled under reduced motion) | 1500ms |
| Shimmer skeleton | sweep (disabled under reduced motion) | 1200ms |
| Dialog/sheet | fade-through + 8px slide | `standard` |

---

## 7. Accessibility Rules

### 7.1 Contrast minimums (WCAG 2.2)

- **Text:** ≥ **4.5:1** normal, ≥ **3:1** large (≥24px or ≥18.5px bold). Verified values in §2 tables (computed with the WCAG relative-luminance formula: `L = 0.2126R + 0.7152G + 0.0722B` over linearized sRGB, ratio `(L1+0.05)/(L2+0.05)`; source: W3C Understanding SC 1.4.3).
- **Non-text (1.4.11):** ≥ **3:1** against adjacent colors for UI component boundaries and state indicators.
- U-26 runs the audit pass; the token table is the contract.

### 7.2 Hairline boundaries (1.4.11) — the one deliberate exception

`#1A1A1A` card borders (1.21:1) fail the 3:1 non-text rule **if** the border is the only indicator of the interactive region. Rule: any tappable surface must also carry a text/icon/chevron with ≥4.5:1, and any *state* (selected, focused, error) must be signaled with white or an accent line ≥3:1 — not the hairline alone. Focus indicator: 2px white outline.

### 7.3 Text scaling

- All type uses the app `textScaler` (never `textScaleFactor` fixed); `MediaQuery.textScalerOf(context)`.
- No fixed-height text containers; buttons/inputs grow; `maxLines` + ellipsis only on single-line labels.
- `AppSpacing.scale()` for responsive spacing (finding UI-09).

### 7.4 Glow legibility

- Halo **behind** text is fine (counts as background per WCAG note 5 on 1.4.3); **blur-only text is not** — glyph fill stays 100% opaque `glowPink`/white.
- Breathing amplitude floor α0.75 keeps effective contrast ≥4.75:1 (§6.2).
- Under reduced motion, glow is static (still legal — it is a background halo).

### 7.5 Reduced motion & sensitive users

- `MediaQuery.disableAnimationsOf(context)` gates: glow breathing, shimmer sweep, live-dot pulse, stagger entries. Static fallbacks defined per component (§6.3).
- No flashing, no strobing, no hue rotation — the disco look is *static color + slow breathing*, safe for photosensitivity (no 3Hz+ flicker anywhere).

### 7.6 Color-blindness

- Pink/violet/gold/cyan are distinguished by luminance (all ≥4.5 vs black) — never by hue alone; every accent state has a text/icon/position companion (1.4.1).

---

## 8. Implementation Mapping — U-01..U-30

Per `docs/agents/FILE-OWNERSHIP.md` (Phase 4.4). Each agent implements the sections named; **this doc is their contract.**

| Agent | Owns | Sections |
|---|---|---|
| U-01 | `lib/core/design_tokens/app_colors.dart` — disco palette | §2 (all tokens + usage rules) |
| U-02 | `lib/core/design_tokens/app_typography.dart` — Playfair Display + Inter | §3 (roles, scale, glow stacks) |
| U-03 | `app_spacing.dart`, `app_radius.dart`, `app_elevation.dart`, `app_icon_sizes.dart` | §4.1–4.4 |
| U-04 | `lib/core/theme/app_theme.dart` + `ThemeExtension` (new `SamayThemeExtension`) | §2 token wiring, §3 TextTheme, §4.5; register extension |
| U-05 | `v_button.dart`, `v_input.dart`, `v_card.dart`, `v_chip.dart`, `v_badge.dart`, `v_shard_icon.dart`, `rank_badge.dart` (disco restyle) | §5.1–5.6 |
| U-06 | New shared widgets: glow text, disco divider, shimmer, state widgets | §3.4, §5.7-5.9, §6.2 |
| U-07 | `lib/features/auth/**` restyle | §3.2 auth headers, welcome wordmark, buttons/inputs |
| U-08 | Router shell/nav restyle + `lib/features/feed/**` | §5.4 nav, feed hero, §6.1 transitions |
| U-09 | `lib/features/profile/**` restyle | §5.6 balance cards (gold shards), settings rows |
| U-10 | `lib/features/friends/**` restyle | chips/badges, online dots §5.5 |
| U-11 | `lib/features/groups/**` restyle | rank badges §5.5, leaderboard podium §3.2, donate flow |
| U-12 | Coming-soon screens restyle | §5.7 |
| U-13 | Juega flow study → flow alignment report | §8 (report feeds this spec's future revisions) |
| U-14..U-17 | Juega auth/profile/friends-groups/shell flow alignment | keep Samay identity per §1; no Juega colors |
| U-18 | Animations + micro-interactions (`samay_durations.dart`, reduced motion) | §6 entire |
| U-19 | Responsive layout + safe areas | §4.1 `scale`, §7.3 |
| U-20 | `assets/images/`, `assets/icons/` (disco assets) + launcher icons | §1 P3 (black + pink glow art) |
| U-21 | Empty/loading/error state widgets | §5.8, §5.9 |
| U-22 | Skeleton/shimmer loading | §5.8, §6.3 |
| U-23..U-25 | Review passes (auth→profile, friends→groups, feed/shell) | full spec conformance |
| U-26 | Contrast/a11y audit (WCAG, reduced motion, text scaling) | §7 entire |
| U-27 | `test/theme/**` + `test/widgets/**` disco update | asserts §2–§5 token values, §7 |
| U-28 | `test/features/**` UI interaction tests | §5 component behavior |
| U-29 | `integration_test/ui_smoke_test.dart` | §7 reduced-motion + §6.2 static-glow assertions |
| U-30 | **Finalization of this document** (updates after implementation realities) | entire |

### Extending the system (refactorability — future features)

1. **New color:** add hex + verified ratio to `app_colors.dart`; if it must appear in `Theme.of`, add it to `SamayThemeExtension` (U-04) with `copyWith`/`lerp`; register in `extensions:`; add a row to §2 with the computed contrast; never invent ad-hoc `Color(0x…)` in features.
2. **New text role:** extend `app_typography.dart`; default text roles map onto the §3.3 table; Playfair additions must be approved by this doc's rules (§3.2 exhaustive list) — add to the list, not beside it.
3. **New component:** compose from existing tokens (spacing/radius/durations) + shared widgets; no new shadow stacks beyond §4.3; ship widget test in `test/widgets/` + integration case in `integration_test/` (U-29 pattern).
4. **New feature screen:** follow §1 pillars first (black bg, white core), then apply the relevant component specs; restyle checklist = §§2.5, 5, 7.1.
5. **Future global change:** touch tokens only — screens must not hardcode design values (the I-16/M-24 token migration enforces this).

---

## 9. Sources

- W3C WCAG 2.2 Understanding SC 1.4.3 Contrast (Minimum) — contrast formula, 4.5:1/3:1 thresholds, large-text and halo notes: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- W3C WCAG 2.2 SC 1.4.11 Non-text Contrast (3:1): https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- W3C WCAG 2.2 SC 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- Flutter `ThemeExtension` API (subclass + `copyWith` + `lerp`, registered via `ThemeData.extensions`): https://api.flutter.dev/flutter/material/ThemeExtension-class.html
- Flutter `MediaQueryData.disableAnimations` (reduced-motion source): https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html
- MDN `text-shadow` (offset/blur/color, layered shadows front-to-back): https://developer.mozilla.org/en-US/docs/Web/CSS/text-shadow
- Google Fonts — Playfair Display (display serif; italic+bold usage): https://fonts.google.com/specimen/Playfair+Display
- Material 3 Color System (color roles; Samay overrides roles per §2): https://m3.material.io/styles/color/system/overview

## 10. Change Log

| Date | Change |
|---|---|
| 2026-08-09 | v1.0 authored by D-11 (docs sub-phase 4.1); contract for U-01..U-30. |
