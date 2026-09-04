# 2026-09-03 — All user uploads are client-side quality-80 JPEGs

## What was built

- **JPEG pipeline** (`lib/core/utils/image_processor.dart`): every upload now
  goes through one funnel — `dart:ui` decode (HEIC-safe) → optional 1920px
  long-edge downscale on decode → `image`-package `encodeJpg(quality: 80)`.
  Removed the old `<512 KB` pass-through and the "already within cap → keep
  original" early-returns: the stored object is **always a JPEG**, regardless
  of source format or size.
- **Storage paths** (`lib/core/services/media_service.dart`): group covers,
  event covers, avatars and event photos now upload as `.jpg` (were `.png`);
  doc comments updated. Buckets set `allowed_mime_types = NULL` and RLS
  policies match on path only, so the extension change is safe server-side.
- **E2EE minigame images** (`truth_dare_screen.dart`, both submit sites):
  picked bytes are downscaled + JPEG-encoded **before**
  `MinigameCipher.encryptAnswerImage` — so the ciphertext stored/downloaded
  per viewer is the compressed JPEG, cutting storage and decrypt+decode time.
- **Removed a latent double-compress** (`photos_providers.dart`): the upload
  provider pre-compressed and then `uploadEventPhotoBytes` compressed again.
  Harmless under the old no-op-2nd-pass logic; would have double-JPEG-lossy
  now. The provider feeds raw bytes; the service owns the single encode.
- **Dependency** (`pubspec.yaml`): promoted `image: ^4.8.0` from dev/transitive
  (it arrived via `flutter_launcher_icons`) to a direct main dep — the pure-Dart
  JPEG encoder `dart:ui` lacks. `flutter pub get` → lockfile flips `image` to
  `direct main`; no new package added.

## Decisions

- **Central `ImageProcessor` funnel + `image` package** (user-confirmed) over
  per-call native `image_picker` params: one encode seam covers all 5 flows
  including the E2EE path; native params would have needed a "skip re-encode of
  picked JPEG" coordination and couldn't touch the minigame bytes path anyway.
- **Always transcode to JPG** (user-confirmed), no size/cap exemption: "every
  upload is JPG" is the invariant. Small PNGs/HEICs (which the old skip logic
  passed through untouched) now re-encode too.
- **JPEG quality 80** matches Juega's reference. Lossy is acceptable for
  photos; alpha is composited onto white by the encoder (a fully transparent
  PNG uploads as white).
- Dropped the "never grow a payload" guard (return original if bigger): it
  would have violated the always-JPEG invariant on the rare oversized tiny
  encode. Uniform format beats the marginal byte saving.

## MISTAKE blocks

**MISTAKE: latent double-encode.** `photos_providers.dart` compressed, then
`MediaService.uploadEventPhotoBytes` compressed again. Before this change the
second pass was a near-no-op (within-cap → original returned untouched), so it
was never caught. After switching to "always re-encode", a second pass would
have been a second lossy generation. Lesson: when centralizing a transform in
a service, grep every caller for a pre-transform of the same kind.

## Commands run

```bash
flutter pub get
dart analyze lib   # No issues found
```

## Validation

`dart analyze lib` is clean across the four touched source files and the whole
tree. No backend change → no Go/pgTAP/opt-test delta. Flutter test trees were
deleted per directive 2026-08-31, so Dart changes validate via the analyzer
and the backend opt-tests that pin the REST/RLS storage contract (unchanged —
paths/RLS are extension-agnostic).

---

## Follow-up: "esperando X/Y reacciones…" visible to every participant

### What was built

- The by_turns reaction tally line (`minigamesAnswerWaitingReactions`) was
  previously rendered ONLY inside `_SubjectWaitingCard` — the round's subject's
  own post-answer view. Non-subject reactors saw the subject's answer preview +
  the reaction deck but no tally, so they could not tell how many reactions were
  still owed.
- Extracted a shared `_ReactionsWaitingLine` widget (skeleton + roster → the
  `reacted/required` text) and rendered it in BOTH views:
  - `_SubjectWaitingCard` (subject, after answering) — unchanged placement.
  - `_WaitingCard` (every non-subject) in the answered-and-not-passed branch —
    i.e. exactly the same window `canReactToCurrentRound` opens the reaction
    row, so subject and reactors watch the same countdown.

### Decisions

- The tally counts distinct voters (emoji OR reactor-Pasar) vs the roster minus
  the subject — identical to the server's by_turns auto-advance gate, so the
  line reaches X/Y at the moment the round closes.
- Async mode is untouched: it has no single shared "waiting X/Y" round — each
  completed async round is an independently reactable tile, so the reported
  subject-only line does not exist there.

### Commands run

```bash
dart analyze lib/features/minigames/screens/truth_dare_screen.dart   # clean
flutter analyze lib/features/minigames/screens/truth_dare_screen.dart # clean
```

---

## Follow-up: red minigame heart + tap reaction-burst animation

### What was built

- **Red heart fix** (truth_dare_screen.dart): the `❤️` reaction tile rendered
  WHITE on every device. Root cause: the app's Inter font ships a MONOCHROME
  U+2764 glyph, so Flutter paints the character in the text foreground color
  (white) instead of falling back to the platform color-emoji font (verified
  Inter's cmap contains U+2764; Quicksand/Playfair do not). Extracted a
  `_ReactionEmoji` widget that tints the heart glyph with `AppColors.badgeRed`
  — deterministic red across iOS/Android regardless of which font draws it.
  The other five reaction emoji are NOT in Inter, so they already render as
  color emoji and are untouched.
- **Tap burst animation** (`_ReactionDeckButton`, used by BOTH reaction decks
  — by_turns `_ReactionRow` and each `_AsyncReactableTile`): on tap of an
  emoji, a duplicate of that emoji appears stacked centered in the SAME slot,
  scales 1.0 → 1.9 while its opacity ramps 0 → 1 (first ~30%) then fades to 0
  and disappears. One-shot, 700 ms, respects reduced-motion
  (`MediaQuery.disableAnimationsOf` → no ticker, reaction still fires).
- New duration token `SamayDurations.reactionBurst` (700 ms) in
  samay_durations.dart.

### Decisions

- The burst is SELF-ONLY feedback on the tapping device for now (user: the
  animation described is the tap-time one; the over-the-answer-card variant
  for other participants is follow-up work). The deck still calls the existing
  react RPC; the realtime echo path is untouched.
- Heart tint over swapping the heart for a red material icon: keeps the emoji
  identity (still the ❤️ character in the reaction list) while fixing color.

### Commands run

```bash
dart analyze lib   # No issues found
flutter analyze lib/features/minigames/screens/truth_dare_screen.dart lib/core/theme/samay_durations.dart  # clean
```

---

## Follow-up: reaction burst was invisible — app-wide ANIM-OFF root cause

### What was built

- The tap reaction-burst added earlier never played on ANY device, even though
  the red-heart fix (same `_ReactionDeckButton` tree) visibly worked.
- Root cause: `lib/app.dart` (ANIM-OFF, 2026-08-14) wraps the whole app in
  `MediaQuery(disableAnimations: true)`. My `_handleTap` honored
  `MediaQuery.disableAnimationsOf(context)` and therefore skipped the burst
  entirely — every session had reduced-motion forced on, so the gate was
  always false.
- Fix: the burst now plays unconditionally in `_handleTap`
  (`_burst.forward(from: 0)` with no gate). `AnimationController` ticks
  normally under `disableAnimations` (that flag is opt-in — VSpinner/VStatusDot
  prove controllers run); the deck still fires the reaction in all cases.

### Decisions

- Explicit product override of the app-wide static-motion rule: the burst is
  the tactile confirmation that the tap registered, so suppressing it defeats
  its purpose. Documented in the widget doc comment.

### Commands run

```bash
dart analyze lib   # No issues found
```

---

## Follow-up: ANIM-ON — remove the app-wide forced `disableAnimations`

### What was built

- `lib/app.dart`: removed the `MediaQuery(disableAnimations: true)` wrapper
  (ANIM-OFF 2026-08-14) that deactivated EVERY animation app-wide. The builder
  now returns the `Stack` directly (the `mediaQuery` read is kept only for the
  crash-banner bottom padding). Motion now runs and is suppressed only by
  OS-level reduced motion via the per-widget `MediaQuery.disableAnimationsOf`
  checks that already exist (VSpinner static ring, VStatusDot static dot,
  StaticPageTransitionsBuilder static routes, the reaction burst, etc.).
- The reaction-burst gate in `truth_dare_screen.dart` reverts to the normal
  opt-in `if (!MediaQuery.disableAnimationsOf(context))` — with the app-wide
  force gone, the earlier "play unconditionally" hack is dead (KISS).
- Doc comments updated where they claimed the app "forces it in SamayApp":
  `app_theme.dart` (page transitions), `v_spinner.dart`, `DESIGN.md` §principle 5.

### Decisions

- User directive: `disableAnimations: false` + KISS. Kept the MediaQuery
  builder (not removed) because the crash banner still needs
  `mediaQuery.padding.bottom` — minimal diff, no structural rewrite.
- Widgets that already honor reduced motion were LEFT as-is: they now do the
  right thing (animate normally, suppress under real OS reduced motion).

### Commands run

```bash
dart analyze lib   # No issues found
flutter analyze lib/app.dart lib/core/theme/app_theme.dart lib/shared/widgets/v_spinner.dart lib/features/minigames/screens/truth_dare_screen.dart  # clean
```

---

## Follow-up: reaction emoji press-down shrink + spring-back

### What was built

- `_ReactionDeckButtonState` (truth_dare_screen.dart) gained a second short
  controller `_press` (SamayDurations.fast, easeOutCubic): while the finger is
  DOWN on an emoji the RESTING glyph shrinks 1.0 → 0.9 (`ScaleTransition` on
  the resting emoji, under the burst duplicate). On release (`onTapUp`) the
  emoji springs back to 1.0 at the same moment `onTap` fires the react + burst
  — the emoji "goes back to its original size AND the animation plays at the
  same time" (user spec). `onTapCancel` (drag-away) also springs back.

### Decisions

- Two independent single-ticker controllers (`_press` + `_burst`) instead of a
  combined curve — KISS, each has one job. Both honor reduced motion.
- Shrink scale 0.9 (subtle, fast token) so the "smaller while pressed" is
  legible without feeling mushy.

### Commands run

```bash
dart analyze lib   # No issues found
flutter analyze lib/features/minigames/screens/truth_dare_screen.dart  # clean
```

---

## Follow-up: SingleTickerProviderStateMixin assertion (two tickers)

### MISTAKE block

**MISTAKE: two AnimationControllers on a SingleTickerProviderStateMixin.**
Adding `_press` to `_ReactionDeckButtonState` (which already had `_burst`) but
leaving `SingleTickerProviderStateMixin` produced a runtime crash on first
layout:

`_ReactionDeckButtonState is a SingleTickerProviderStateMixin but multiple
tickers were created.`

Fix: mix in `TickerProviderStateMixin` (multi-ticker) instead. One-line change;
`dart analyze` clean. Lesson: a State that owns more than one controller needs
the non-single variant — the single mixin asserts on the SECOND `createTicker`.

### Commands run

```bash
dart analyze lib   # No issues found
```
