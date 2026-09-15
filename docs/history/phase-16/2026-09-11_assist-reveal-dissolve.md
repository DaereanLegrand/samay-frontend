# 2026-09-11 — Assist reveal: in-place dissolve + inverse condense

## What was built

Rework of Task D's terminal reveal (`AttendeeAssistAnimation`) after the
user's review of the first version.

1. **Regresar button removed.** The terminal state no longer renders a
   `VButton.outlined`; the floating header back arrow (`VHeaderTitleRow`,
   `showBack: true` by default) is the only way out. Dropped `returnLabel` /
   `onReturn` from the widget and the call site
   (`attendance_code_screen.dart`), and deleted the now-dead
   `codeAlreadyAttendedReturn` l10n key (ARBs + regenerated localizations).
2. **No horizontal/vertical movement.** The first version laid the terminal
   state out as a centered `Column` (QR + word + button). Centering that column
   pulled the QR off screen-centre, so at the flip the QR visibly jumped UP —
   the "QR flashes moving up / animation begins wrong" the user reported. The
   rework mirrors the live screen: a full-bleed `Stack` with
   `Center → FittedBox(scaleDown) → SizedBox(250)` pinning the QR+check at the
   live code's exact position, and the word in an independent
   `Positioned(top: …)` overlay (computed from `LayoutBuilder`) so it can never
   shift the QR.
3. **QR dissolves instead of expanding.** No `Transform.scale`; opacity `1→0`
   while blurring `0→kAssistDissolveBlur` (18) through `ImageFiltered`.
4. **Check + "LISTO"/"DONE" are the exact inverse.** They condense in at the
   QR's own centre with opacity `0→1` and blur `max→0`, starting at **half of
   the QR's dissolve** and finishing together. No drift, no scale pop: the old
   `easeOutBack` scale was removed. All segments use `Curves.easeInOutCubic`
   (ease in AND out).
5. **Slower.** `SamayDurations.assistReveal` `1600 → 2600 ms`. Interval split:
   QR out `[0.0, 0.7]`, terminal in `[0.35, 1.0]` (0.35 = half of 0.7).
6. New feature-local const `kAssistDissolveBlur` (18) — the single dissolve
   tuneable; kept out of `app_constants.dart` (another session has uncommitted
   edits there).

Flutter-only: no backend/migration change; the `event_attendances` realtime
seam / RLS and `validate_code` are untouched. Reduced motion still jumps
straight to the final state.

## Decisions made and why

- **Pin the QR with the same layout as the live screen.** The live `_ActiveCode`
  centers the QR alone; any terminal layout that puts the QR in a larger
  flex/column shifts it. The `Stack` + independent word overlay is the smallest
  faithful fix.
- **Blur as the inverse, not scale.** The user asked for a pure dissolve
  ("no expanding anymore just dissolving (blur too)") and the entering motion to
  be its inverse; a shared `_BlurOpacity` helper makes out = `1−t` opacity /
  `t` blur and in = `t` opacity / `1−t` blur, so they are literally symmetric.
- **Start at half the QR dissolve.** Per the user's answer, the check/word
  begin at `_qrOutEnd / 2` (0.35), giving a cross-dissolve rather than a
  wait-then-pop.
- **No drift.** Both the QR and the word stay put; only opacity + blur animate.
- **Remove the dead l10n key.** No references remained; keeping it would be dead
  string data.

## MISTAKE blocks

- **MISTAKE — a centered `Column` cannot hold the QR if the terminal text is
  also in it.** Centering QR + word together moves the QR up by half the
  trailing content's height the instant the state flips. Terminal overlays that
  must not disturb an existing element's position need a `Stack`, not a `Column`.
- **MISTAKE — `ImageFilter.blur` at sigma 0 still allocates a save-layer.**
  Guarded in `_BlurOpacity` (`blur > 0.01`) so the final/static frame pays
  nothing.

## Commands run (reproducible)

```bash
export AGENT_NAME=d-assist-dissolve
tools/agent_lock.sh acquire <paths> --owner "$AGENT_NAME"

flutter gen-l10n
dart analyze                                 # No issues found!
make build TARGET=android                    # ✓ Built app-debug.apk
adb -s localhost:5565 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s localhost:5565 shell monkey -p com.qallariy.samay -c android.intent.category.LAUNCHER 1
```

## Issues found / out of scope

- **On-device tap verification still to run (human).** Host/staff scans an open
  QR: the code must dissolve IN PLACE (no jump), blurring out; the check +
  "LISTO"/"DONE" condense in at the same centre starting halfway; no Regresar
  button; back arrow exits. Re-open already-assisted → terminal directly, no
  replay. OS reduced-motion → terminal directly.
- Pre-existing doc drift found while checking: the previous log
  `2026-09-10_realtime-assist-animation.md` names `AppColors.success` /
  `easeInCubic` / `easeOutBack`; the committed code already used white and
  `easeInOut*` before this rework. Left as the historical record.
- The uncommitted working-tree `Makefile` comment says pgTAP "956 assertions"
  while `schema_test.sql` / `README.md` are `plan(960)` — another session's
  in-flight work; not touched.
