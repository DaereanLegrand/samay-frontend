import 'package:characters/characters.dart';
import 'package:samay/shared/constants/auth_constants.dart';

/// Username validation policy for the signup funnel (profile setup).
///
/// Pure Dart, no BuildContext — same contract as `password_policy.dart` /
/// `age_policy.dart`: the messages are Spanish literals by design
/// (es-first app, BuildContext-free error contract like the error classes in
/// `lib/core/errors/**`), mapped verbatim at presentation time.
///
/// The policy validates the SANITIZED value: callers pass the output of
/// `InputSanitizer.sanitizeUsername` (whitespace and `@` markers are stripped
/// silently upstream, so there is deliberately no charset rule here; the
/// length cap is enforced by the sanitizer itself).
///
/// ALL violated rules are returned together as a list — the profile-setup
/// screen renders every message, so a value that breaks several requirements
/// reports them in one pass instead of first-failure-wins.
const String usernameRequiredMessage = 'El nombre de usuario es obligatorio.';
const String usernameMinLengthMessage =
    'Debe tener al menos $usernameMinLength caracteres.';

/// Every user-facing violation of the username requirements for [value]
/// (already sanitized), in stable display order; empty when valid.
List<String> usernamePolicyErrors(String value) {
  final errors = <String>[];
  if (value.isEmpty) {
    errors.add(usernameRequiredMessage);
  }
  if (value.characters.length < usernameMinLength) {
    errors.add(usernameMinLengthMessage);
  }
  return errors;
}
