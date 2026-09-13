# 2026-09-10 — Realtime assist reveal on the QR screen

## What was built

Task D: once a host/staff scanner confirms an attendee, an **already-open QR
screen** now flips live and plays the assist reveal.

1. **Screen-owned realtime seam** —
   `lib/features/qr/screens/attendance_code_screen.dart` now subscribes
   `event_attendances` for the event itself (`RealtimeService.
   subscribeToEventAttendances`, filtered to `event_id = <uuid>`), while mounted
   and not yet assisted, and invalidates `myAttendanceProvider(eventId)` on any
   row event. The channel is unsubscribed on **dispose** and the moment the
   call goes assisted (`_syncAttendanceRealtime` / `_unsubscribeAttendance`).
   This closes H2's known limitation: a deep-linked `/qr/:eventId` (no detail
   screen underneath) flips live too. RLS `ea_read_access` gates delivery — no
   new exposure.
2. **Transition-gated animation** — a per-mount `_sawLiveQr` flag is set only
   on the QR-rendered path (`_buildCode` → `CodeFetchStatus.ok`, i.e. a code is
   actually on screen). When the own-attendance read flips true, the terminal
   widget gets `animate: _sawLiveQr`: a false → true flip observed while the QR
   was live plays the reveal; opening already assisted renders the terminal
   state directly, no replay.
3. **Animated terminal state** — new feature widget
   `lib/features/qr/widgets/attendee_assist_animation.dart`
   (`AttendeeAssistAnimation`), replacing the static `_AlreadyAttended`:
   - QR + its thin ring scale `1 → 1.35` while fading `1 → 0` in the first
     `0–0.55` of the controller, `Curves.easeInCubic`;
   - a big check mark (`Icons.check`, `AppColors.success`, `size =
     kAttendanceQrSide * 0.6`) pops in at the QR position across `0.42–0.85`,
     `Curves.easeOutBack` for the scale + `Curves.easeOutCubic` for the clamped
     opacity — the inverse motion (nothing → in place);
   - the terminal word (`codeAssistedDone`, es "LISTO"/en "DONE") plus the
     existing caption ease + drift up in `0.62–1.0`, `Curves.easeOutCubic`.
   - The **Regresar** button (`VButton.outlined`) and the floating back arrow
     (`VHeaderTitleRow`) remain; the button is armed (`IgnorePointer`) only once
     the controller completes.
4. **Shared QR geometry** — new `lib/features/qr/widgets/attendance_qr_view.dart`
   owns `kAttendanceQrSide` (250) / `kAttendanceQrRingWidth` (3) and the
   `AttendanceQrView` module. The live rotating code (`_CountdownQr`) and the
   out-animation now render through the same module, so the QR that fades is
   literally the QR that was on screen (no duplicated tuneable).
5. **Duration token** — `SamayDurations.assistReveal` (1600 ms) added to
   `lib/core/theme/samay_durations.dart`; the widget composes its intervals from
   that single token.
6. **l10n** — `codeAssistedDone` ("LISTO" / "DONE") added to `app_es.arb`
   (template) + `app_en.arb`, regenerated with `flutter gen-l10n`.
   `codeAlreadyAttended` / `codeAlreadyAttendedReturn` kept and still used
   (caption + button).

No backend/migration change: Task D is Flutter-only. The running 54382 DB was
**not** touched; `event_attendances` was already on `supabase_realtime` from
Task C.

## Decisions made and why

- **Own the seam on the QR screen, not only the detail.** The detail's
  `_attendancesChannel` already flipped a QR pushed over it, but a
  notification deep-link to `/qr/:eventId` has no detail behind it. Subscribing
  on the QR screen itself is the only way that surface can live-flip; it also
  lets us unsubscribe as soon as the caller is assisted (the channel has no
  further job).
- **Gate the animation on `_sawLiveQr`, not on "is assisted".** The spec is
  explicit: animate the false → true transition observed while the QR is open,
  but render directly if already assisted. A per-mount flag set when a session
  is anchored is the smallest faithful test of "the QR was on screen".
- **Easing choices.** Out-motion (`easeInCubic`) reads as the QR accelerating
  away; in-motion uses `easeOutBack` for the check so it pops past its resting
  size and settles (the "big check" beat) with `easeOutCubic` for its opacity
  (easeOutBack overshoots > 1, which `Opacity` forbids — hence the split), and
  `easeOutCubic` for the text. The spec named exactly these curves.
- **Reduced motion.** Followed the existing repo contract
  (`MediaQuery.disableAnimationsOf(context)`, e.g. `VTabFade`, `VStatusDot`):
  the controller jumps to `1.0` and the terminal state renders statically, no
  ticker. Verified `didChangeDependencies` is the right hook (MediaQuery is not
  available in `initState`).
- **New duration token over an inline literal.** `SamayDurations` is the
  documented home for motion durations (it already carries feature tokens like
  `reactionBurst`/`reactionFloat`); inventing a hardcoded 1600 ms in the widget
  would violate the no-hardcoded-tuneables rule.
- **Keep the existing caption.** The old terminal headline ("Ya te registraste")
  is now the small caption under the big "LISTO"/"DONE" — the prominent word is
  the new spec, the existing key stays informative and used.

## MISTAKE blocks

- **MISTAKE — three-step animations cannot share one `Interval` curve with
  `easeOutBack` and `Opacity`.** The first draft used a single
  `easeOutBack` curve for both the check's scale and opacity; `MotionCurve`
  overshoots past `1.0` and `Opacity` asserts on values > 1. Split into a scale
  curve (`easeOutBack`, unclamped) and an opacity curve (`easeOutCubic`,
  clamped) over the same window.
- **MISTAKE — `_qrWidgetSide`/`_qrRingWidth` were file-private.** The reveal
  needs the same geometry; duplicating the constants would create two
  tuneables that can drift. Extracted the shared `attendance_qr_view.dart`
  (constants + `AttendanceQrView`) and pointed the live code at it.
- **MISTAKE — a `_sawLiveQr` flag set in the terminal branch would always be
  true.** It must be set when the live QR is actually rendered
  (`_buildCode` → `CodeFetchStatus.ok`), not when the terminal state renders;
  otherwise opening already-assisted would animate. It was initially put in
  `_applySession`, which also runs for an assisted host/staff whose code
  provider still resolves — moved to the `CodeFetchStatus.ok` path.

## Commands run (reproducible)

```bash
export AGENT_NAME=d-assist-anim
tools/agent_lock.sh list
tools/agent_lock.sh acquire <paths> --owner "$AGENT_NAME"

flutter gen-l10n
dart analyze                                 # No issues found!

make build TARGET=android                    # ✓ Built app-debug.apk
adb connect localhost:5565
adb -s localhost:5565 install -r build/app/outputs/flutter-apk/app-debug.apk   # Success
adb -s localhost:5565 shell monkey -p com.qallariy.samay -c android.intent.category.LAUNCHER 1
```

## Issues found / out of scope

- The reset wiped test data; the app launched to the login screen (an orphan
  local session was signed out — expected). Ready for the human to re-create /
  log in and tap-verify: host scans an open QR → QR expands + fades, check pops
  in, "LISTO"/"DONE" eases in below, Regresar stays available.
- Concurrent minigame-session hunks and other uncommitted work were preserved;
  only the files Task D needs were edited. No commit made.
- No Dart/Flutter or integration tests (deleted by directive) — validated via
  `dart analyze` + Android build/install/launch.
