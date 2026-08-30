/// Reusable play engine for the five minigame types (150_minigame_play).
///
/// The DB owns randomness (server-random subject/prompt draws) and the prompt
/// bank; this pure-Dart layer owns the game-agnostic turn skeleton parsing,
/// the round-robin judge rotation and the completed-round records — the
/// shared shape every game (poke_chain, questions, truth_dare, drunk_bottle,
/// challenge) builds its rounds on.
///
/// A game state row from `get_minigame_game_state` / `init_*` / `advance_*`
/// / `reveal_*` is an object like:
///
/// ```json
/// {
///   "session_id": "...", "game_type": "truth_dare",
///   "state": {
///     "judge_index": 0, "round": 0, "phase": "playing",
///     "subject_id": "...", "prompt_type": "verdad", "prompt": {...}
///   },
///   "rounds": [...], "created_at": "...", "updated_at": "..."
/// }
/// ```
///
/// The turn skeleton is NESTED under the outer `state` key — [GameTurnSkeleton]
/// parses it, [MinigameGameState] parses the whole row.
library;

import 'dart:math';

import 'package:samay/l10n/app_localizations.dart';

/// Lifecycle phase of a minigame session's play engine.
enum MinigamePhase {
  /// The session exists but no game-state row is initialized yet.
  setup,

  /// The host tapped Start; the 5s pre-play countdown is running. Every
  /// participant sees the same countdown and the server flips to [playing]
  /// once `countdown_ends_at` passes (or back to [setup] if the host
  /// cancels). 190_minigame_countdown.
  countdown,

  /// Rounds are being played (a subject + prompt are current).
  playing,

  /// The game ended (`complete_minigame_game` flipped the phase).
  finished,
}

/// Parses a `state.phase` string into [MinigamePhase] (tolerant: unknown /
/// missing values fall back to [MinigamePhase.setup]).
MinigamePhase minigamePhaseFromString(String? value) {
  return switch (value) {
    'playing' => MinigamePhase.playing,
    'finished' => MinigamePhase.finished,
    'countdown' => MinigamePhase.countdown,
    _ => MinigamePhase.setup,
  };
}

/// How a completed round resolved — the only two outcomes a party game needs.
enum PromptOutcome {
  /// The subject did it (truth answered / dare completed) — the round closes
  /// and the turn advances.
  done,

  /// The subject skipped — the round still closes and the turn advances.
  skip,
}

/// The game-agnostic turn skeleton, parsed from the nested `state` jsonb.
///
/// `judgeIndex` is the rotation pointer (advances round-robin server-side);
/// `subjectId` is the CURRENT player the turn belongs to (server-random);
/// `nextSubjectId` is the server-authoritative "who's next" (190); `promptType`
/// + `prompt` hold the revealed prompt for the current turn. During the
/// pre-play countdown, `countdownEndsAt` is the server-set deadline that the
/// lobby's countdown overlay animates towards.
class GameTurnSkeleton {
  const GameTurnSkeleton({
    this.judgeIndex = 0,
    this.round = 0,
    this.phase = MinigamePhase.setup,
    this.subjectId,
    this.nextSubjectId,
    this.countdownEndsAt,
    this.promptType,
    this.prompt,
  });

  final int judgeIndex;
  final int round;
  final MinigamePhase phase;
  final String? subjectId;

  /// The server-drawn player whose turn comes after the current one
  /// (authoritative — the "Siguiente: {name}" indicator).
  final String? nextSubjectId;

  /// The countdown deadline (`state.countdown_ends_at`, ISO 8601) the lobby
  /// overlay counts down to; null outside the countdown phase.
  final DateTime? countdownEndsAt;

  final String? promptType;
  final Map<String, dynamic>? prompt;

  /// Whether the phase is [MinigamePhase.finished].
  bool get isFinished => phase == MinigamePhase.finished;

  /// Whether the pre-play countdown is running.
  bool get isCountdown => phase == MinigamePhase.countdown;

  /// Whether a prompt has been revealed for the current turn.
  bool get hasPrompt => prompt != null;

  /// Tolerant parse of the nested `state` object (missing keys → defaults).
  factory GameTurnSkeleton.fromJson(Map<String, dynamic> json) {
    return GameTurnSkeleton(
      judgeIndex: _asInt(json['judge_index']),
      round: _asInt(json['round']),
      phase: minigamePhaseFromString(json['phase'] as String?),
      subjectId: json['subject_id'] as String?,
      nextSubjectId: json['next_subject_id'] as String?,
      countdownEndsAt: DateTime.tryParse(json['countdown_ends_at'] as String? ?? ''),
      promptType: json['prompt_type'] as String?,
      prompt: json['prompt'] is Map
          ? Map<String, dynamic>.from(json['prompt'] as Map)
          : null,
    );
  }

  /// Coerces a json value (int, double or numeric string) into an int,
  /// defaulting to 0 when absent / unparseable.
  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// A completed round — the record appended to `minigame_game_state.rounds`
/// and passed to `advance_minigame_turn` as `p_round`.
class GameRoundRecord {
  GameRoundRecord({
    required this.subjectId,
    required this.outcome,
    this.promptType,
    this.promptId,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String subjectId;
  final PromptOutcome outcome;
  final String? promptType;
  final String? promptId;
  final DateTime at;

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'prompt_type': promptType,
      'prompt_id': promptId,
      'outcome': outcome == PromptOutcome.done ? 'done' : 'skip',
      'at': at.toIso8601String(),
    };
  }

  factory GameRoundRecord.fromJson(Map<String, dynamic> json) {
    return GameRoundRecord(
      subjectId: json['subject_id'] as String,
      promptType: json['prompt_type'] as String?,
      promptId: json['prompt_id'] as String?,
      outcome: json['outcome'] == 'done' ? PromptOutcome.done : PromptOutcome.skip,
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// The full `minigame_game_state` row — the outer object returned by the
/// play-engine RPCs, with the turn skeleton nested under `state`.
class MinigameGameState {
  const MinigameGameState({
    required this.sessionId,
    required this.gameType,
    required this.skeleton,
    required this.rounds,
    required this.ready,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sessionId;
  final String gameType;
  final GameTurnSkeleton skeleton;
  final List<GameRoundRecord> rounds;

  /// The partida lobby's authoritative ready map — `{participant_id: bool}`
  /// (180_minigame_lobby). Written ONLY through `set_minigame_ready` and
  /// streamed live via the `minigame_game_state` realtime subscription, so a
  /// participant's Ready toggle lands here instantly for the whole lobby.
  final Map<String, bool> ready;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFinished => skeleton.isFinished;

  bool get hasPrompt => skeleton.hasPrompt;

  /// Whether [participantId] has toggled Ready (absent → not ready).
  bool isReady(String participantId) => ready[participantId] ?? false;

  /// Parses a play-engine row. The turn skeleton is read from the nested
  /// `state.state` object (tolerant: any missing piece falls back to a
  /// default skeleton); the `ready` map tolerates absence (`{}`).
  factory MinigameGameState.fromRow(Map<String, dynamic> row) {
    final nested = row['state'] is Map
        ? Map<String, dynamic>.from(row['state'] as Map)
        : <String, dynamic>{};
    final rawRounds = row['rounds'];
    final rawReady = row['ready'];
    return MinigameGameState(
      sessionId: row['session_id'] as String? ?? '',
      gameType: row['game_type'] as String? ?? '',
      skeleton: GameTurnSkeleton.fromJson(nested),
      rounds: rawRounds is List
          ? [
              for (final r in rawRounds)
                if (r is Map) GameRoundRecord.fromJson(Map<String, dynamic>.from(r)),
            ]
          : const [],
      ready: rawReady is Map
          ? {
              for (final e in rawReady.entries)
                if (e.value is bool) e.key.toString(): e.value as bool,
            }
          : const {},
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// The round-robin judge rotation: the next judge is `(current + 1) % count`.
/// Throws [ArgumentError] for a non-positive [participantCount] — a rotation
/// over zero players is meaningless.
int nextJudgeIndex({required int currentIndex, required int participantCount}) {
  if (participantCount <= 0) {
    throw ArgumentError.value(
      participantCount,
      'participantCount',
      'must be > 0',
    );
  }
  return (currentIndex + 1) % participantCount;
}

/// A random participant index in `[0, participantCount)` using [rng] — the
/// client-side mirror of the server's random subject draw (used for previews;
/// the server never trusts it). Throws [ArgumentError] for a non-positive
/// [participantCount].
int randomParticipantIndex({
  required int participantCount,
  required Random rng,
}) {
  if (participantCount <= 0) {
    throw ArgumentError.value(
      participantCount,
      'participantCount',
      'must be > 0',
    );
  }
  return rng.nextInt(participantCount);
}

/// Localized label for a subject — "Turno de {name}" (2026-08-30 directive:
/// the play screen never shows a raw UUID). The caller resolves the name (the
/// engine does not know users); a null name falls back to the generic
/// "Turno de un jugador" line.
String minigameSubjectLabel(AppLocalizations l10n, String? subjectName) {
  if (subjectName == null || subjectName.isEmpty) {
    return l10n.minigamesTurnGeneric;
  }
  return l10n.minigamesTurnFor(subjectName);
}
