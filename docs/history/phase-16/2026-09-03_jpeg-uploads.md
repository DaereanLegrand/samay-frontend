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

---

## Follow-up: every-device rising-reaction animation in the answer card

Follow-up to the tap burst (2026-09-03, same session): the "on every single
device participant screen, each reaction appears in the ANSWER CONTAINER moving
bottom → top" animation. Independent of the deck-slot burst — different
container, different mechanism; they merely coincide in time on the tapper's
device.

### What was built

- `_ReactionRiseCanvas` (truth_dare_screen.dart): wraps the by_turns answer
  card (`buildAnswerCard()` — every card variant: reactor `_WaitingCard`,
  subject `_SubjectWaitingCard`, both caption layouts) as the rise stage. A
  `Stack[child, Positioned.fill(IgnorePointer(ClipRect(LayoutBuilder)))]`
  overlays rising emoji particles clipped to the card — nothing escapes into
  the list below/above, and the card's own surface/hairline border is not
  clipped (the `ClipRect` wraps only the overlay).
- **Diff-driven, no backend change**: each device already receives the full
  ordered reaction list on the game-state realtime channel
  (`state.reactions[subjectId]`, server-ordered by `created_at`). The canvas
  diffs the list between rebuilds under the identity `round`:
  - a glyph at a brand-new index (a reaction just landed) → spawn a rise;
  - a CHANGED glyph at an existing index (a re-tap UPSERT replaces the voter's
    emoji in place — `created_at` unchanged) → spawn the new glyph's rise;
  - the FIRST sighting of a window (or after a round advance resets
    `_lastIdentity`) seeds the baseline SILENTLY — a late joiner mid-window
    never replays the reactions that already landed.
- `_RisingReactionParticle`: one emoji per reaction event. Starts fully hidden
  just below the card's bottom edge (`top = height + 4`), floats straight up
  the full card height, exits fully hidden just above the top edge
  (`top = -(fontSize + 4)`), `SamayDurations.defaultCurve`. Per user spec it
  carries a slight random horizontal position (12–88% of card width) and a
  0–320 ms random stagger; a fade-in/fade-out envelope (18/64/18) blurs the
  enter/exit. One-shot, 1.6 s. Reduced motion never creates a particle (the
  canvas gate skips spawns).
- New duration token `SamayDurations.reactionFloat` (1600 ms).
- Reuses `_ReactionEmoji` so the monochrome-Inter heart stays red in flight.

### Decisions

- Scope = by_turns answer cards ONLY. The async reactable tiles carry no live
  tally today and their mirror is SUBJECT-keyed (not per-round), so multi-round
  async answers from one subject would animate the wrong window; extending the
  mirror key is a prerequisite for async. Documented on the canvas.
- Rises ride the realtime echo rather than a separate event stream (no new
  table/column/channel). The tap-time local burst stays as-is per user
  ("completely different and independent … just so happen to happen at the
  same time").
- Identity = `round` (single window per round; the round's subject can't
  change mid-round). Diff by index, not by content-set, so re-taps (in-place
  UPSERT) animate the replacement glyph and the ordered list stays truthful.

### Commands run

```bash
dart analyze lib   # No issues found
```

Note: the project is NOT formatted to this Dart 3.12 formatter's defaults — an
unrelated `dart format` pass rewrote pre-existing chains (headlineSmall etc.);
those hunks were reverted manually to keep the diff minimal.

---

## Follow-up: per-tap reaction event — every tap animates on every device

Supersedes the diff-driven canvas above (which only animated when the tally
mirror CONTENT changed). User requirement refined: the rise "must happen each
time the user taps" AND "users can also react with the same one more than one
time" — i.e. a SAME-EMOJI re-tap must be visible on every device — "well no
spam, like maybe some limits".

### The problem (validated)

A same-emoji re-tap UPSERTs the voter's row in place (`ON CONFLICT DO UPDATE`
keeps `created_at`), so `state.reactions` is byte-identical to the previous
tap. The diff-driven client could not distinguish "reacted the same emoji
again" from "nothing" — remote devices never saw the re-tap rise.

### What was built — backend (migration 207, TDD)

`supabase/migrations/207_minigame_reaction_event/reaction_event.sql` (+
byte-identical `supabase-testing/` mirror) CREATE OR REPLACEs the two reaction
write RPCs (`submit_minigame_reaction`, `react_minigame_round`) to fold two
new fields into the SAME atomic mirror UPDATE (one realtime emission):

- `state.reactions_seq` — session-global monotonic bigint, bumped +1 on EVERY
  write (inline `COALESCE((state->>'reactions_seq')::bigint,0)+1` computed
  against the pre-UPDATE row). NEVER reset on advance (round identity rides
  the event's own `round`).
- `state.reactions_event` — jsonb `{seq, round, reaction, voter_id}`; the
  exact tapped emoji per tap (NULL reaction = reactor Pasar, no rise).

Tests (2 layers per budget): 8 pgTAP assertions in Section 49r
(`supabase/tests/schema_test.sql` plan 921→929) + `test/opt-023-minigame-
reaction-event.sh` (by_turns same-emoji re-tap seq 1→2→3, seq preserved on
auto-advance, async `react_minigame_round` event carries the target round,
Pasar → reaction null). Auto-discovered by `run_all_backend.sh` (no
registration needed).

### What was built — client

- `ReactionEvent` model + `reactionsSeq`/`reactionEvent` on `GameTurnSkeleton`
  (minigame_engine.dart); `hasEmoji` false for a Pasar.
- `SamayDurations.reactionTapCooldown` (350 ms) — the per-device spam limit.
- `_ReactionRiseCanvas` (truth_dare_screen.dart) is now EVENT-driven:
  - baselines `seq` on first sight of a round AND on every round change (a
    late joiner never replays history; the session-global counter means the
    round-change reset is the only place a stale high seq is skipped);
  - on a row with `seq` > applied AND an event whose `round` == the shown
    round → spawn the event's emoji. Works for same-emoji re-taps (identical
    mirror, new seq) and emoji changes alike.
  - the voter's OWN echo is deduped (`voter_id == me` → no remote rise; the
    instant local rise already played).
- Per-session local-rise bus `_localRiseProvider` (NotifierProvider.family):
  the by_turns `_ReactionRow` deck calls `reserveTap()` (cooldown gate — a tap
  inside 350 ms is swallowed: no RPC + no rise) then `emit(kind)` for an
  accepted emoji tap; the canvas consumes it and floats the emoji up the
  tapper's OWN card INSTANTLY (no realtime round-trip). Pasar emits nothing.

### Decisions

- User chose: tapper gets INSTANT local feedback every accepted tap; every
  device animates remote taps via the seq event. A backend seq/event was
  REQUIRED for same-emoji re-taps to be visible on other devices — client-only
  diffing cannot express it. Scope stays by_turns answer cards (async tiles'
  mirror is not per-round).
- Cooldown (350 ms) at the DECK, not the canvas: rapid fire is bounded at the
  source; deliberate alternating taps each fire. The deck burst is untouched
  (independent container).
- `seq` compared, not timestamps: the server serializes writes so seq ordering
  is exact even for same-millisecond taps.
- Inline counter (two nested `jsonb_set` reads of the old row) instead of a
  PL/pgSQL variable: Postgres evaluates the whole UPDATE RHS against the
  pre-UPDATE snapshot, so `reactions_seq` and `event.seq` are provably the
  same +1 and the RPC body keeps its exact 204 gates.

### MISTAKE block

**MISTAKE: swallowing the first realtime event as a "late join".** My first
canvas draft baselined `_lastSeq` only when the first EVENT arrived, which
silently ate the very first reaction of a window. Fixed: baseline from the
row's CURRENT `reactions_seq` on first build / round change (`round !=
_lastRound`), and only diff strictly-greater seqs afterwards.

### Commands run

```bash
dart analyze lib                                   # No issues found
bash test/opt-005-seeds-static.sh                  # 45 checks pass
bash tools/check_migrations.sh                     # parity/layout pass; 1 failure = UNTRACKED migrations (must be committed before apply — inherent contract)
diff -rq supabase/migrations supabase-testing/migrations   # byte-identical
bash test/opt-007-compose-static.sh                # migration parity pass; SERVICE_KEY drift is the pre-existing local-.env baseline
```

---

## Follow-up: bigger swaying rise + emoji ↔ Pasar exclusivity (2026-09-04)

### 1. Rise particle: bigger + random-frequency/amplitude wobble

- `_RisingReactionParticle` (truth_dare_screen.dart) renders the emoji at
  **44 px** (was 28 — clearly larger than the deck's ~24 px tiles).
- Horizontal sway is now a **random sinusoid** per particle: `_wobbleCycles` =
  1.5–3.5 full cycles over the rise (random frequency) and `_wobbleAmplitude` =
  6–18 px (random amplitude), both drawn once in `initState`. The rise lane
  `_dx` stays random, plus the 0–320 ms stagger, so a burst looks organic.
  `Offset(_sway(t), _top.value)` composes the drift with the rise.

### 2. Emoji ↔ Pasar exclusivity (user: "if reacting has chosen emoji then
can't choose Pasar and vice versa")

- **Server (migration 207, both RPCs)**: before the upsert, each reaction write
  reads the caller's existing row for the target round. `p_reaction='pasar'`
  when the voter already emoji-reacted → `already_reacted`; an emoji when the
  voter already passed → `already_passed`. **Emoji → emoji re-votes remain
  allowed** (upsert replaces) — the lock is cross-mode only. The mirror also
  gains `state.reactions.<subject>.voters` (`jsonb_object_agg(voter_id::text,
  reaction)`, null = pass) so clients can render the exclusivity.
- **Client (by_turns `_ReactionRow`)**: computes `myEmojiReacted`/`myPassed`
  from the new `reactionVoters` map (`GameTurnSkeleton.votersFor/hasVoterEmoji-
  Reacted/hasVoterPassed`). Once the caller passed, every emoji tile is
  **greyed out (0.35 opacity) and inert** (`_ReactionDeckButton.disabled` — no
  press/burst/rise); once the caller emoji-reacted, the **Pasar button is
  disabled**. Async reactable tiles stay server-enforced only (the async mirror
  is subject-keyed, so a per-round grey-out would be ambiguous for multi-round
  subjects).
- New client error mappings for `already_reacted`/`already_passed` in both
  service methods (ConflictError snackbar).
- Tests: 5 new pgTAP assertions (Section 49r; plan 929→934) + opt-023 reworked
  TEST C (emoji-voter's Pasar rejected `already_reacted`, emoji→emoji still
  advances seq) and new TEST E (passer's emoji rejected `already_passed`, the
  `voters` mirror carries the passer as null).

### Decisions

- Cross-mode-only lock, not full lock: the user can still change their mind
  WITHIN a mode (emoji→emoji), which the upsert always supported; only the
  emoji↔pass boundary is exclusive.
- `voters` rides the existing mirror (no new table/channel); json null is the
  pass marker (mirrors the `minigame_reactions.reaction` NULL from 204).
- Grey-out is server-truth driven (not a local flag) so every device converges;
  a mid-flight cross-mode tap is additionally rejected by the RPC.

### Commands run

```bash
dart analyze lib                                   # No issues found
bash -n test/opt-020-minigame-voting.sh test/opt-021-minigame-play-v2.sh test/opt-023-minigame-reaction-event.sh   # syntax OK
diff -rq supabase/migrations supabase-testing/migrations   # byte-identical
diff supabase/tests/schema_test.sql supabase-testing/tests/schema_test.sql   # byte-identical
bash tools/check_migrations.sh                     # parity/layout pass (UNTRACKED = commit-first contract)
```
