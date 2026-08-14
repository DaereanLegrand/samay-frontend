# 2026-08-12 — XL-16: auth form-screen declutter (Gemma round 1)

**Agent:** XL-16 | **Campaign:** LUXE v2 UI overhaul | **Branch:** `fixes`

## What was built

Round-1 Gemma critique hit the auth FORM screens hardest (density, weak
hierarchy, ornament). All seven owned screens were decluttered per the
"simple is luxury" directive: whisper aurora, one hero, generous air, one
dominating CTA, secondary links muted.

| File | Changes |
|---|---|
| `login_screen.dart` | Aurora 0.05. Hero→fields 32→40; fields 16→20; field-group→CTA 24→32. Secondary "Crear cuenta" demoted from full-width outlined VButton to a muted `TextButton` (the primary glowAccent now dominates — Gemma 02_login "primary action doesn't dominate"). Forgot link muted. |
| `signup_contact_screen.dart` | Aurora 0.05. Dropped the `authSignupSubtitle` paragraph (restated the labels below it — 03_signup "overwhelming density"). Hero→field 32→40; fields 16→20; auth-error pad 16→20. |
| `otp_verification_screen.dart` | Aurora 0.05. Hint→field 32→40; error pads 16→20. Resend + back-to-login links muted. |
| `age_gate_screen.dart` | Aurora 0.05 (05_age_gate "strip away the ornament"). Hint→picker 32→40; underage pad 16→20. |
| `privacy_terms_screen.dart` | Aurora 0.05. Removed the `VGlassCard` panel wrapping the consent rows (06_privacy_terms "trivial display of over-complication"; directive: black bg + rows is cleaner) — hero gradient + CTA now own the only glow. Rows breathe at 20 apart. Dropped `v_glass.dart` import. |
| `profile_setup_screen.dart` | Aurora 0.05. Removed the `CircleAvatar` camera placeholder (07_profile_setup "cheap ornamentation") and the inline `@usuario` VInput hint (label + immutable-username caption suffice — directive: one short hint). Hero→field 40, caption 4→8. Dropped `app_icon_sizes.dart` import. |
| `forgot_password_screen.dart` | Aurora 0.05. Hint→field 32→40. Back-to-login muted in both form + success states. |

Secondary links everywhere: plain `TextButton` + `AppColors.mutedStrong`
(the CTA is the only full-strength surface). Layout structure, routes,
providers, l10n keys, validation, cooldowns, counters and autofocus are
byte-identical; `VDisplayText` (MAYUS, no external glow) untouched.

## Decisions

- **Aurora opacity 0.05 on every form screen** (was 0.10 default). Form
  screens are input surfaces, not brand moments — the glow belongs to the
  hero gradient fill and the CTA halo (directive §2).
- **The glass card on privacy_terms was the "over-complication".** Two
  identical consent rows group naturally by adjacency; the card's gradient
  border + glow shadow stacked a third gradient surface on the hero's and
  the CTA's. Removed per directive §6.
- **`@usuario` hint vs the immutable caption:** the caption ("No podrás
  cambiar tu nombre de usuario…") is the information the user needs before
  committing; the inline hint merely echoed the label. Kept caption, dropped
  hint (directive §4: labels already sit above fields).
- **Muted `TextButton` for secondaries, not outline VButtons** — a second
  full-width bordered button competes with the primary (login hierarchy
  5/10). Disabled resend keeps its explicit muted color, which reads as the
  countdown's subdued state.

## MISTAKE blocks

- **MISTAKE (edit):** two large block-replacements (`profile_setup`,
  `forgot_password`) failed first try — stale whitespace assumption about
  comment placement after `appBar:`. Fix: re-read the file and split into
  smaller targeted edits.

## Verification

```bash
dart analyze lib/features/auth/screens/          # No issues found!
dart analyze lib/features/auth/ test/features/auth/   # No issues found!
flutter test test/features/auth/ test/features/auth_screens_test.dart
# 93/93 passed — no test updates needed (no finders pinned removed text;
# restyle_test §6.2 one-hero, errorText, glowAccent pins all intact)
```

## Sources

- Gemma 4 verdicts: `luxe-screenshots/verdicts/02_login.md` (hierarchy 5/10,
  "primary action doesn't dominate"), `03_signup.md` (minimalism 2/10,
  "overwhelming density / lack of whitespace"), `05_age_gate.md`
  ("visual cacophony… strip away the ornament"), `06_privacy_terms.md`
  ("trivial display of over-complication"), `07_profile_setup.md`
  (minimalism 1/10, "multiple overlapping elements… cheap ornamentation").
- LUXE v2 directive: `docs/history/phase-04-luxe/ORCHESTRATION-LUXE.md`
  (gradient family map, one hero per screen, no glow outside hero/CTA).
