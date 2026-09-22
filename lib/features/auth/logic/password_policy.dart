/// Pure password-strength policy extracted from
/// `signup_contact_screen.dart`.
///
/// The failure message stays a Spanish literal by design: it is a
/// `BuildContext`-free error contract, same rationale as the error classes in
/// `lib/core/errors/**` — the app is es-first and the message is mapped
/// verbatim at presentation time.
const _weakPasswordMessage =
    'La contraseña debe tener al menos 8 caracteres y contener un número.';

/// A password is valid when it has at least 8 characters and at least one
/// digit (NIST SP 800-63B §5.1.1 recommended minimum — server-side
/// `GOTRUE_PASSWORD_MIN_LENGTH: 8` matches this rule).
bool isPasswordValid(String password) {
  if (password.length < 8) return false;
  if (!password.contains(RegExp(r'[0-9]'))) return false;
  return true;
}

/// Returns the user-facing validation message for an invalid password, or
/// `null` when [isPasswordValid] accepts it.
String? passwordError(String password) {
  if (isPasswordValid(password)) return null;
  return _weakPasswordMessage;
}
