# 2026-08-27 — Token-budget: focused test loop + restyle-test deletion

## What was built

Per user directive (2026-08-27): "the agent + harness does much more work
doing test repairing after a modification rather than coding ending in high
token usage." Fix the feedback loop and kill the highest-churn test layer.

1. **Focused test loop is now the default.** New Makefile targets:
   `make test-file FILE=<path>`, `make test-files FILES="a b"`,
   `make test-feature FEATURE=<name>` — each runs ONLY the touched tests.
   The full `make check` + `make test` gate is explicitly gated on a human
   request. `make flutter-test` honors `FLUTTER_CONCURRENCY`.
2. **Deleted the five visual-pinning `restyle_test.dart` files** (~3.8k
   lines): `test/features/{auth,feed,friends,groups,profile}/restyle_test.dart`.
   They asserted `BoxDecoration.shape`, exact color-token equality and exact
   `fontSize` on widget internals — every token/spacing tweak broke several,
   forcing an agent repair loop.
3. **Replacement:** a compact `test/design_tokens/render_smoke_test.dart`
   (8 tests) proves the canonical shared widgets (`VCard`, `VButton`,
   `VBadge`, `VChip`, `VDisplayText`, `VStatusDot`) build through
   `SamayTheme.dark` without throwing. Token VALUES stay pinned once in
   `test/design_tokens/` + `test/theme/app_theme_test.dart` + each widget's
   own behavioral test in `test/widgets/`.
4. **Guard:** `test/meta/conventions_test.dart` gains a "visual-pinning
   guard" group — bans `decoration.shape` assertions and
   `fontSize`-vs-token equality outside the canonical owners, and fails if
   any `*_restyle_test.dart` is recreated.
5. **Process docs updated:** `AGENTS.md` §TDD Rules (test-layer budget max
   2–3 layers, no restyle layer, iteration loop directive),
   `docs/process/DEVELOPMENT-WORKFLOW.md` §1.3/§1.6/§8 (focused loop
   default, full gate on explicit request), `.opencode/agents/samay.md` +
   `.opencode/agents/reviewer.md` (same directives baked into agent
   prompts), `.opencode/README.md`, `README.md` §Testing summary,
   `docs/specs/steps/cross-references.md` test-policy note.

## Decisions

- **Delete, don't rewrite.** The restyle tests duplicated coverage that
  already lives in `test/design_tokens/`, `test/theme/app_theme_test.dart`
  and `test/widgets/*` (VStatusDot pins the 8px `statusOnline` dot, etc.).
  Keeping a "collapsed" per-feature smoke would re-pin at higher churn cost.
- **Guard scoped narrowly.** A broad "no `tester.widget<...>`" rule was
  rejected after it false-positived on 30+ legitimate behavior tests
  (chat bubble colors, text-field controllers, OTP counter text). Final
  guard only targets the two genuinely churn-prone patterns: `decoration
  .shape` and `fontSize`-vs-token equality.
- **Canonical owners are exempt from the guard** so token pins can't be
  deleted: `test/design_tokens/`, `test/theme/`, `test/widgets/`,
  `test/perf/list_view_builder_test.dart` (pre-existing `itemExtent` pin),
  plus the `lib/core/design_tokens` + `lib/core/theme` sources.

## MISTAKE

- The first guard iteration matched `tester.widget<TextButton>(...)` —
  a legitimate Flutter idiom used by dozens of behavior tests — and
  "failed" the entire `test/features/` tree. Fix: enumerate the exact
  pinning patterns (shape + fontSize-vs-token) instead of the reading idiom.
- `git rm` on the restyle files failed because they had uncommitted local
  modifications from the prior restyle session (526/354 changed lines). The
  user explicitly directed full deletion, so `git rm -f` was used — the
  prior session's edits to those files are superseded by this directive.

## Commands run

```bash
git rm -f test/features/{auth,feed,friends,groups,profile}/restyle_test.dart
flutter test test/design_tokens/render_smoke_test.dart   # 8 pass
flutter test test/meta/conventions_test.dart             # 32 pass
make test-file FILE=test/design_tokens/render_smoke_test.dart
make test-feature FEATURE=friends                        # 34 pass
dart analyze                                            # clean
```
