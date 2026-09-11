/// Cross-cutting, non-visual application constants.
///
/// Visual tokens live in `lib/core/design_tokens/**`; motion lives in
/// `lib/core/theme/samay_durations.dart`. This file is for numeric/timeout
/// knobs that are neither: a single named home so a tunable is never a bare
/// literal buried in a widget or service.
abstract final class AppConstants {
  /// How long the finished-match leaderboard waits for the decrypted
  /// per-answer content (`minigame_answers` + the private image blobs, joined
  /// to their prompts) before giving up and offering a discreet retry in place
  /// of the answer area. 5s per the user directive (2026-09-11).
  static const Duration leaderboardAnswersTimeout = Duration(seconds: 5);
}
