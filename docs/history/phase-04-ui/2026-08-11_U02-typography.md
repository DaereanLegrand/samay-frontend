# U-02 — Typography tokens: `app_typography.dart` + theme consumption (2026-08-11)

**Agent:** U-02 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §3 (read in full — THE
CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` +
`docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/DEVELOPMENT-WORKFLOW.md` (read
in full), I-16/I-17/I-18/U-01 logs, Juega reference (read-only, structure
study). Baseline before edits: `dart analyze` 0 issues; `flutter test
test/design_tokens/ test/theme/` 69/69; full `flutter test` 1651/0 (U-01
checkpoint).

## What was built

1. **`lib/core/design_tokens/app_typography.dart` (NEW — U-02's §3 deliverable):**
   the typography token layer finalizing I-17's inline theme typography:
   - `AppTypography` (abstract final const class), family consts
     `playfair`/`inter`, and the **complete §3.3 role table** as
     **const-constructible `TextStyle`s** with the doc's EXACT values:
     `displayLarge` 64/w700 italic/Playfair/-1.9/1.0 ·
     `displayMedium` 40/w700 italic/-1.2/1.0 · `displaySmall` 32/w700
     italic/-1.0/1.05 · `headlineLarge` 28/w600 italic/-0.8/1.1 ·
     `headlineMedium` 24/w700 Inter/-0.3/1.2 · `headlineSmall` 20/w600 ·
     `titleLarge` 18/w600/0/1.4 · `titleMedium` 16/w500/0/1.4 · `bodyLarge`
     16/w300/0/1.5 · `bodyMedium` 14/w300/0/1.5 · `bodySmall` 12/w400/0/1.5 ·
     `labelLarge` 14/w700/1.2/1.2 · `labelMedium` 12/w600/0.8/1.3 ·
     `labelSmall` 10/w500/1.2/1.3 · **`otpInputText` 30/w800/8/1.5** (the
     §3.3 table's extra row).
   - **`fancyTitle(TextStyle base, {bool soft})`** — I-17's `glowTitleStyle`
     consolidated: the §3.4 canonical stacks with `em`-relative blur radii
     (glow-strong 3 layers α0.9@0.35em/α0.5@0.7em/α0.25@1.0em; glow-soft 2
     layers α0.6@0.3em/α0.25@0.6em), fill left opaque (§7.4 legibility).
   - **`AppTypography.textTheme`** — the composed `TextTheme` (glow baked
     into the four Playfair roles: strong ≥32px, soft 28px); roles outside
     §3.3 (titleSmall/caption/overline) stay null so `ThemeData` merges
     Material defaults — same roles I-17's `base.copyWith` left untouched.
2. **`lib/core/theme/app_theme.dart`** — I-17's inline typography removed
   (the 100-line `_textTheme` + `glowTitleStyle` are gone); the theme now
   consumes `AppTypography`: `fontFamily: AppTypography.inter` +
   `textTheme: AppTypography.textTheme` in the `ThemeData` constructor.
   **Zero visual change verified** — every existing theme assertion
   (`displayLarge` Playfair italic 700 at 64, glow stacks, Inter body roles)
   stays green unchanged; the merged `TextTheme` (constructor
   `defaultTextTheme.merge(textTheme)`) fills color + non-table roles
   identically to the previous `base.copyWith` composition.
3. **Tests** — TDD: `test/design_tokens/app_typography_test.dart` (NEW, 26
   tests): table-driven §3.3 assertions for all 16 roles (family/size/
   weight/style/letter-spacing/height), const-constructibility (compile-time
   const + canonical identical), `fancyTitle` strong/soft stacks with exact
   α + `fontSize×f` blur radii, italic+bold preservation, opaque fill, em-
   scaling; `textTheme` composition (Playfair+glow on display roles, Inter
   no-glow on body/UI, const-base↔themed consistency). `test/theme/
   app_theme_test.dart` — glow tests repointed `SamayTheme.glowTitleStyle` →
   `AppTypography.fancyTitle` (+2 new: theme driven by tokens; non-table
   roles keep Material defaults).

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire <path> --owner U-02` (held
03:12Z, all released after edits):

| File | Action | Lock evidence |
|---|---|---|
| `lib/core/design_tokens/app_typography.dart` | created | acquire 4ff45c3634cad30ba6e3b371 → release |
| `lib/core/theme/app_theme.dart` | modified (consume tokens) | acquire 5012349ec44717814afddeb2 → release |
| `test/design_tokens/app_typography_test.dart` | created | acquire fc126d5fdcf054dc63730181 → release |
| `test/theme/app_theme_test.dart` | modified (+2, repointed glow tests) | acquire 0df1a90c7bf3f192538baf73 → release |
| `docs/to-fix/TODO.md` | modified (U-02 workstream block) | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U02-typography.md` | created (this log) | acquire 7144a9e9ced37066f25dc10e → release |

Feature screens: **zero changes** — the fancy treatment is applied exactly
where the doc wants it *today* via the theme roles (see application map).
U-07/U-08/U-11/U-12 own the files where Playfair must *still* land (visual
change = their restyle scope).

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-02"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test test/design_tokens/ test/theme/               # baseline 69/69
tools/agent_lock.sh acquire <6 files> --owner U-02         # one per command
flutter test test/design_tokens/app_typography_test.dart   # RED: file absent
# ... write tests (table-driven §3.3 + §3.4 + const) ...
flutter test test/design_tokens/app_typography_test.dart   # GREEN 26/26
flutter test test/theme/app_theme_test.dart                # GREEN 27/27
dart analyze                                               # 0 issues
flutter test test/theme/ test/design_tokens/               # 97/97
flutter test                                               # 1679/0 (baseline 1651 → +28)
tools/agent_lock.sh release <path> --owner U-02            # all 6
```

## Test results

- `test/design_tokens/app_typography_test.dart` — **26/26** (new).
- `test/theme/app_theme_test.dart` — **27/27** (was 25; +2 new, glow tests
  repointed to `AppTypography.fancyTitle`).
- `flutter test test/theme/ test/design_tokens/` — **97/97** (was 69/69).
- `flutter test` (full) — **1679 pass / 0 failures** (U-01 baseline 1651/0,
  +28 = the new tests; zero regressions).
- `dart analyze` — **0 issues**.

## Decisions made and why

- **`AppTypography.textTheme` leaves non-§3.3 roles null** instead of
  hardcoding `titleSmall`/`caption`/`overline`: `ThemeData` merges Material
  defaults at construction (`defaultTextTheme.merge(textTheme)` — verified
  in the Flutter SDK `theme_data.dart:524`), exactly reproducing I-17's
  `base.copyWith` behavior where those roles were untouched. Zero churn,
  no invented values.
- **`fancyTitle` is the single glow helper** (I-17's `glowTitleStyle`
  consolidated): the theme no longer carries glow logic; screens compose
  ad-hoc brand moments via `AppTypography.fancyTitle(...)` (U-06/U-12).
  The old `SamayTheme.glowTitleStyle` name is gone — no external usages
  existed (grep-verified).
- **`letterSpacing: 0` is explicit** on title/body roles (doc table says 0;
  I-17 omitted it as null → rendered 0). Explicit 0 == null render; kept to
  match the doc table verbatim.
- **`otpInputText` ships as a token but the OTP screen was NOT touched:**
  the field currently uses an inline `TextStyle(fontSize: 32,
  letterSpacing: 12)` (otp_verification_screen.dart:173) — switching to
  30/w800/ls8 is a visual change + the file is U-07's. Handed off below.
- **Zero feature edits:** `welcome_screen.dart:20` (displayLarge), `banned_screen.dart:38`
  (displayMedium), `feed_screen.dart:113` (displaySmall), `event_detail_screen.dart:138`
  (headlineLarge) already render Playfair+glow through the theme roles — the
  refactor preserves them byte-for-byte.

## MISTAKE

- **Test compile error ×2 (fixed):** first wrote `weight.w` then `weight.weight`
  in a test-name interpolation — `FontWeight` exposes neither; the weight was
  only cosmetic in the description, removed. Lesson: don't interpolate
  `FontWeight` internals into test names; keep names to family/size.
- **Assumed `caption`/`overline` exist on `TextTheme`** for the "non-table
  roles" assertion — this Flutter version (3.44.1) removed them from the M3
  `TextTheme` API (they're legacy M2 names; doc comment maps them to
  bodySmall/labelSmall). Switched the assertion to `titleSmall` (the one
  real non-§3.3 role) + bodySmall/labelSmall.

## Issues found / handoffs (fancy-title application map)

The theme roles carry the fancy treatment everywhere it exists today.
Playfair Display italic + glow must land in these spots (all visual changes,
all in other agents' owned files):

| Where | Doc §3.2 | File (owner) | Instruction |
|---|---|---|---|
| Welcome wordmark | 64 | `welcome_screen.dart:20` (U-07) | ✅ already `displayLarge` — nothing to do |
| Auth big headers ("Crea tu cuenta", "¿Cuál es tu fecha de nacimiento?", "Verificar edad"…) | 40 | `signup_contact_screen.dart:109`, `age_gate_screen.dart:40`, `otp_verification_screen.dart:160`, `privacy_terms_screen.dart:36` (U-07) | switch `headlineMedium` → `displayMedium` |
| OTP code input | 30/w800/ls8 | `otp_verification_screen.dart:173` inline (U-07) | use `AppTypography.otpInputText` |
| Feed hero header | 32 | `feed_screen.dart:113` (U-08) | ✅ already `displaySmall` — nothing to do |
| Router shell AppBar titles | 32 | `app_router.dart` coming-soon titles (U-08) | use `displaySmall` for brand titles |
| Ban screen title | 40 | `banned_screen.dart:38` (U-07) | ✅ already `displayMedium` — nothing to do |
| Event titles (detail hero) | 28 | `event_detail_screen.dart:138` (events — I-55/U-05 era) | ✅ already `headlineLarge` — nothing to do |
| Leaderboard podium names (top 3) | 28 | `leaderboard_screen.dart:79` ListTile (U-11) | podium rows → `headlineLarge` + glow-soft |
| Group names on detail hero | 28 | `group_detail_screen.dart` AppBar title (U-11) | hero name → `headlineLarge` |
| Coming-soon "Próximamente" | 32 | `v_coming_soon.dart:34` inline 24/bold (U-12) | `fancyTitle(displaySmall, soft: true)`-style Playfair 32 |
| Donate header | — | `donate_shards_screen.dart:82` `headlineMedium` (U-11) | keep Inter (not a §3.2 Playfair site) |

- **U-04/U-27:** `SamayTheme` no longer exposes `glowTitleStyle` — the
  canonical helper is `AppTypography.fancyTitle`. Any future theme work
  should read tokens from `AppTypography`, not inline styles.
- **U-30 (doc finalization):** `otpInputText` is a token now; consider a
  §3.2 row for the OTP input if the field grows a brand accent.
- **U-26 (a11y):** display roles remain AA under the glow (fill opaque,
  halo behind — §7.4); unchanged from I-17's verified baseline.

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §3 (typography contract, read in
  full), §7.4.
- Flutter SDK source (read-only): `material/theme_data.dart` (constructor
  `textTheme = defaultTextTheme.merge(textTheme)` — the merge semantics
  relied on for zero-churn consumption), `material/text_theme.dart`
  (`TextTheme.merge`, M3 role set — no `caption`/`overline` in 3.44.1),
  `painting/text_style.dart` (`TextStyle.merge`).
- Juega (read-only): no typography layer reference needed — Samay's values
  are the doc's own.
