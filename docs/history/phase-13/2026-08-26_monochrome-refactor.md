# 2026-08-26 — Monochrome refactor: lowercase heroes, white display text, gradient system deleted

## What was built

Full-app visual refactor per user directive (2026-08-26): "SAMAY in minuscule
'samay', same for feed screen, same for CREA TU CUENTA, all white same as
login, all next steps of account setup, in general — all color stripped
down."

1. **`VDisplayText` rewritten** (`lib/shared/widgets/v_display_text.dart`):
   renders copy VERBATIM (the MAYUS `toUpperCase()` rule is deleted), flat
   white Playfair bold. The ShaderMask gradient fill, the once-only shimmer
   sweep and the ticker are gone (stateless now). One widget change fixed the
   casing + whiteness contract for every hero in the app.
2. **l10n brand values**: `feedBrand` "Samay" → **"samay"**,
   `welcomeVive` "VIVE" → **"vive"** (en+es ARB, regenerated).
3. **Gradient system deleted**: `lib/core/design_tokens/app_gradients.dart`
   removed; `VGlowPulse` widget + its test deleted; dead duration tokens
   (`glowPulse`, `glowBreath`, `displaySweep`, `glassHover`) removed from
   `samay_durations.dart`.
4. **Shared widgets de-accented**: `VButton` (variants outlined/emphasized/
   dark only; `glowAccent`/`gradient:`/`filled` deleted — former glow CTAs
   are `VButton.dark`, matching the login voice), `VChip` (no `.accent`),
   `VBadge` (flat semantic accent only, `color` required),
   `VCountBadge` (white on black), `VDiscoDivider` (white tick default).
5. **~30 feature screens swept**: auth flow (welcome/login/signup/age gate/
   privacy/OTP/profile setup/banned/forgot), feed, events, groups, friends,
   profile, chat, minigames, cosmetics, party finder, notifications,
   paywall, photos, QR, shards ledger. Nav-shell violet glow removed.
6. **Semantic colors kept** (user decision): error pink, chat read-blue
   ticks, live/online dots, gold shards/rank metals — as flat tokens only.
7. **Guards**: `test/meta/conventions_test.dart` gains a monochrome group —
   bans `AppGradients`/`app_gradients` references anywhere in `lib/` and
   pins the token file as deleted.

## Decisions

- **Verbatim heroes, not re-cased strings**: deleting the uppercase
  transform in `VDisplayText` (instead of lowercasing every l10n string)
  keeps sentence-case Spanish natural ("Crea tu cuenta") while the brand
  strings themselves were lowercased in the ARBs ("samay", "vive").
- **glowAccent → dark**, not emphasized: the black button is the documented
  primary-CTA voice (2026-08-14 directive); emphasized (white fill) stays
  reserved for form submits in the auth flow where it was already flat.
- **QR countdown ring stays cyan** (flattened to a solid `discoCyan`
  stroke): it is functional rotation-timing feedback, not decoration.
- **Shard balance keeps gold** as a flat `discoGold` TextStyle (currency
  semantics), replacing the gold ShaderMask.

## MISTAKE

Typing `isNot(eitherContains(...))` with a custom `Set` extension inside
`v_chip_test.dart` collided with flutter_test's `contains` Matcher and
failed to compile. Lesson: don't fight the test-framework matchers with
same-named helpers — assert explicit values instead.

## MISTAKE

The first conventions-guard draft mapped `File` objects with `.map(relative)`
(compile error: `String Function(File)` vs `String Function(String)`).
Fixed with `.map((f) => relative(f.path))`.

## Commands run

```
flutter test test/widgets/v_display_text_test.dart          # RED then GREEN
make check                                                  # PASS (exit 0)
flutter test                                                # 2413 pass / 0 fail
make test-unit test-go                                      # PASS (Go all ok)
bash test/opt-001-rls-security.sh                           # passes at runtime
```

## Pre-existing issue found (reported, not fixed)

`test-backend-static` → `opt-007-compose-static.sh` now reports
"SERVICE_KEY default != .env dev value" for opt-001..006. None of those
files (nor `.env`) are touched by this session's diff — the local gitignored
`.env` drifted from the scripts' inlined dev defaults after the 2026-08-25
baseline (runtime runs still pass because they fall back to `.env`). Needs
an env-alignment pass by whoever owns key material.

## Baselines moved

Flutter unit/widget: 2454 → **2413 pass** (deleted `app_gradients_test`,
`v_glow_pulse_test`, plus LUXE-only assertions consolidated into monochrome
equivalents). README updated in this change.
