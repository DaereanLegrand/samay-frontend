/// Pure-Dart play engine for a single-device ("pass the phone") match.
///
/// No server session, no accounts, no plugins: one phone hosts every seat and
/// the whole match state lives in memory. Prompt draws come from the on-device
/// [LocalPromptPack] with an injectable [Random], so a seeded match replays
/// identically.
///
/// Turn rules (mirroring the shared engine's rotation):
/// * the judge rotates `0..n-1` and wraps;
/// * the subject is the NEXT seat after the judge (never the judge for n>=2);
/// * a prompt id is never drawn twice in one session;
/// * `done` scores +1, `skip` scores +0, both tallied;
/// * reaching [LocalMatchConfig.rounds] finishes the match.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/local/local_game_rules.dart';
import 'package:samay/features/minigames/local/local_match_config.dart';
import 'package:samay/features/minigames/local/local_player.dart';
import 'package:samay/features/minigames/local/local_prompt_pack.dart';

/// Lifecycle phase of a local match.
enum LocalMatchPhase { setup, countdown, playing, finished }

/// How a local round resolved.
enum LocalRoundOutcome { done, skip }

/// One completed round of a local match.
@immutable
class LocalRoundResult {
  const LocalRoundResult({
    required this.round,
    required this.judgePlayerId,
    required this.subjectPlayerId,
    this.promptId,
    required this.outcome,
    required this.at,
  });

  /// Zero-based round index.
  final int round;
  final String judgePlayerId;
  final String subjectPlayerId;
  final String? promptId;
  final LocalRoundOutcome outcome;
  final DateTime at;

  bool get isDone => outcome == LocalRoundOutcome.done;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalRoundResult &&
        other.round == round &&
        other.judgePlayerId == judgePlayerId &&
        other.subjectPlayerId == subjectPlayerId &&
        other.promptId == promptId &&
        other.outcome == outcome &&
        other.at == at;
  }

  @override
  int get hashCode => Object.hash(
    round,
    judgePlayerId,
    subjectPlayerId,
    promptId,
    outcome,
    at,
  );
}

/// One row of the final standings.
@immutable
class LocalScore {
  const LocalScore({
    required this.player,
    required this.done,
    required this.skip,
    required this.score,
  });

  final LocalPlayer player;
  final int done;
  final int skip;

  /// `done - 0 * skip` — the round score (done = +1, skip = +0).
  final int score;

  String get playerId => player.id;
  String get name => player.name;

  /// Alias of [skip] (the "skipped" spelling used by the summary shape).
  int get skipped => skip;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalScore &&
        other.player == player &&
        other.done == done &&
        other.skip == skip &&
        other.score == score;
  }

  @override
  int get hashCode => Object.hash(player, done, skip, score);

  @override
  String toString() => 'LocalScore(${player.id}, done: $done, skip: $skip)';
}

/// Immutable snapshot of the current turn.
@immutable
class LocalMatchState {
  const LocalMatchState({
    required this.phase,
    required this.round,
    required this.roundTarget,
    required this.judgeIndex,
    required this.subjectPlayerId,
    required this.prompt,
    required this.results,
    required this.participantOrder,
  });

  final LocalMatchPhase phase;

  /// Zero-based current round (equals [roundTarget] once finished).
  final int round;
  final int roundTarget;

  /// Index into [participantOrder] of the current judge.
  final int judgeIndex;
  final String? subjectPlayerId;
  final LocalPrompt? prompt;
  final List<LocalRoundResult> results;

  /// Seat order — the ids of [LocalMatchConfig.players] in their original
  /// order. Seat index is the stable scoreboard tiebreak.
  final List<String> participantOrder;

  bool get isFinished => phase == LocalMatchPhase.finished;
  bool get isPlaying => phase == LocalMatchPhase.playing;

  /// Id of the current judge.
  String? get judgePlayerId =>
      judgeIndex >= 0 && judgeIndex < participantOrder.length
      ? participantOrder[judgeIndex]
      : null;

  LocalMatchState copyWith({
    LocalMatchPhase? phase,
    int? round,
    int? roundTarget,
    int? judgeIndex,
    String? subjectPlayerId,
    LocalPrompt? prompt,
    List<LocalRoundResult>? results,
    List<String>? participantOrder,
  }) {
    return LocalMatchState(
      phase: phase ?? this.phase,
      round: round ?? this.round,
      roundTarget: roundTarget ?? this.roundTarget,
      judgeIndex: judgeIndex ?? this.judgeIndex,
      subjectPlayerId: subjectPlayerId ?? this.subjectPlayerId,
      prompt: prompt ?? this.prompt,
      results: results ?? this.results,
      participantOrder: participantOrder ?? this.participantOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalMatchState &&
        other.phase == phase &&
        other.round == round &&
        other.roundTarget == roundTarget &&
        other.judgeIndex == judgeIndex &&
        other.subjectPlayerId == subjectPlayerId &&
        other.prompt == prompt &&
        listEquals(other.results, results) &&
        listEquals(other.participantOrder, participantOrder);
  }

  @override
  int get hashCode => Object.hash(
    phase,
    round,
    roundTarget,
    judgeIndex,
    subjectPlayerId,
    prompt,
    Object.hashAll(results),
    Object.hashAll(participantOrder),
  );

  @override
  String toString() =>
      'LocalMatchState(${phase.name}, round: $round/$roundTarget, '
      'judge: $judgeIndex, subject: $subjectPlayerId)';
}

/// The mutable controller of one single-device match.
class LocalMatch {
  LocalMatch._(
    this.config,
    this.pack,
    this._seed,
    this._random, {
    required bool seeded,
  }) : _seeded = seeded {
    _state = _initialState();
  }

  /// Starts a match: validates [config], captures the seed and builds the first
  /// turn. A supplied [random] is used for the draws; when [config] carries a
  /// seed the draws are always derived from it (so [restart] replays exactly).
  factory LocalMatch.start(
    LocalMatchConfig config,
    LocalPromptPack pack, {
    Random? random,
  }) {
    config.assertValid();
    final seeded = config.seed != null;
    final seed = config.seed ?? DateTime.now().microsecondsSinceEpoch;
    final rng = seeded ? Random(seed) : (random ?? Random(seed));
    return LocalMatch._(config, pack, seed, rng, seeded: seeded);
  }

  /// The live config. Replaceable so a name can be corrected mid-match
  /// without losing the round/score state (the ids — which the state and the
  /// results reference — never change).
  LocalMatchConfig config;
  final LocalPromptPack pack;
  final int _seed;
  final bool _seeded;
  final Set<String> _usedPromptIds = <String>{};
  Random _random;
  late LocalMatchState _state;

  LocalMatchState get state => _state;

  /// Seat ids in their configured order.
  List<String> get _order => [for (final p in config.players) p.id];

  LocalMatchState _initialState() {
    _usedPromptIds.clear();
    final order = _order;
    const judgeIndex = 0;
    final subjectIndex = (judgeIndex + 1) % order.length;
    return LocalMatchState(
      phase: LocalMatchPhase.playing,
      round: 0,
      roundTarget: config.rounds,
      judgeIndex: judgeIndex,
      subjectPlayerId: order[subjectIndex],
      prompt: _drawPrompt(0),
      results: const [],
      participantOrder: order,
    );
  }

  /// Draws (and consumes) the prompt for [round]; null when the pack is dry.
  LocalPrompt? _drawPrompt(int round) {
    final promptType = config.gameType == MinigameType.truthDare
        ? truthDarePromptTypeForRound(round)
        : null;
    final prompt = pack.pickFor(
      promptType: promptType,
      excludeIds: _usedPromptIds,
      random: _random,
    );
    if (prompt != null) _usedPromptIds.add(prompt.id);
    return prompt;
  }

  /// Renames seat [playerId] to [name] (trimmed, clamped) without touching the
  /// round, the scores or the prompt stream.
  ///
  /// This is what makes a zero-typing start possible: the match begins with
  /// default seat names and the table fixes them on the play screen. Throws
  /// [ArgumentError] for a blank name or an unknown id.
  void renamePlayer(String playerId, String name) {
    if (!_order.contains(playerId)) {
      throw ArgumentError.value(playerId, 'playerId', 'not a seat');
    }
    final players = [
      for (final p in config.players)
        if (p.id == playerId) p.copyWith(name: LocalPlayer.create(name).name) else p,
    ];
    config = LocalMatchConfig(
      gameType: config.gameType,
      players: players,
      rounds: config.rounds,
      packId: config.packId,
      anonymous: config.anonymous,
      seed: config.seed,
    );
  }

  /// setup/countdown -> playing (idempotent; no-op once finished).
  void begin() {
    if (_state.phase == LocalMatchPhase.finished) return;
    if (_state.phase != LocalMatchPhase.playing) {
      _state = _state.copyWith(phase: LocalMatchPhase.playing);
    }
  }

  /// Records the current round as [LocalRoundOutcome.done] and advances.
  void markDone() => _recordAndAdvance(LocalRoundOutcome.done);

  /// Records the current round as [LocalRoundOutcome.skip] and advances.
  void markSkip() => _recordAndAdvance(LocalRoundOutcome.skip);

  /// Closes the current round with no explicit outcome — the subject never
  /// answered, which counts as a skip — and rotates. No-op once finished.
  void advance() => _recordAndAdvance(LocalRoundOutcome.skip);

  void _recordAndAdvance(LocalRoundOutcome outcome) {
    if (_state.phase != LocalMatchPhase.playing) return;
    final subjectId = _state.subjectPlayerId;
    if (subjectId == null) return;

    final result = LocalRoundResult(
      round: _state.round,
      judgePlayerId: _order[_state.judgeIndex],
      subjectPlayerId: subjectId,
      promptId: _state.prompt?.id,
      outcome: outcome,
      at: DateTime.now(),
    );
    final results = [..._state.results, result];
    final nextRound = _state.round + 1;

    if (nextRound >= config.rounds) {
      _state = LocalMatchState(
        phase: LocalMatchPhase.finished,
        round: config.rounds,
        roundTarget: config.rounds,
        judgeIndex: _state.judgeIndex,
        subjectPlayerId: null,
        prompt: null,
        results: results,
        participantOrder: _order,
      );
      return;
    }

    final order = _order;
    final judgeIndex = nextRound % order.length;
    final subjectIndex = (judgeIndex + 1) % order.length;
    _state = LocalMatchState(
      phase: LocalMatchPhase.playing,
      round: nextRound,
      roundTarget: config.rounds,
      judgeIndex: judgeIndex,
      subjectPlayerId: order[subjectIndex],
      prompt: _drawPrompt(nextRound),
      results: results,
      participantOrder: order,
    );
  }

  /// Back to round 0 with the same roster/config; results are cleared. A
  /// seeded match replays its exact prompt stream; an unseeded one keeps
  /// drawing fresh prompts.
  void restart() {
    if (_seeded) _random = Random(_seed);
    _state = _initialState();
  }

  /// Final standings: score descending, stable seat-order tiebreak.
  List<LocalScore> scoreboard() {
    final done = <String, int>{};
    final skip = <String, int>{};
    for (final result in _state.results) {
      if (result.outcome == LocalRoundOutcome.done) {
        done[result.subjectPlayerId] = (done[result.subjectPlayerId] ?? 0) + 1;
      } else {
        skip[result.subjectPlayerId] = (skip[result.subjectPlayerId] ?? 0) + 1;
      }
    }
    final seat = <String, int>{
      for (var i = 0; i < config.players.length; i++)
        config.players[i].id: i,
    };
    final board = [
      for (final player in config.players)
        LocalScore(
          player: player,
          done: done[player.id] ?? 0,
          skip: skip[player.id] ?? 0,
          score: done[player.id] ?? 0,
        ),
    ];
    board.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return (seat[a.player.id] ?? 0).compareTo(seat[b.player.id] ?? 0);
    });
    return board;
  }

  /// The outright leader, or null when first place is shared.
  LocalPlayer? winner() {
    final board = scoreboard();
    if (board.isEmpty) return null;
    if (board.length > 1 && board[1].score == board[0].score) return null;
    return board.first.player;
  }
}
