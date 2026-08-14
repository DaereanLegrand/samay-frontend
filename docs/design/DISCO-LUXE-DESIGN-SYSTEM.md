# Samay — LUXE v2 Design System (DISCO-LUXE-DESIGN-SYSTEM)

**Owner:** XL-21 (spec author) | **Campaign:** LUXE v2 UI overhaul (XL-01..XL-23, branch `fixes`)
**Status:** v2.0 — the LUXE delta on top of DISCO-DESIGN-SYSTEM v1.1 (U-30). The v1.1 doc stays the
authoritative read-only reference for everything LUXE does NOT override; this document defines the
LUXE v2 language and reconciles it against the implemented code (post-XL-19).
**Date:** 2026-08-12
**Upstream specs:** `docs/audit/GATE-REPORT-LUXE.md` (campaign gate record; the per-round
campaign spec `ORCHESTRATION-LUXE.md` and `GEMMA-ROUNDS.md` were removed post-campaign), non-negotiables,
gradient map), `docs/design/DISCO-DESIGN-SYSTEM.md` (v1.1 — superseded where noted),
`docs/history/phase-04-luxe/2026-08-12_XL-{01..19}-*.md` (per-agent decisions).

> **What LUXE v2 is:** a full UI overhaul following 2026 UI/UX tendencies — AI-like thinking
> interfaces, liquid glass, maximum luxury + minimalism, black background always, pastel soft vibrant
> colors in gradients (watered down with white + glow), slow pulsating glows, iOS-only focus
> (iPhone 17 Pro simulator). Where this doc is silent, v1.1 rules apply unchanged (sharp corners,
> hairline boundaries, contrast contract, reduced-motion engine, text-scaling patterns).

> **Reconciliation note (XL-21):** every § below describes what the code ACTUALLY does after
> XL-01..XL-19 (verified file-by-file against `lib/core/design_tokens/`, `lib/shared/widgets/`,
> `lib/core/theme/`, `lib/features/**`). Spec lines the implementation deliberately did not ship are
> marked **DEPARTURE** with rationale. §8 maps every section to its owning file + XL agent.

---

## 1. Brand Pillars (LUXE)

| # | Pillar | Rule |
|---|--------|------|
| L1 | **Black always** | `scaffoldBackgroundColor` is `#000000` in every screen, sheet, dialog (inherited from v1.1 P1 — unchanged). No light mode, no gray page background. |
| L2 | **Pastel gradients, watered with white** | Every accent is a *gradient* — text, borders, buttons, glows. Never a flat single-color accent (directive #2). Colors are pastels mixed toward white; vivid hues appear only at low alpha inside glow/gradient layers or as the display-text shader (directive #3). |
| L3 | **NO PINK MAINS** | `rose` is NOT a main color anywhere (user directive 2026-08-12). Rose survives only as a possible micro-accent inside ambient multi-color auroras (low alpha), never as a screen's hero, display, or CTA gradient. `AppGradients.familyOf` default = **violet**, and every shared widget's accent default (VButton.glowAccent, VBadge.accent, VChip.accent, VCountBadge) is violet. Pink remains only in error semantics (`AppColors.error`/`errorFill` — the documented exception). Gemma critiques MUST flag pink dominance as a critical defect (see §7). |
| L4 | **Glow pulsates slowly** | Ambient halos breathe on a **3.8s** ease-in-out α ramp (non-negotiable 5: 3.6–4s), reduced-motion → static at a fixed α. See §5. |
| L5 | **Playfair ONLY uppercase** | Playfair Display italic bold is the display voice and renders **MAYUS** — enforced by the shared `VDisplayText` widget (`text.toUpperCase()`), never at call sites (directive #6). Everything else is Inter. |
| L6 | **Inputs are glass, never underline** | NO underline inputs (directive #7). All fields are liquid-glass slabs: radius-16 shell, 1px gradient ring, `surfaceAlt` α0.5 fill, floating label, focus glow. |
| L7 | **One hero per screen** | One `VDisplayText` hero and one primary CTA per screen, max. No title duplicated in an AppBar + hero (directive #8). Strictly what is necessary; nothing else. |
| L8 | **iOS swipe-back** | Left-to-right edge swipe to go back on every pushed route — `CupertinoPageTransitionsBuilder` on **all** platforms (iPhone-17-Pro focus carries everywhere; directive #9). |
| L9 | **Liquid glass + neumorphism + brutalism**, blended minimally | Glass surfaces (blur + white sheen), neumorphic top highlights on glass fills, sharp brutalist geometry for cards. Never all three at once in one component. |
| L10 | **AI-thinking accents** | Subtle typing dots in the chat input (`VThinkingDots`), a once-only shimmer sweep on hero text (`VDisplayText`), breathing skeleton shimmer. Subtle, one per context (directive #11). |
| L11 | **iOS only** | Android/web/macOS/linux/windows specifics are untouched (directive #12). |

**White-only fallback (inherited):** when a screen's accent needs are unclear, render fully
white-on-black. Accent color is a privilege, not a default — saturated color is a *brand moment* (see
§6).

---

## 2. The Gradient System

Source of truth: `lib/core/design_tokens/app_gradients.dart` (XL-01) + the 8 new pastel tokens in
`lib/core/design_tokens/app_colors.dart`. **No screen may invent a `LinearGradient` color list or
ad-hoc `Color(0x…)`** — families resolve via `AppGradients.familyOf(screenKey)` and render through the
token layer. Stops are always `[0.0, 0.5, 1.0]`.

### 2.1 The 6 families (exact hexes + stops)

| Family | Stops `[0.0, 0.5, 1.0]` (pastel → mid → vivid) | Vivid end aliases |
|---|---|---|
| `violet` | `#E3D9FF` → `#B79CFF` → `#8B5CF6` | `AppColors.discoViolet` |
| `cyan` | `#D6F7FF` → `#7FE9FF` → `#00E5FF` | `AppColors.discoCyan` |
| `gold` | `#FFF3D6` → `#FFDF99` → `#FFC94D` | `AppColors.discoGold` |
| `mint` | `#D8FFEE` → `#8BFFD9` → `#37E6A5` | `AppColors.mint` (new) |
| `peach` | `#FFE6D9` → `#FFC09E` → `#FF8A65` | `AppColors.peach` (new) |
| `rose` | `#FFD6E8` → `#FF8AC2` → `#FF2E88` | `AppColors.glowPink` — **micro-accent only (L3)** |

The 6 light ends + the 2 new vivid ends are canonical tokens (contrast vs black, computed with the
`AppColors.contrastRatio` formula):

| Token | Hex | Contrast vs `#000000` |
|---|---|---|
| `pastelRose` | `#FFD6E8` | 16.04:1 — AAA |
| `pastelViolet` | `#E3D9FF` | 15.64:1 — AAA |
| `pastelCyan` | `#D6F7FF` | 18.61:1 — AAA |
| `pastelGold` | `#FFF3D6` | 19.04:1 — AAA |
| `pastelMint` | `#D8FFEE` | 19.46:1 — AAA |
| `pastelPeach` | `#FFE6D9` | 17.57:1 — AAA |
| `mint` | `#37E6A5` | 13.02:1 — AAA |
| `peach` | `#FF8A65` | 9.08:1 — AA/AAA |

> The 6 mid stops (`#B79CFF`, `#7FE9FF`, `#FFDF99`, `#8BFFD9`, `#FFC09E`, `#FF8AC2`) are
> family-exclusive in-file hexes (no standalone token by contract — documented in `app_colors.dart`'s
> LUXE section header). Pastels sit at AAA by construction; they are decorative gradient/glow
> materials — never body-text roles (use `white`/`mutedStrong` for text).

### 2.2 Screen → family map (verbatim from `AppGradients.familyOf`)

| Family | Screens |
|---|---|
| violet | welcome, signup, age_gate, groups, cosmetics, profile_setup, qr — **+ default fallback for unknown keys** |
| cyan | login, feed, party_finder |
| gold | otp, notifications, profile, shards, paywall |
| mint | privacy_terms, friends, photos, banned |
| peach | forgot_password, chat, events, minigames |
| rose | **no screen** — micro-accent only (L3) |

### 2.3 `glowShadows` layering rules

`AppGradients.glowShadows(g, {alpha = 0.35, blur = 48})` — three zero-offset halo layers
(innermost → outermost):

| Layer | Color | Alpha | Blur |
|---|---|---|---|
| 1 — tight halo | mid stop (`colors[1]`) | `alpha` | `blur` |
| 2 — mid aura | vivid stop (`colors[2]`) | `alpha × 0.6` | `blur × 2` |
| 3 — wide aura | vivid stop (`colors[2]`) | `alpha × 0.3` | `blur × 3.5` |

Rules:
1. Zero offset — the glow is a **halo**, never a drop shadow (inherited v1.1 spirit).
2. Per-component alphas are disciplined by surface type (§4 table): cards ≤ 0.18, data screens ≤ 0.12,
   buttons 0.35 (the one brand-moment halo), hero/id moments 0.12–0.22.
3. Glows are animated only through `VGlowPulse` (or the shell's own pulse); static halos stay static.
4. Never stack a glow on a glow (hero + card + CTA on one screen = spray; see §6 rule 5).
5. Reduced motion → static at the documented fixed α (never removed — a static halo is still legal).

### 2.4 `watered()` / `wateredFamily()` usage rules (XL-17 "cheap saturated color" fix)

- `watered(List<Color> base, {mix = 0.6})` — lerps every stop toward white.
- `wateredFamily(AppGradient g, {mix = 0.4})` — a full `AppGradient` re-stopped from `watered()`
  colors (keeps `name`/`stops`, so the glass ring, glow halo, button face and badge resolve it
  unchanged — just paler).

| Surface type | Recipe | Where |
|---|---|---|
| Fills & borders (glass chrome, cards, buttons, badges) | **watered ≤ 0.5 mix** (canonical: 0.4; chat bubbles 0.45; unread dot 0.45; party-finder chips 0.35) | §4 |
| Display-text shader (`VDisplayText`) | **raw family** — the vivid end's only major home | §3 |
| 1px accents & tiny dots | raw family mid/vivid at low α, or watered mid tones | §2.2 usage, §4 |

So: saturated color survives ONLY in the display shader, the 1px ring accents, and the tiny dots —
everywhere else rides the watered run. Uniform across families (0.4 chosen because it lands the vivid
end far enough toward white to read "pastel chrome" while the α0.18 border ring keeps a visible hue).

### 2.5 Aurora rules (`VAurora`)

- **One per screen, max.** 2–3 huge radial blobs, diameter ≈ 1.5× the long edge, anchored mostly
  off-screen (top-left / top-right / bottom-center).
- Blob alpha **0.03–0.10** (the whisper range). Form screens: **0.03–0.05** (inputs are surfaces, not
  brand moments). Default component α = 0.10.
- Default blob family set = **`[cyan, violet, mint]`** — rose is NOT in the default set (L3; rose may
  appear only as an explicit micro-accent override).
- Drift: one shared 10s orbit (`auroraDrift`), per-blob sin/cos phases, ±12px — "barely there"
  motion. Reduced motion → static base positions, zero tickers.
- Auras may double as the screen's brand wash (welcome: `[violet, cyan]`).

---

## 3. Typography

### 3.1 Display voice — `VDisplayText` ONLY (the 2026-08-12 directive)

`lib/shared/widgets/v_display_text.dart` (XL-03) is the **only** sanctioned way to render a display
role (v1.1 §3.2's exhaustive Playfair list is hereby routed through it):

- Playfair Display italic bold, `text.toUpperCase()` — **the MAYUS rule is enforced here, never at
  call sites**. Callers pass natural case.
- Gradient glyph fill via `ShaderMask(BlendMode.srcIn)` over `AppGradients.textShader(family,
  bounds)`; `gradient: null` → pure white glyphs.
- **Once-only shimmer sweep (900ms)** across the glyphs on first build — inside the letters, off at
  t=1, never restarts, reduced-motion → none.
- **NO EXTERNAL GLOW — the halo was deleted (2026-08-12 user directive: "glowing pulsation outside
  letters must be deleted").** There is deliberately no boxShadow/halo behind display glyphs. The
  ambient glow lives in the screen's `VAurora` and the glass/button halos — never around the text.
- Sizes map to the v1.1 roles: 64 `displayLarge`, 40 `displayMedium` (default), 32 `displaySmall`,
  28 `headlineLarge`; neutral tracking (no negative letter-spacing — the LUXE display voice breathes).
- One hero per screen (L7) — `VDisplayText` appears at most once per screen.

### 3.2 UI voice — Inter

- Everything that is not a display hero is Inter (inherited).
- **Inputs are iOS-native 17px** — `VInput`'s text/hint style: `fontSize: 17, w400, height 1.35,
  letterSpacing 0` (clean, never styled like display copy). Cursor white.
- **`sectionLabel`** (XL-03): Inter w600 12, letter-spacing 2.0, `mutedStrong` (7.37:1 — AA). Rendered
  ABOVE content as an all-caps eyebrow (uppercased at call sites). NOT a display voice — it never
  goes through `VDisplayText`. Standalone token (not in `textTheme`); consumers: settings, feed,
  profile, public-profile, create-event.

### 3.3 Rules

1. No Playfair below 28px; no Inter for heroes.
2. Display text is NEVER flat (always the family shader or white) — L2.
3. AppBar titles stay Inter utility titles (v1.1 U-12 decision) — heroes live in the body.
4. `VDiscoDivider`, `VGlowText`, `VBreathingGlow` remain available (v1.1 §3.4/§6.2, violet-canonical
   after XL-14) but are NOT the display voice; the LUXE display voice is `VDisplayText`.

---

## 4. Components

### 4.1 Glass — `lib/shared/widgets/glass/` (XL-02)

**`VGlass`** (layered back → front):

| Layer | Spec |
|---|---|
| Backdrop | `BackdropFilter` sigma 12 over a white gradient fill α0.05 → α0.01 (topLeft → bottomRight), clipped to radius. Over pure black the blur is invisible — the glass reads through fill + border + glow (by design). |
| Content | padded, clipped to radius. The ring is `IgnorePointer` chrome — it never intercepts taps (XL-07 hit-test fix). |
| Top highlight | 1px white α0.10 sheen at the top edge, fading at both ends (the glass rim catching light). |
| Ring | `VGradientBorder`: white α0.28 → pastel α0.18 → transparent; **white-only when `gradient` is null**. |
| Glow | `AppGradients.glowShadows` on an outer DecoratedBox when `glowAlpha > 0` and a family is set. |

Geometry: radius **0** for cards (brutalism) / **16–20** for chips, inputs, sheets (liquid).

**`VGlassCard`** = radius 0 + `glowAlpha` 0.18 + padding 16 — the liquid-glass sibling of `VCard`.

**Glow discipline (post-Gemma rounds, XL-17):**

| Surface | glowAlpha ceiling |
|---|---|
| Cards (`VGlassCard` default) | **≤ 0.18** |
| Data screens (ledger header 0.10, balance card 0.12, group hero 0.12, podium 0.12) | **≤ 0.12** |
| Hero/id moments | 0.12–0.22 (OTP field halo 0.22/blur 24 is the top end) |
| Buttons (`VButton.glowAccent`) | 0.35 (the one brand-moment halo) |

**`VGradientBorder`** — the 1px gradient-ring primitive (double-container trick; const-constructible;
used by `VGlass`, `VButton`, chips, inputs, sheets).

### 4.2 Buttons — `v_button.dart` (U-05 base, XL-14 gradient-capable)

| Variant | LUXE spec |
|---|---|
| `VButton` / `.outlined` | flat path byte-identical to v1.1 (white border/white text); `gradient:` → pastel gradient ring. |
| `VButton.emphasized` | white fill + black text; `gradient:` → family gradient fill (pastel-first stops keep black text legal). |
| `VButton.glowAccent` | **always gradient-renders**: 1px `VGradientBorder` ring (default family **violet**, caller passes `AppGradients.familyOf`), black text when `filled` / white when outline, halo = `glowShadows(α 0.35)`; pressed = `Color.lerp(family.colors.last, black, 0.35)` overlay + white text (the "darker violet" face, 5.87:1). **Use ≤ 1 per screen — always the primary action.** |
| Disabled / loading | ring + text drop to `muted #666666` (flat 2-color ring, no stops); spinner in the foreground color. |

### 4.3 Inputs — `v_input.dart` (XL-03 redesign, API-identical — 32 call sites compile untouched)

- Radius-16 glass slab (double container, `AnimatedContainer` 200ms): outer 1px gradient ring + inner
  `surfaceAlt` α0.5 fill + neumorphic top highlight (white α0.04).
- Ring states: default white α0.25 · focused white diagonal α0.8 → α0.25 · error glowPink α0.8.
- Focus glow: white α0.12, blur 24 (only when focused, not on error).
- Label ALWAYS visible above the field (`floatingLabelBehavior: always`, `labelSmall`-adjacent voice:
  `mutedStrong` → white on focus → glowPink on error). Hint `muted`, text white 17px, cursor white,
  error text glowPink (never raw red).
- **Per-screen gradient borders are applied screen-locally where the family moment demands it** (the
  OTP 6-digit slab wears the gold family border + halo — XL-18); `VInput` itself stays neutral white
  so every field is a quiet member of the form.
- Theme-level `inputDecorationTheme` (XL-03) gives raw Material `TextField`s the same glass treatment
  (radius-16 `OutlineInputBorder`, `surfaceAlt` α0.5 fill, floating labels).

### 4.4 Ambient & AI-thinking widgets (XL-04)

| Widget | Spec |
|---|---|
| `VAurora` | §2.5. One per screen. |
| `VGlowPulse` | generic halo pulse: `glowShadows` α **0.35 ↔ 0.7**, `glowPulse` 3800ms easeInOut alternate + 300ms static settle; reduced → static α0.55. |
| `VThinkingDots` | 3 dots, staggered α0.4 ↔ 1.0 wave, 900ms; `mutedStrong` default (accents stay minimal — luxury = restraint); reduced → static α1.0. Used in the chat composer. |
| `VDisplayText` | §3.1. |
| Shell glass strip | `MainShell._NavGlassStrip` (XL-06): blur-12 glass strip + 1px top hairline under the `surface` α0.85 tab bar. |

### 4.5 Gradient-capable shared widgets (XL-14 de-pink sweep)

| Widget | Param | Default family | Rendering |
|---|---|---|---|
| `VButton` (all 4 factories) | `AppGradient? gradient` | violet (glow variant) | §4.2 |
| `VBadge.accent` | `AppGradient? gradient` | violet | pale `watered()` fill, mid-stop border, black label; legacy flat `color:` accent kept |
| `VChip.accent` | `AppGradient? gradient` | violet | vivid-end border/label; selected = vivid fill + black label |
| `VCountBadge` | `AppGradient? gradient` | violet | vivid-end 1px border + count text (was glowPink) |
| `VGlowText` / `VBreathingGlow` | `AppGradient? gradient` | violet | v1.1 halo voice (not the display voice) |
| `VDiscoDivider` | flat | `statusVip` (violet) | a 1px segment cannot carry a gradient (documented) |

Error surfaces keep `glowPink` via the semantic `error` alias — the documented exception. The
`no_pink_defaults_test` source-grep guard pins the sweep.

---

## 5. Motion

### 5.1 Duration tokens — `lib/core/theme/samay_durations.dart` (U-18 + XL-04)

| Token | Value | Use |
|---|---|---|
| `fast` | 150ms | button press, chip select, icon swaps, focus states, **tab fade** (`VTabFade` — no dedicated `tabFade` token exists; `fast` is the tab-fade duration) |
| `standard` | 250ms | page transitions, dialog/sheet open, snackbar |
| `slow` | 500ms | hero/display fade-in, glow settle |
| `glowBreath` | 3000ms | v1.1 disco-glow breathing (`VBreathingGlow`, `VStatusDot` family) |
| `shimmer` | 1200ms | skeleton shimmer sweep |
| `liveDotPulse` | 1500ms | live-dot α pulse |
| `motionCycleRest` | 300ms | idle-safe static settle between every glow/pulse cycle (test-deterministic engine) |
| **`glowPulse`** | **3800ms** | `VGlowPulse` halo alternate (the campaign's 3.6–4s directive) |
| **`auroraDrift`** | **10000ms** | `VAurora` blob orbit |
| **`thinkingDot`** | **900ms** | `VThinkingDots` staggered pulse |
| **`glassHover`** | **150ms** | glass hover/focus accent transition (chips, glass controls) |
| **`displaySweep`** | **900ms** | once-only shimmer sweep on hero text (`VDisplayText`) |

> **DEPARTURE note (XL-21):** `VInput`'s shell transition is its own `VInput.shellDuration` 200ms
> const (pre-dates the `glassHover` token; value not on the 8-step duration scale). `VDisplayText`
> keeps a mirror `shimmerDuration` 900ms const equal to `displaySweep`. Both are documented in-file;
> a future pass may fold them into the token file. `tabFade` is not a literal token — `VTabFade`
> consumes `fast`.

### 5.2 Motion contract

- Ambient motion set (per component): `VGlowPulse` α0.35↔0.7 on 3800ms; `VAurora` 10s drift;
  `VThinkingDots` 900ms wave; `VDisplayText` once-only 900ms sweep; v1.1 set unchanged (glowBreath,
  shimmer, liveDotPulse).
- Idle-safe engine (inherited D-7/U-18): each cycle = alternate + **300ms static settle**
  (`motionCycleRest`) so `pumpAndSettle`-based tests land deterministically; `isAnimating` guard
  absorbs late timer ticks.
- **Reduced-motion contract** (`MediaQuery.disableAnimationsOf(context)`): every ambient animation
  freezes at a static value — `VGlowPulse` α0.55, `VAurora` base positions, `VThinkingDots` α1.0,
  `VDisplayText` no sweep, `VBreathingGlow`/`VStatusDot` α1.0, `VShimmer` static blocks, `VTabFade`
  static. Zero tickers (`transientCallbackCount == 0` pinned in the XL-04 suites).
- No scale, bounce, elastic, rotation, flash, or hue rotation anywhere (inherited v1.1 §6.1).

---

## 6. Decluttered-Screen Rules (from the Gemma rounds)

Post-`gemma_critique` fixes (rounds 1–3, XL-16..XL-19) distilled into the canonical screen grammar.
"Simple is luxury."

1. **One hero + one primary CTA per screen.** The single primary is `VButton.glowAccent(filled: true)`
   in the screen's family. Secondary actions are **plain muted `TextButton`s** (`mutedStrong`) — a
   second full-width outlined button competes with the primary (login hierarchy 5/10 → fixed).
2. **Form-field rhythm:** hero → fields **32–40** air, **16–20** between fields, **24–32** before the
   CTA (final state: signup 32/16, login 40/20, OTP 40; CTA gap 32). No field cramping, no extra
   captions — one short hint max.
3. **No decorative dividers on form screens** (`VDiscoDivider` removed from welcome; the
   `VGlassCard` panel removed from privacy-terms — two identical rows group by adjacency).
4. **Data rows are hairlines, not card+glow.** Per-row glass + glow reads as decoration, not
   hierarchy (shard ledger was "a pathetic, cluttered mess" at ~20 glass tiles — now plain hairline
   rows). Glass is reserved for hero/id moments and forms.
5. **Saturated color = brand moment only.** The vivid end appears in exactly: the `VDisplayText`
   shader, the primary CTA halo, and micro accents (dots, 1px rings). Everything else rides the
   watered run (§2.4). One accent surface per screen; a second full-strength accent is spray.
6. **No duplicate titles** (no AppBar title duplicating the hero), no redundant hints echoing labels,
   no decorative avatars/ornaments (`CircleAvatar` placeholder removed from profile-setup).
7. **Aurora whisper on forms:** α0.03–0.05 (age-gate even drops to a single blob).
8. **Status lives in the label, not the color** (v1.1 §2.5 rule 5): event badges went neutral —
   peach stays only on the hero + CTA; the unread dot is watered gold, never saturated.

---

## 7. The Gemma QA Loop

The vision-model critique gate that drove rounds 1–3 and every subsequent polish.

### 7.1 Tools

- `tools/gemma_critique.sh <prompt-file> <image>` → prints one verdict. Base64s the PNG raw, posts
  to the local model, prints the assistant content.
- `tools/gemma_critique_all.sh <screenshots-dir> [prompt-file] [out-dir]` → runs every `*.png` in a
  directory through the judge, writes one `<name>.md` verdict per screen into
  `<dir>/verdicts/` + a `SUMMARY.md` score table. Each image takes ~30–90s on the local model.
- Screenshots come from `xcrun simctl io booted screenshot <file>.png` (or the `integration_test`
  `takeScreenshot` harness — `integration_test/luxe_screenshots_test.dart`, XL-15, walks 18 stops on
  the iPhone 17 Pro simulator into `luxe-screenshots/`).

### 7.2 Endpoint contract

- `POST http://0.0.0.0:8001/model/chat/completions`
- Body: `{"messages":[{"role":"user","content":"<prompt>","image":"<RAW base64 — no data: prefix>"}],"max_tokens":<2048>}`
- Vision-capable Gemma 4 (verified 2026-08-12: correctly identified an all-pink image).
- The canonical prompt is `tools/gemma_critique_prompt.md` (brutal luxury-UI judge; requirements =
  black bg, watered pastels, **NO PINK as main color**, Playfair UPPERCASE, glass inputs, no clutter).

### 7.3 Mandatory output shape (verdict MUST include "WHAT IS WRONG")

1. **SCORES** 1–10 per axis: LAYOUT · HIERARCHY · LUXURY · MINIMALISM · GRADIENTS · TYPOGRAPHY ·
   INPUTS · IOS-FEEL.
2. **WHAT IS WRONG** — up to 5 concrete defects: exact location → what's wrong → exact fix. **If
   pink dominates, list it first** (a critical defect by L3).
3. **ONE CHANGE** — the single most impactful fix.
4. **VERDICT** — one brutally honest line.

Per-round results and fixes were tracked in `docs/history/phase-04-luxe/GEMMA-ROUNDS.md`
(removed post-campaign; the gate record is `docs/audit/GATE-REPORT-LUXE.md`).

---

## 8. Implementation Status

| Doc section | Owning implementation file(s) | Landed by | Status |
|---|---|---|---|
| §1 pillars (black/glass/swipe-back/one-hero) | `lib/core/theme/app_theme.dart` (pageTransitionsTheme, inputDecorationTheme), `lib/core/router/main_shell.dart` | XL-03, XL-06 | DONE |
| §2 gradients + pastel tokens | `lib/core/design_tokens/app_gradients.dart`, `app_colors.dart` (8 new tokens) | XL-01 (wateredFamily: XL-17) | DONE |
| §3 typography (VDisplayText, sectionLabel, 17px inputs) | `lib/shared/widgets/v_display_text.dart`, `app_typography.dart`, `v_input.dart` | XL-03 (no-halo directive 2026-08-12) | DONE |
| §4.1 glass | `lib/shared/widgets/glass/` (v_glass, v_gradient_border, glass barrel) | XL-02 (glow discipline XL-17) | DONE |
| §4.2 buttons | `lib/shared/widgets/v_button.dart` | XL-14 | DONE |
| §4.3 inputs + theme | `v_input.dart`, `app_theme.dart` | XL-03 (OTP gold slab XL-18) | DONE |
| §4.4 ambient/AI widgets | `v_aurora.dart`, `v_glow_pulse.dart`, `v_thinking_dots.dart`, `main_shell.dart` | XL-04, XL-06 | DONE |
| §4.5 gradient-capable sweep | `v_badge.dart`, `v_chip.dart`, `v_count_badge.dart`, `v_glow_text.dart`, `v_breathing_glow.dart`, `v_disco_divider.dart` | XL-14 | DONE |
| §5 motion tokens | `lib/core/theme/samay_durations.dart` | U-18, XL-04 | DONE |
| §6 decluttered screens (auth) | 9 auth screens | XL-05 (declutter XL-16, polish XL-19) | DONE |
| §6 decluttered screens (data) | profile, shards, groups (4), events (2) | XL-08/XL-10/XL-11 (declutter XL-17) | DONE |
| §6 decluttered screens (chat/rest) | chat, otp, notifications, party_finder, v_coming_soon | XL-12/XL-13 (XL-18, XL-19) | DONE |
| §7 Gemma loop | `tools/gemma_critique.sh`, `gemma_critique_all.sh`, `gemma_critique_prompt.md`, `integration_test/luxe_screenshots_test.dart` | XL-15 + orchestrator | DONE |
| §8 this document | `docs/design/DISCO-LUXE-DESIGN-SYSTEM.md` | XL-21 | DONE |

### Extending the system (refactorability)

1. **New family:** add hexes + verified ratios to `app_colors.dart` (if the stops need tokens), add
   the `AppGradient` const + `all`/`familyOf` entries in `app_gradients.dart`, add a row to §2.1/§2.2
   — never ad-hoc gradients in features.
2. **New screen:** resolve the family via `AppGradients.familyOf(key)` (extend the map if new),
   one `VAurora` (α0.03–0.10, no rose), one `VDisplayText` hero, one `glowAccent` primary, glass
   inputs, hairline data rows; check the §6 checklist.
3. **New component:** compose from tokens + shared widgets; default accent family violet; ship a
   widget test + reduced-motion pin.
4. **Durations:** extend `samay_durations.dart` only; never hardcode ms in features.
5. **Future global change:** touch tokens only — the `no_pink_defaults_test` guard and the token
   files are the enforcement points.

---

## 9. Sources

- Campaign spec: `ORCHESTRATION-LUXE.md` (removed post-campaign; gate record:
  `docs/audit/GATE-REPORT-LUXE.md` — directives, family map, Gemma protocol)
- v1.1 design system: `docs/design/DISCO-DESIGN-SYSTEM.md` (read-only reference; LUXE overrides only)
- Gemma verdicts + rounds: `GEMMA-ROUNDS.md` (removed post-campaign),
  `luxe-screenshots/verdicts/`
- Agent logs: `docs/history/phase-04-luxe/2026-08-12_XL-01..XL-19-*.md`
- Apple HIG — Color (restraint; watered chrome vs brand moment): https://developer.apple.com/design/human-interface-guidelines/color
- 2026 gradient trends (pastel/aurora/glass on dark): https://dev.to/will_indie/css-gradient-trends-in-2026-and-how-developers-actually-use-them-3hec · https://pxltool.com/en/blog/design-trends-2026 · https://www.kittl.com/blogs/gradient-design-trend-stl/

## 10. Change Log

| Date | Change |
|---|---|
| 2026-08-12 | v2.0 authored by XL-21 — the LUXE delta spec, reconciled against the code post-XL-19 (gradients XL-01, glass XL-02, typography/inputs/theme XL-03, motion XL-04, screens XL-05..XL-13, widget sweep XL-14, harness XL-15, declutter rounds XL-16..XL-19). |
