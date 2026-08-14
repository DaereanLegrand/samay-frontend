# 2026-08-12 — XL-19: Final Polish (Gemma round-2 survivors)

**Agent:** XL-19 | **Branch:** `fixes` | **Campaign:** LUXE v2 UI overhaul

Final targeted fixes for the five screens Gemma round-2 still flagged.
Rendering only — routes, providers, flows, l10n keys untouched.
No commits (orchestrator-only). No `print`.

---

## Verdicts addressed (evidence)

- `luxe-screenshots/verdicts/01_welcome.md` — "sheer volume of text / visual
  clutter" (minimalism 4/10).
- `luxe-screenshots/verdicts/03_signup.md` — still "dense" (luxury 3/10,
  minimalism 2/10).
- `luxe-screenshots/verdicts/05_age_gate.md` — "visual clutter / inconsistent
  effects" (luxury 2/10).
- `luxe-screenshots/verdicts/06_privacy_terms.md` — "over-complication"
  (luxury 3/10).
- `luxe-screenshots/verdicts/10_events.md` — "overly saturated / cheap"
  (luxury 2/10) — the VComingSoonScreen glass panel.
- `luxe-screenshots/verdicts/14_chat.md` — "trivial / mediocre" on the EMPTY
  state (harness loads no messages).

Positive controls re-verified, NOT regressed: 04_otp, 15_coming_soon,
12_profile, 13_settings (false positive — left alone), 17_cosmetics.

## Sources

- Apple HIG "Color" —
  https://developer.apple.com/design/human-interface-guidelines/color —
  restraint: saturated accents only where the brand moment lives (the
  "watered chrome / raw brand moment" split below).
- ORCHESTRATION-LUXE.md directives (2026-08-12): black always, pastel watered
  with white (directive #3), one hero per screen (#8), NO pink mains.
- `AppGradients.wateredFamily` (XL-01) — the pre-built "re-stopped pale
  family" primitive, used here for the coming-soon glass chrome.
- Prior agents' patterns as in-repo references: login's muted secondary link
  (`login_screen.dart`), VEmptyView (§5.9).

---

## Changes

### 1. Welcome — `lib/features/auth/screens/welcome_screen.dart`
Verdict 01_welcome (clutter). Fixes:
- **VDiscoDivider removed** — redundant ornament on the brand screen.
- Secondary "Iniciar sesión" **demotes from the outlined VButton to a plain
  muted text link** (`AppColors.mutedStrong`, login-screen secondary pattern).
- Rhythm tightened: wordmark (64, violet family) → 8 → tagline → **48** →
  ONE primary CTA (filled `glowAccent`, violet) → 12 → text link → 32.
  Removed the second `Spacer` so the fixed 48 gap is real, not spread out.
- Wordmark stays the ONLY `VDisplayText` hero; aurora (violet+cyan brand
  wash) untouched.

### 2. Signup contact — `lib/features/auth/screens/signup_contact_screen.dart`
Verdict 03_signup (dense). Fixes:
- Hero → fields rhythm **40 → 32** ("hero 32").
- Field grouping **20 → 16** between the 3 fields (and error block 20 → 16).
- Verified no secondary caption remains (removed in XL-16); the 3 fields +
  CTA now read as one quiet column. Aurora stays α0.05 (the form screens'
  whisper).

### 3. Age gate — `lib/features/auth/screens/age_gate_screen.dart`
Verdict 05_age_gate (clutter / inconsistent effects). Fixes:
- Aurora → **single blob** (`gradients: [family]`) at **α0.03** (the floor of
  the whisper range) — one quiet wash, no multi-blob noise.
- Hint → picker **40 → 32** (tighter rhythm).
- Structure confirmed exactly: hero, one-line hint, date-picker row, CTA.
  Underage error is behavior (kept). No ornaments exist to remove.

### 4. Privacy & terms — `lib/features/auth/screens/privacy_terms_screen.dart`
Verdict 06_privacy_terms (over-complication). Fixes:
- Aurora **0.05 → 0.03** (floor of the whisper range).
- Verified: no duplicate instruction text exists — the two consent rows carry
  their own section labels (`Acepto la Política de Privacidad` /
  `Acepto los Términos de Servicio` + legal subtitles). Screen is exactly
  hero, 2 consent rows, CTA — nothing added, nothing more to strip.

### 5. Coming-soon shell — `lib/shared/widgets/v_coming_soon.dart`
Verdict 10_events (saturated / cheap — the events TAB is a VComingSoonScreen).
Fixes:
- Glass panel **ring + glow** ride the watered run:
  `AppGradients.wateredFamily(family, mix: 0.4)` instead of the raw family
  (pale chrome; the vivid end only survives in the brand moment).
- **Headline shader stays the RAW family** (`VDisplayText` untouched) — the
  one brand moment on the screen.
- **Icon defaults to the family's watered mid tone**
  (`AppGradients.watered(family.colors, mix: 0.4)[1]`) — `iconColor` is now
  `Color?` (null → computed); explicit callers (party_finder's faint
  glowPink α0.5 micro-accent, pre-existing) keep their override.
- Back button unchanged. All router call sites unchanged (default violet).

### 6. Chat — `lib/features/chat/screens/chat_screen.dart`
Verdict 14_chat (trivial / mediocre — EMPTY state). The round-4 directive
("centered minimal VEmptyView (chat icon, one line) + composer already
glass; zero chrome besides list + composer") is **already implemented** by
the XL-12/XL-18 code (`VEmptyView(icon: chat_bubble_outline, title:
chatEmpty)` in the `Expanded` slot above the glass composer). Per
"no gold-plating — just enough to pass", the screen code is left untouched;
the contract is now pinned harder in the test (icon + one line + no
description/CTA + only the composer chrome below).

---

## Tests

Updated only broken visual pins:

- `test/features/auth/restyle_test.dart` — secondary-CTA pin rewritten
  (plain muted text link: no background, no side, inner Text in
  mutedStrong); VDiscoDivider pin flipped to `findsNothing` + exactly one
  `VButton` on the brand screen. Header comment updated.
- `test/widgets/v_coming_soon_test.dart` — icon pins → watered mid tone of
  the (default violet) family; glass-panel pin → watered run (name kept,
  colors = watered(0.4)); `glass.glowAlpha` still 0.22.
- `test/features/chat/chat_screen_test.dart` — empty-state pin strengthened
  (icon, one line, no description/action, composer present).

Behavior pins untouched and green (signup validation, age-gate picker +
underage gate, consent gating → profile_setup, chat send/thinking-dots/
pagination, router MAYUS pins).

## Commands (reproducibility)

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
dart analyze lib/features/auth/ lib/shared/widgets/v_coming_soon.dart lib/features/chat/   # 0 issues
flutter test test/features/auth/ test/widgets/v_coming_soon_test.dart \
  test/features/chat/ test/features/auth_screens_test.dart   # 132/132
flutter test test/router/                                   # 153/153
flutter test test/core/feature_flags_test.dart test/widgets/ # 283/283
```

## MISTAKE block

- **restyle_test secondary CTA**: first pin asserted
  `backgroundColor == Colors.transparent` — but a bare `TextButton` with no
  background resolves `null`, not transparent (the old outlined VButton
  explicitly set transparent). Fixed to `isNull` + pinned the inner
  `Text`'s color (the mutedStrong lives on the Text, not the ButtonStyle —
  same as login's secondary).
- **v_coming_soon_test glass pin**: `expect(glass.gradient, wateredFamily(...))`
  compares `AppGradient` instances by identity (no `==` override) and the
  widget builds a fresh instance — failed. Fixed by pinning `name` +
  the watered `colors` list instead.

## Validation gate

- [x] All focused tests pass (132 + 153 + 283)
- [x] `dart analyze` 0 issues on touched files
- [x] Verdict WHAT IS WRONG sections addressed
- [x] ONE hero per screen, uppercase via VDisplayText, no external text
      glow, no pink mains — all re-verified untouched
- [x] Cross-references: no dependency changes (rendering only)
- [x] Locks acquired/released; no commits
