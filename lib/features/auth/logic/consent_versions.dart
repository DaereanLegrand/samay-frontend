/// Versions of the two documents a player accepts at onboarding.
///
/// Kept in code (not the DB) because the acceptance itself is what the server
/// stores (`users.terms_version`): bumping a version here is how a future
/// re-consent flow detects that a player accepted an older revision.
abstract final class ConsentVersions {
  /// Age confirmation is versionless — it is a statement of fact ("I am 18 or
  /// older"), not a document.
  static const String terms = '2026-11';
  static const String privacy = '2026-11';
}
