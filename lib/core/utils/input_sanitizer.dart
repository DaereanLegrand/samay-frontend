import 'package:characters/characters.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Centralized input sanitization (finding SEC-06 / H-24).
///
/// Every write boundary in the app funnels user-supplied strings through this
/// class before they reach Supabase: username (profile setup + auth service),
/// bio (edit profile), group name/description (create group + group service),
/// invite/friend search queries, donate amounts and chat message content.
///
/// Guarantees, applied in order:
///
/// 1. **Optional NFKC normalization** ([normalizeNfkc]) — canonical +
///    compatibility decomposition/recomposition (Unicode TR-15). Prevents
///    canonical-equivalence duplicates (e.g. `e` + combining acute vs `é`)
///    and compatibility lookalikes (e.g. full-width `Ａ` vs `A`, circled
///    `①` vs `1`). Defaults to off for free text because NFKC can visibly
///    rewrite characters users intentionally typed; use it for identifiers
///    ([sanitizeUsername] always normalizes).
/// 2. **Control/format character stripping** — removes the Unicode `Cc`
///    (control: C0/C1, DEL) and `Cf` (format: zero-width space, ZWJ, bidi
///    overrides U+202A-U+202E, soft hyphen) categories. This is what keeps
///    control characters out of JSON payloads and kills bidi spoofing.
/// 3. **Trim** — leading/trailing whitespace.
/// 4. **Length cap** — by *grapheme cluster* (via `package:characters`), not
///    UTF-16 code units, so emoji are never split into broken surrogates.
///
/// Sanitization is idempotent: sanitizing an already-sanitized string is a
/// no-op, which makes defense-in-depth cheap (screens and services can both
/// sanitize without double-processing).
///
/// NFKC implementation note: Dart's core library has no Unicode normalization
/// (no `String.normalize()`); `unorm_dart` (a Dart port of `walling/unorm`,
/// Unicode 17.0 tables, verified publisher, MIT) is the maintained option.
///
/// Cap note: these are *client-side* caps. The DB schema has no length
/// CHECK constraints yet — server-side caps are tracked separately (see
/// `docs/security/SECURITY.md` §2.6). Screens should also set
/// `TextField.maxLength` so users get UX feedback, not silent truncation.
class InputSanitizer {
  InputSanitizer._();

  /// Unicode control (Cc) + format (Cf) categories.
  static final RegExp _controlChars = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);

  /// Whitespace (including non-breaking) and the `@` handle marker.
  static final RegExp _usernameInvalid = RegExp(r'[\s@]');

  /// Anything that is not an ASCII digit.
  static final RegExp _nonDigits = RegExp('[^0-9]');

  // Client-side field caps (grapheme count). Chosen to be generous for the
  // MVP while keeping UI rendering and DB storage bounded; revisit when the
  // server-side CHECK constraints land.
  static const int usernameMaxLength = 20;
  static const int bioMaxLength = 160;
  static const int groupNameMaxLength = 50;
  static const int groupDescriptionMaxLength = 250;
  static const int messageMaxLength = 500;
  static const int searchQueryMaxLength = 50;
  static const int amountMaxDigits = 9;

  /// Trims [input], strips Unicode control/format characters, optionally
  /// NFKC-normalizes, and caps the result to [maxLength] graphemes.
  ///
  /// [normalizeNfkc] defaults to `false`: for free text (bio, group
  /// description, messages) visible character rewrites are undesirable; pass
  /// `true` for identifiers and search keys. Valid input passes through
  /// unchanged.
  static String sanitize(
    String input, {
    int? maxLength,
    bool normalizeNfkc = false,
  }) {
    if (input.isEmpty) return input;
    var result = input;
    if (normalizeNfkc) {
      result = unorm.nfkc(result);
    }
    result = result.replaceAll(_controlChars, '');
    result = result.trim();
    if (maxLength != null && maxLength > 0) {
      result = result.characters.take(maxLength).toString();
    }
    return result;
  }

  /// Like [sanitize], but returns `null` when the result is empty — the
  /// natural shape for optional fields such as group descriptions.
  static String? sanitizeOptional(
    String? input, {
    int? maxLength,
    bool normalizeNfkc = false,
  }) {
    if (input == null) return null;
    final cleaned = sanitize(
      input,
      maxLength: maxLength,
      normalizeNfkc: normalizeNfkc,
    );
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Sanitizes a username handle: trims, strips control characters, removes
  /// all whitespace and `@` markers (handles are shown as `@username`), and
  /// always NFKC-normalizes so canonically-equivalent and compatibility
  /// lookalike inputs cannot register as distinct accounts. Case is
  /// preserved — usernames are case-sensitive display identifiers.
  static String sanitizeUsername(String input) {
    var result = sanitize(
      input,
      maxLength: usernameMaxLength,
      normalizeNfkc: true,
    );
    result = result.replaceAll(_usernameInvalid, '');
    return result;
  }

  /// Reduces an amount field to ASCII digits only (up to [amountMaxDigits]).
  /// `sanitizeAmount('1.5')` → `'15'` — callers parse the result with
  /// `int.tryParse`, so separators never reach the integer parser.
  static String sanitizeAmount(String input) {
    final digits = input.replaceAll(_nonDigits, '');
    if (digits.length > amountMaxDigits) {
      return digits.substring(0, amountMaxDigits);
    }
    return digits;
  }
}
