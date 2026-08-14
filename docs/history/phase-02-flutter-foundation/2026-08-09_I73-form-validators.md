# 2026-08-09/10 — I-73: Form validation utilities

**Agent:** I-73-form-validators
**Status:** DONE
**Scope:** `lib/core/utils/form_validators.dart` (new generic validation layer) +
migration of the three easy forms (login, donate shards, create group) +
unit/screen tests. TDD (RED → GREEN). Pure Dart, zero new dependencies.
**Evidence:** this log, TODO.md workstream entry, lock list (9 paths).

## What was built

### `lib/core/utils/form_validators.dart` (new, I-73 owned per FILE-OWNERSHIP)

The shared, typed validation layer so every form uses one pattern: field
validators + a form-state helper. Extracted as GENERIC primitives — the
I-46 (password/age policies) and I-54 (`EventFormData.validate()`) extracted
functions are NOT rewritten; they keep their semantics and remain the
specialized rules, while this file provides the reusable building blocks:

| Symbol | Contract |
|---|---|
| `requiredValidator(String?, {String? message})` | trim-empty presence check (`null`/`''`/whitespace → error) |
| `emailValidator(String?, {String? message})` | WHATWG/HTML5 `type=email` pattern (see Decisions) |
| `lengthValidator(String?, {required int min, int? max, String? message})` | raw-length bounds; `min: 0` = optional-field shape; no implicit trim |
| `numericValidator(String?, {int? min, int? max, String? message})` | `int.tryParse` + optional inclusive bounds |
| `compose(List<String? Function(String?)?>)` | first-failure-wins pipeline; null entries skipped; returns a reusable function |
| `class FormState` | `Map<String, String?> errors` + `validate(rules, values)` + `bool get isValid`; pure Dart |

Default messages are Spanish literals (`formRequiredMessage`, `formEmailMessage`,
`formLengthMessage`, `formNumericMessage`) — BuildContext-free constants, the
same rationale as `lib/core/errors/**` and `password_policy.dart` (I-46), and
OUTSIDE the l10n extraction guard's scan scope (`lib/features/**`,
`lib/shared/widgets/**`, `app_router.dart` — verified in
`test/l10n/l10n_extraction_test.dart`). Screens that render an error pass
their ARB string as `message` (donate does this).

## Migrated screens (behavior identical — zero visual diff)

- **`login_screen.dart`** — the implicit `if (email.isEmpty || password.isEmpty) return;`
  became a `FormState` validation over `requiredValidator` for both fields.
  Import is prefixed (`as form_validators`) because `FormState` shadows
  Flutter's widgets `FormState`. Guard semantics identical; the errors map is
  ready for per-field display once `VInput` gains `errorText` (U-05 scope).
- **`donate_shards_screen.dart`** — the inline
  `int.tryParse(sanitizeAmount(...)) == null || < 1` check became
  `numericValidator(sanitized, min: 1, message: l10n.groupsInvalidAmount)`.
  Same sanitize step, same parse semantics, same snackbar string
  (`l10n.groupsInvalidAmount`), same early return. `int.parse` after
  validation is safe by construction.
- **`create_group_screen.dart`** — the inline `if (name.isEmpty) return;`
  (post-`InputSanitizer.sanitize`) became
  `if (requiredValidator(name) != null) return;`. Name is already trimmed by
  the sanitizer, so trim-empty is byte-identical to `isEmpty` here.

## Decisions made and why

1. **Email regex = WHATWG/HTML5 `type=email` pattern** (source:
   <https://html.spec.whatwg.org/multipage/input.html#valid-e-mail-address>,
   also https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/email
   "basic validation"). It is the industry-standard "sane" client-side
   pattern: accepts dot-separated domain labels and the printable-ASCII
   local-part set, rejects whitespace/empty labels/leading `-`, avoids a full
   RFC 5322 parser (over-engineering) and "contains an @" (too lax).
   **No implicit trimming** — callers pass what they mean to validate.
2. **`compose` returns a non-nullable function** even for an empty/null-only
   list (it always passes) — the mission sketch's `?` on the return type
   would force every call site to null-check; a no-op pipeline is still a
   valid function. Null *entries* are skipped (`whereType`).
3. **Validators don't trim** (except requiredValidator's presence check): the
   repo already funnels strings through `InputSanitizer` at every write
   boundary, so trimming in validators would double-process and hide caller
   bugs. Documented in the library header.
4. **Behavior delta (deliberate, spec-driven):** a whitespace-only password on
   the login screen is now blocked locally (trim-empty requiredValidator)
   instead of being sent to the server (old raw-`isEmpty` guard passed it).
   This is the mission's mandated trim-empty semantics; no existing test
   covered the old edge; pinned by a new widget test. Everything else is
   byte-identical.
5. **`FormState` kept out of the other two screens on purpose:** donate and
   create-group are single-field guards with no per-field error display;
   adding the state holder there would be ceremony without behavior. Login
   (2 fields) demonstrates the pattern end-to-end; signup/create-event
   (multi-field, visible errors) are the natural future adopters — NOT
   migrated now to avoid touching I-46/I-54 behavior.
6. **Message defaults are public constants** so tests pin them and callers
   can reference them without re-typing literals.

## Files modified (lock evidence)

| File | Lock |
|------|------|
| `lib/core/utils/form_validators.dart` (new) | ACQUIRED by I-73-form-validators |
| `lib/features/auth/login_screen.dart` | ACQUIRED by I-73-form-validators |
| `lib/features/groups/donate_shards_screen.dart` | ACQUIRED by I-73-form-validators |
| `lib/features/groups/create_group_screen.dart` | ACQUIRED by I-73-form-validators |
| `test/utils/form_validators_test.dart` (new) | ACQUIRED by I-73-form-validators |
| `test/features/auth/auth_interactions_test.dart` | ACQUIRED by I-73-form-validators |
| `test/features/groups_screens_test.dart` | ACQUIRED by I-73-form-validators |
| `docs/to-fix/TODO.md` | ACQUIRED by I-73-form-validators |
| this log | ACQUIRED by I-73-form-validators |

All locks released after edits (see `tools/agent_lock.sh list`).

## Tests

- **`test/utils/form_validators_test.dart` (new, 27 tests):** every validator
  (pass/fail/edge: null/empty/whitespace, min/max inclusivity, default vs
  custom messages), `compose` (first-failure-wins order, null entries skipped,
  empty list always passes, reusability), `FormState`
  (per-field errors, `isValid`, stale-error clearing on re-validate, empty
  rules).
- **`test/features/auth/auth_interactions_test.dart`** (+1): whitespace-only
  password never fires `signIn` (pins decision 4).
- **`test/features/groups_screens_test.dart`** (+2): donate amount `0` and
  `abc` → `groupsInvalidAmount` snackbar, no repository call; create-group
  whitespace-only name → no service call, no limit dialog.

**Final verification (2026-08-10):**
```bash
flutter test test/utils/form_validators_test.dart test/features/auth/ \
  test/features/groups_screens_test.dart test/features/auth_screens_test.dart
# → 113/113 passed

dart analyze
# → 0 errors (2 pre-existing non-errors: I-57 qr_flow_test.dart unused import,
#   user_service.dart curly_braces info — untouched)

flutter test          # full suite → 1607/1607 passed, 0 failed
```

## MISTAKE blocks

- **MISTAKE (test authoring):** the compose first-failure test used
  `lengthValidator(min: 4)` as a tear-off — invalid, `v` is a required
  positional parameter. The correct compose entry for length rules is a
  closure `(x) => lengthValidator(x, min: 4)`. RED caught it at compile time;
  the test now uses the closure.
- **MISTAKE (test data):** the compose fall-through case used `'abc'` as
  "length-valid, email-invalid" input — but `'abc'.length == 3 < 4`, so the
  length rule failed first and the assertion expected the email message.
  Fixed the fixture to `'abcd'` (length-valid, still no `@`). Lesson: build
  fixtures against the validator chain, not against the intent.
- **MISTAKE (Dart semantics, avoided by review):** `int.tryParse` accepts
  surrounding whitespace (`int.tryParse(' 5') == 5`), so `' 5'` was nearly
  pinned as an invalid numeric input — it is valid; the fixture list was
  corrected before running.

## Issues found / notes (out of scope, reported)

- `VInput` (`lib/shared/widgets/v_input.dart`) has no `errorText` support —
  per-field inline errors for the FormState pattern can't render yet; belongs
  to the U-05 disco restyle pass.
- The 23 pre-existing failing tests from the campaign baseline are NOT
  present anymore: full suite is 1607/0 (I-47/I-78 keep it green).
- `dart analyze` non-error findings on `integration_test/qr_flow_test.dart`
  (unused import, I-57's file) and `lib/core/services/user_service.dart`
  (curly braces info) pre-date this agent; left untouched.

## Sources consulted

- WHATWG HTML spec — "valid e-mail address" pattern:
  https://html.spec.whatwg.org/multipage/input.html#valid-e-mail-address
- MDN `<input type="email">` basic validation notes:
  https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/email
