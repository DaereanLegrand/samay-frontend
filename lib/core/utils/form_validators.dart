/// Shared form-validation primitives.
///
/// One validation pattern for every form in the app: field validators return
/// a user-facing message or `null` (valid), [compose] chains several into a
/// first-failure-wins pipeline, and [FormState] groups per-field errors for a
/// whole form. Pure Dart, no BuildContext, no Flutter imports.
///
/// Validators are strict on purpose: they validate what they receive. Callers
/// sanitize first (`InputSanitizer`) and decide whether to trim; the only
/// trimming built in is [requiredValidator]'s presence check (a
/// whitespace-only field is empty). Error messages stay Spanish literals by
/// default (BuildContext-free constants, same rationale as the error classes
/// in `lib/core/errors/**`); screens pass their localized ARB string when they
/// render the error.
///
/// NOTE: [FormState] shadows Flutter's `FormState` (widgets). Files that also
/// import `package:flutter/material.dart` should import this library with a
/// prefix: `import '.../form_validators.dart' as form_validators;`
library;

/// Default message when no custom [message] is passed to [requiredValidator].
const String formRequiredMessage = 'Este campo es obligatorio.';

/// Default message when no custom [message] is passed to [emailValidator].
const String formEmailMessage = 'Ingresa un correo electrónico válido.';

/// Default message when no custom [message] is passed to [lengthValidator].
const String formLengthMessage = 'Longitud inválida.';

/// Default message when no custom [message] is passed to [numericValidator].
const String formNumericMessage = 'Ingresa un valor numérico válido.';

/// Presence check: `null`, empty or whitespace-only input fails.
///
/// [message] defaults to [formRequiredMessage].
String? requiredValidator(String? v, {String? message}) {
  if (v == null || v.trim().isEmpty) return message ?? formRequiredMessage;
  return null;
}

/// Basic email shape check: the WHATWG/HTML5 `type=email` pattern
/// (<https://html.spec.whatwg.org/multipage/input.html#valid-e-mail-address>)
/// — the sane middle ground between "contains an @" and a full RFC 5322
/// parser. Accepts dot-separated domain labels and the printable-ASCII
/// local-part set; rejects whitespace, empty labels and leading `-`.
///
/// The value is NOT trimmed: callers pass what they mean to validate.
/// [message] defaults to [formEmailMessage].
String? emailValidator(String? v, {String? message}) {
  final email = RegExp(
    r'''^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+'''
    r'@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );
  if (v == null || !email.hasMatch(v)) return message ?? formEmailMessage;
  return null;
}

/// Length range check on the raw string (no implicit trimming — callers
/// sanitize/trim first): fails when `v.length` (`0` for `null`) is below
/// [min] or above [max]. `min: 0` accepts `null`/empty — the optional-field
/// shape. [message] defaults to [formLengthMessage].
String? lengthValidator(
  String? v, {
  required int min,
  int? max,
  String? message,
}) {
  final length = v?.length ?? 0;
  if (length < min || (max != null && length > max)) {
    return message ?? formLengthMessage;
  }
  return null;
}

/// Integer-field check: `null`/empty/non-`int.tryParse`-able input fails, and
/// so does any value outside the optional [min]..[max] bounds (inclusive).
/// [message] defaults to [formNumericMessage].
String? numericValidator(String? v, {int? min, int? max, String? message}) {
  final value = int.tryParse(v ?? '');
  if (value == null ||
      (min != null && value < min) ||
      (max != null && value > max)) {
    return message ?? formNumericMessage;
  }
  return null;
}

/// Chains [validators] in order; the first non-`null` message wins (null
/// entries in the list are skipped). With no effective validator the returned
/// function always passes (`null`). The result is a plain function, so it can
/// be stored, reused and handed to [FormState.validate] like any validator.
String? Function(String?) compose(List<String? Function(String?)?> validators) {
  final active = validators.whereType<String? Function(String?)>();
  return (v) {
    for (final validator in active) {
      final error = validator(v);
      if (error != null) return error;
    }
    return null;
  };
}

/// Per-field error holder for a form (the form-state helper of the shared
/// pattern). Pure Dart, no Flutter imports. Call [validate] with the field
/// rules and values, then read [errors] (per-field) or [isValid] (aggregate).
class FormState {
  /// The latest validation result: field key → error message (`null` =
  /// valid). Rebuilt on every [validate] call.
  final Map<String, String?> errors = {};

  /// Runs every [rules] validator against its [values] entry and stores the
  /// result in [errors] (previous results are discarded).
  void validate(
    Map<String, String? Function(String?)> rules,
    Map<String, String?> values,
  ) {
    errors.clear();
    for (final entry in rules.entries) {
      errors[entry.key] = entry.value(values[entry.key]);
    }
  }

  /// True when no field currently carries an error message (an untouched
  /// form with no rules is valid).
  bool get isValid => errors.values.every((e) => e == null);
}
