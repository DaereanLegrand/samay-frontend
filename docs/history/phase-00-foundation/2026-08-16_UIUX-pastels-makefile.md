# UI/UX Pass — Pastel Token Re-Saturation + Simulator Picker (2026-08-16)

**Agent:** human (code) + UIUX-docs-audit (docs) · **Branch:** `fixes` · **HEAD:** `c8bba7e` (uncommitted changes)

## What was built

### 1. Pastel tokens re-saturated (`lib/core/design_tokens/app_colors.dart`)

The six LUXE pastel light ends were moved off the near-white pastels toward their
mid stops — the UI/UX requirement was that the pastels read as *color* on the
black glass surfaces (glows, gradient fills, group-chat sender names), not as
washed-out near-white. All six remain **AAA vs black**:

| Token | Old | New | Old ratio | New ratio |
|---|---|---|---|---|
| `pastelRose` | `#FFD6E8` | `#FF8CBE` | 16.04:1 | 9.75:1 |
| `pastelViolet` | `#E3D9FF` | `#BFA5FA` | 15.64:1 | 9.98:1 |
| `pastelCyan` | `#D6F7FF` | `#73F1FF` | 18.61:1 | 15.75:1 |
| `pastelGold` | `#FFF3D6` | `#FFE19D` | 19.04:1 | 16.51:1 |
| `pastelMint` | `#D8FFEE` | `#91F1CD` | 19.46:1 | 15.66:1 |
| `pastelPeach` | `#FFE6D9` | `#FFCCBB` | 14.60:1 | 14.60:1 |

- Gradient families re-stopped by construction: the light end IS the pastel token,
  so `AppGradients.{rose,violet,cyan,gold,mint,peach}` light stops changed with it
  (mid/vivid stops untouched).
- Tests updated in lock-step: `test/design_tokens/app_colors_test.dart`
  (exact-hex map, exact-hex group, ratio group with 0.02 tolerance) +
  `test/design_tokens/app_gradients_test.dart` (doc-table verbatim stops).
- Consumers are tint/glow roles (group sender names, auroras, watered fills), so
  no layout/contrast regression — ratios verified by the existing ratio tests.

### 2. Makefile simulator multi-device picker (`Makefile`)

`dev`, `install`, and `uninstall` with `TARGET=simulator` previously used
`head -1` on the booted list — with two booted simulators the wrong device was
picked silently. Now:

- Single booted simulator → used directly (no change in behavior).
- Multiple booted simulators → `gum choose` interactive picker
  (`echo "$DEVS" | gum choose --header "Pick a simulator:"`), result staged in
  `/tmp/_sim_pick`.
- Zero booted → first available iPhone booted as before.
- `uninstall TARGET=simulator` restructured: the simulator is picked BEFORE the
  `get_app_container` check, so the not-installed message refers to the device
  the user actually meant (previously the check ran against `head -1`).

New runtime dependency: **`gum`** (charmbracelet) for the multi-simulator path
only — already a dev-machine staple via `test_runner.sh`/`make help`.

## Decisions

- Keep the saturated pastels AAA vs black — the tokens are decorative
  gradient/glow/sender-name materials, never body-text roles (DISCO-LUXE §2.1
  contract unchanged).
- Ratio tests updated with the same 0.02 tolerance; every ratio re-verified by
  the test suite (no manual constants).
- `/tmp/_sim_pick` is a scratch file (gitignored path); the pipefail edge (gum
  cancelled → empty pick) falls through to the same failure the old `head -1`
  flow had — acceptable for a dev-only target.
- Changes stay **uncommitted** (orchestrator/commit policy — user decision).

## MISTAKE

- The `tools/agent_lock.sh run <path> --owner … -- <cmd>` one-shot did not
  execute its command body (`sed` edit never ran) — the lock was acquired but
  the edit was silently skipped. Recovered by re-reading the file, applying the
  edit with the edit tool, and releasing the lock manually. Lesson: never trust
  `run` without verifying the file changed; check `agent_lock.sh list` before
  moving on.

## Commands (reproducibility)

```bash
flutter test                                   # 2440/2440 after cleanup (see R-5 log)
dart analyze                                   # 0 issues
go test ./...                                  # 182 pass
tools/check_ports.sh --strict                  # STRICT PASS (Makefile ports untouched)
```

Docs updated in the same pass: `DISCO-LUXE-DESIGN-SYSTEM.md` §2.1 (both tables +
§2.4 chat-bubble note + §4.1 group-hero row + §10 changelog), the three XL-09/10/11
hex references, `DISCO-DESIGN-SYSTEM.md` §4.2 chat-bubble departure note.
