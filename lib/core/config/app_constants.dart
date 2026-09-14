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

  /// Per-attempt timeout for uploading an encrypted minigame answer image to
  /// the private `minigame_images` bucket. A hung storage request consumes at
  /// most this long before `resilient` retries it.
  static const Duration minigameImageUploadTimeout = Duration(seconds: 20);

  /// Extra attempts for the minigame answer-image upload after the first
  /// failure (transient storage errors only — see `defaultShouldRetry`).
  static const int minigameImageUploadMaxRetries = 3;

  /// Delay before the first minigame answer-image retry; later retries grow by
  /// [minigameImageUploadRetryBackoffFactor] with full jitter.
  static const Duration minigameImageUploadRetryInitialDelay =
      Duration(seconds: 1);

  /// Exponential backoff multiplier between minigame answer-image retries.
  static const double minigameImageUploadRetryBackoffFactor = 2;
}
