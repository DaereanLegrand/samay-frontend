/// Declarative per-game round shapes for single-device play.
///
/// The shared [minigame_engine.dart] owns the game-agnostic turn skeleton; the
/// server-side game modules own their own wire payloads. On one device there is
/// no server session, so the UI needs the same round information computed
/// locally: which prompt kind a truth-or-dare round uses, the "3 statements, 1
/// truth" descriptor, the bottle's spin target and the charades word + timer.
///
/// Everything here is data + pure functions (no widgets, no plugins), so the
/// round-shape math is unit-testable.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/local/local_player.dart';
import 'package:samay/features/minigames/local/local_prompt_pack.dart';

/// The per-game round descriptor the UI renders. Every concrete shape knows
/// [gameType] and the round it describes.
@immutable
sealed class LocalRoundShape {
  const LocalRoundShape({
    required this.gameType,
    required this.round,
    required this.judgeId,
    required this.subjectId,
  });

  final MinigameType gameType;
  final int round;
  final String judgeId;
  final String subjectId;
}

/// Verdad o Reto: the subject must answer a [promptType] prompt.
@immutable
class TruthDareRoundShape extends LocalRoundShape {
  const TruthDareRoundShape({
    required super.round,
    required super.judgeId,
    required super.subjectId,
    required this.promptType,
    required this.prompt,
  }) : super(gameType: MinigameType.truthDare);

  /// `verdad` or `reto` — alternates every round.
  final String promptType;

  /// The prompt drawn for this round (null when the pack ran dry).
  final LocalPrompt? prompt;
}

/// 2 mentiras, 1 verdad: the subject writes [statementCount] statements, of
/// which exactly [truthCount] is true; the others vote for the truth.
@immutable
class TwoLiesRoundShape extends LocalRoundShape {
  const TwoLiesRoundShape({
    required super.round,
    required super.judgeId,
    required super.subjectId,
    this.statementCount = 3,
    this.truthCount = 1,
  }) : super(gameType: MinigameType.twoLiesOneTruth);

  final int statementCount;
  final int truthCount;

  /// The vote indices the round offers (0, 1, 2 for the default shape).
  List<int> get voteIndices => [for (var i = 0; i < statementCount; i++) i];
}

/// La botella: the bottle spins and lands on [targetId]; the spinner is exempt.
@immutable
class DrunkBottleRoundShape extends LocalRoundShape {
  const DrunkBottleRoundShape({
    required super.round,
    required super.judgeId,
    required super.subjectId,
    required this.spinnerId,
    required this.targetId,
    required this.angle,
  }) : super(gameType: MinigameType.drunkBottle);

  /// Who spun the bottle (the round's judge).
  final String spinnerId;

  /// The seat the bottle landed on — never [spinnerId].
  final String targetId;

  /// The resting angle in degrees `[0, 360)` the UI draws.
  final double angle;
}

/// Charades: [actorId] acts [word] out for [seconds] seconds.
@immutable
class CharadesRoundShape extends LocalRoundShape {
  const CharadesRoundShape({
    required super.round,
    required super.judgeId,
    required super.subjectId,
    required this.actorId,
    required this.word,
    required this.seconds,
  }) : super(gameType: MinigameType.charades);

  /// The player holding the phone (the round's subject).
  final String actorId;
  final String word;
  final int seconds;
}

/// The fallback charades word bank used when the pack carries no word prompts.
const List<String> kDefaultCharadesWords = [
  'elefante',
  'pizza',
  'cohete',
  'abuela',
  'guitarra',
  'lluvia',
  'tiburon',
  'mariposa',
  'castillo',
  'bicicleta',
];

/// The truth-or-dare prompt kind of [round]: `verdad` on even rounds, `reto`
/// on odd ones (the alternation the shared game rules describe).
String truthDarePromptTypeForRound(int round) =>
    round.isEven ? 'verdad' : 'reto';

/// Builds the round shape for [gameType].
///
/// [judge] is the rotating asker and [subject] the seat that must answer — the
/// caller passes the match controller's rotation. [random] makes every draw
/// deterministic for a seeded match. [charadesSeconds] is the turn length the
/// UI chose (default 60, mirroring the engine's `charadesSeconds`).
LocalRoundShape localRoundShapeFor({
  required MinigameType gameType,
  required LocalPromptPack pack,
  required List<LocalPlayer> players,
  required int round,
  required LocalPlayer judge,
  required LocalPlayer subject,
  Set<String> excludeIds = const {},
  int charadesSeconds = 60,
  Random? random,
}) {
  final rng = random ?? Random();
  switch (gameType) {
    case MinigameType.truthDare:
      final promptType = truthDarePromptTypeForRound(round);
      final prompt = pack.pickFor(
        promptType: promptType,
        excludeIds: excludeIds,
        random: rng,
      );
      return TruthDareRoundShape(
        round: round,
        judgeId: judge.id,
        subjectId: subject.id,
        promptType: promptType,
        prompt: prompt,
      );
    case MinigameType.twoLiesOneTruth:
      return TwoLiesRoundShape(
        round: round,
        judgeId: judge.id,
        subjectId: subject.id,
      );
    case MinigameType.drunkBottle:
      final seats = [
        for (final p in players)
          if (p.id != judge.id) p,
      ];
      final target = seats.isEmpty ? null : seats[rng.nextInt(seats.length)];
      return DrunkBottleRoundShape(
        round: round,
        judgeId: judge.id,
        subjectId: subject.id,
        spinnerId: judge.id,
        targetId: target?.id ?? judge.id,
        angle: rng.nextDouble() * 360,
      );
    case MinigameType.charades:
      final words = [
        for (final p in pack.promptsOfType('word'))
          if (!excludeIds.contains(p.id) && p.body.trim().isNotEmpty) p.body,
      ];
      final pool = words.isEmpty ? kDefaultCharadesWords : words;
      final word = pool[rng.nextInt(pool.length)];
      return CharadesRoundShape(
        round: round,
        judgeId: judge.id,
        subjectId: subject.id,
        actorId: subject.id,
        word: word,
        seconds: charadesSeconds < 1 ? 60 : charadesSeconds,
      );
  }
}
