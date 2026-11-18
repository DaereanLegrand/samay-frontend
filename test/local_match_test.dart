import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/local/local_game_rules.dart';
import 'package:samay/features/minigames/local/local_match.dart';
import 'package:samay/features/minigames/local/local_match_config.dart';
import 'package:samay/features/minigames/local/local_match_store.dart';
import 'package:samay/features/minigames/local/local_player.dart';
import 'package:samay/features/minigames/local/local_prompt_pack.dart';

LocalPlayer _p(String id, String name) => LocalPlayer(id: id, name: name);

/// A minimal in-memory stand-in for a Hive box (only put/get/keys are used by
/// [HiveLocalMatchStore]); every other member throws if touched.
class FakeBox extends Fake implements Box<String> {
  final Map<String, String> store = {};

  @override
  Iterable<dynamic> get keys => store.keys;

  @override
  String? get(dynamic key, {String? defaultValue}) =>
      store[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, String value) async {
    store['$key'] = value;
  }
}

LocalPromptPack _truthDarePack() {
  return LocalPromptPack(
    id: 'pack-td',
    gameType: MinigameType.truthDare,
    name: 'Verdad o Reto',
    version: 1,
    prompts: [
      for (var i = 0; i < 5; i++)
        LocalPrompt(
          id: 'v$i',
          promptType: 'verdad',
          category: 'suave',
          body: 'Verdad $i',
        ),
      for (var i = 0; i < 5; i++)
        LocalPrompt(
          id: 'r$i',
          promptType: 'reto',
          category: 'medio',
          body: 'Reto $i',
        ),
    ],
  );
}

LocalMatchConfig _threePlayers({int rounds = 5, int? seed = 7}) {
  return LocalMatchConfig(
    gameType: MinigameType.truthDare,
    players: [_p('a', 'Ana'), _p('b', 'Beto'), _p('c', 'Caro')],
    rounds: rounds,
    packId: 'pack-td',
    seed: seed,
  );
}

void main() {
  group('LocalPlayer.create', () {
    test('trims and clamps the name, and rejects blanks', () {
      final player = LocalPlayer.create('  Ana  ');
      expect(player.name, 'Ana');
      expect(player.id, isNotEmpty);

      final long = LocalPlayer.create('x' * 40);
      expect(long.name.length, LocalPlayer.maxNameLength);

      expect(() => LocalPlayer.create('   '), throwsArgumentError);
      expect(() => LocalPlayer.create(''), throwsArgumentError);
    });

    test('copyWith preserves identity and overrides fields', () {
      const player = LocalPlayer(id: 'a', name: 'Ana');
      expect(player.copyWith(name: 'Beto').name, 'Beto');
      expect(player.copyWith().name, 'Ana');
    });
  });

  group('LocalMatchConfig.assertValid', () {
    test('rejects fewer than two players', () {
      final config = LocalMatchConfig(
        gameType: MinigameType.truthDare,
        players: [_p('a', 'Ana')],
        rounds: 3,
        packId: 'pack-td',
      );
      expect(config.assertValid, throwsArgumentError);
    });

    test('rejects a non-positive round target', () {
      final config = LocalMatchConfig(
        gameType: MinigameType.truthDare,
        players: [_p('a', 'Ana'), _p('b', 'Beto')],
        rounds: 0,
        packId: 'pack-td',
      );
      expect(config.assertValid, throwsArgumentError);
    });

    test('rejects duplicate player ids', () {
      final config = LocalMatchConfig(
        gameType: MinigameType.truthDare,
        players: [_p('a', 'Ana'), _p('a', 'Beto')],
        rounds: 3,
        packId: 'pack-td',
      );
      expect(config.assertValid, throwsArgumentError);
    });

    test('rejects blank player names', () {
      final config = LocalMatchConfig(
        gameType: MinigameType.truthDare,
        players: [_p('a', 'Ana'), _p('b', '   ')],
        rounds: 3,
        packId: 'pack-td',
      );
      expect(config.assertValid, throwsArgumentError);
    });

    test('accepts a valid three-player config', () {
      expect(_threePlayers().assertValid, returnsNormally);
    });
  });

  group('LocalPromptPack.pickFor', () {
    test('is deterministic for a seeded Random', () {
      final pack = _truthDarePack();
      final first = pack.pickFor(
        promptType: 'verdad',
        random: Random(42),
      );
      final second = pack.pickFor(
        promptType: 'verdad',
        random: Random(42),
      );
      expect(first, isNotNull);
      expect(second!.id, first!.id);
      expect(first.promptType, 'verdad');
    });

    test('respects excludeIds and the prompt type filter', () {
      final pack = _truthDarePack();
      final picked = pack.pickFor(
        promptType: 'reto',
        excludeIds: {'r0', 'r1', 'r2', 'r3'},
        random: Random(3),
      );
      expect(picked, isNotNull);
      expect(picked!.id, 'r4');
      expect(picked.promptType, 'reto');
    });

    test('returns null when every candidate is excluded', () {
      final pack = _truthDarePack();
      final picked = pack.pickFor(
        excludeIds: {for (final p in pack.prompts) p.id},
        random: Random(3),
      );
      expect(picked, isNull);
    });
  });

  group('LocalMatch rotation', () {
    test('judge rotates 0,1,2 and subject is always the next seat', () {
      final match = LocalMatch.start(_threePlayers(), _truthDarePack());
      final judges = <int>[];
      final subjects = <String>[];
      for (var i = 0; i < 5; i++) {
        expect(match.state.phase, LocalMatchPhase.playing);
        judges.add(match.state.judgeIndex);
        subjects.add(match.state.subjectPlayerId!);
        match.markDone();
      }
      expect(judges, [0, 1, 2, 0, 1]);
      expect(subjects, ['b', 'c', 'a', 'b', 'c']);
      expect(match.state.phase, LocalMatchPhase.finished);
      expect(match.state.round, 5);
      expect(match.state.results.length, 5);
    });

    test('the subject is never the judge for n >= 2', () {
      final match = LocalMatch.start(
        _threePlayers(rounds: 12),
        _truthDarePack(),
      );
      for (var i = 0; i < 12; i++) {
        final judgeId = match.state.participantOrder[match.state.judgeIndex];
        expect(match.state.subjectPlayerId, isNot(judgeId));
        match.markSkip();
      }
    });
  });

  group('LocalMatch prompts', () {
    test('never repeats a prompt id within a session', () {
      final match = LocalMatch.start(_threePlayers(), _truthDarePack());
      final seen = <String>{};
      while (match.state.phase != LocalMatchPhase.finished) {
        final prompt = match.state.prompt;
        expect(prompt, isNotNull);
        expect(seen.add(prompt!.id), isTrue);
        match.markDone();
      }
      expect(seen.length, 5);
    });

    test('alternates verdad and reto for truth_dare', () {
      final match = LocalMatch.start(_threePlayers(), _truthDarePack());
      final types = <String>[];
      while (match.state.phase != LocalMatchPhase.finished) {
        types.add(match.state.prompt!.promptType);
        match.markDone();
      }
      expect(types, ['verdad', 'reto', 'verdad', 'reto', 'verdad']);
    });
  });

  group('LocalMatch scoring', () {
    test('done scores +1, skip scores +0, and tallies per player', () {
      final match = LocalMatch.start(_threePlayers(rounds: 3), _truthDarePack());
      match.markDone(); // judge a -> subject b scores
      match.markSkip(); // judge b -> subject c skips
      match.markDone(); // judge c -> subject a scores

      final board = match.scoreboard();
      expect(board.map((s) => s.player.id).toList(), ['a', 'b', 'c']);
      expect(board[0].score, 1);
      expect(board[0].done, 1);
      expect(board[0].skip, 0);
      expect(board[1].score, 1);
      expect(board[1].done, 1);
      expect(board[2].score, 0);
      expect(board[2].skip, 1);
      expect(match.state.phase, LocalMatchPhase.finished);
    });

    test('scoreboard sorts by score then seat and winner is unique', () {
      final match = LocalMatch.start(
        LocalMatchConfig(
          gameType: MinigameType.truthDare,
          players: [_p('a', 'Ana'), _p('b', 'Beto')],
          rounds: 2,
          packId: 'pack-td',
          seed: 1,
        ),
        _truthDarePack(),
      );
      match.markDone(); // judge a -> subject b scores
      match.markSkip(); // judge b -> subject a skips

      final board = match.scoreboard();
      expect(board.first.player.id, 'b');
      expect(board.first.score, 1);
      expect(match.winner()!.id, 'b');
    });

    test('winner is null on a tie for first', () {
      final match = LocalMatch.start(_threePlayers(rounds: 3), _truthDarePack());
      match.markDone(); // subject b
      match.markSkip(); // subject c
      match.markDone(); // subject a
      expect(match.winner(), isNull);
    });
  });

  group('LocalMatch lifecycle', () {
    test('advance after finish is a stable no-op', () {
      final match = LocalMatch.start(_threePlayers(rounds: 2), _truthDarePack());
      match.markDone();
      match.markDone();
      expect(match.state.phase, LocalMatchPhase.finished);
      final before = match.state;
      match.advance();
      match.markDone();
      expect(identical(before, match.state), isTrue);
      expect(match.state.results.length, 2);
      expect(match.state.round, 2);
    });

    test('restart rebuilds the initial state from the seed', () {
      final match = LocalMatch.start(_threePlayers(rounds: 3), _truthDarePack());
      final initialPromptId = match.state.prompt!.id;
      match.markDone();
      match.markDone();
      match.restart();
      expect(match.state.phase, LocalMatchPhase.playing);
      expect(match.state.round, 0);
      expect(match.state.results, isEmpty);
      expect(match.state.judgeIndex, 0);
      expect(match.state.prompt!.id, initialPromptId);
    });
  });

  group('LocalMatchSummary', () {
    test('JSON round-trips', () {
      final summary = LocalMatchSummary(
        id: 'match-1',
        gameType: MinigameType.twoLiesOneTruth,
        playerNames: const ['Ana', 'Beto'],
        scores: const {'Ana': 2, 'Beto': 1},
        rounds: 3,
        finishedAt: DateTime.utc(2026, 11, 17, 12, 30),
      );
      final copy = LocalMatchSummary.fromJson(summary.toJson());
      expect(copy.id, summary.id);
      expect(copy.gameType, summary.gameType);
      expect(copy.playerNames, summary.playerNames);
      expect(copy.scores, summary.scores);
      expect(copy.rounds, summary.rounds);
      expect(copy.finishedAt, summary.finishedAt);
    });

    test('InMemoryLocalMatchStore saves and lists newest first', () async {
      final store = InMemoryLocalMatchStore();
      final older = LocalMatchSummary(
        id: 'old',
        gameType: MinigameType.charades,
        playerNames: const ['Ana'],
        scores: const {'Ana': 1},
        rounds: 1,
        finishedAt: DateTime.utc(2026, 1, 1),
      );
      final newer = LocalMatchSummary(
        id: 'new',
        gameType: MinigameType.charades,
        playerNames: const ['Ana'],
        scores: const {'Ana': 2},
        rounds: 2,
        finishedAt: DateTime.utc(2026, 2, 1),
      );
      await store.save(older);
      await store.save(newer);
      expect((await store.recent()).map((s) => s.id).toList(), ['new', 'old']);
    });
  });

  group('LocalGameRules.select', () {
    final players = [_p('a', 'Ana'), _p('b', 'Beto')];
    final judge = players.first;
    final subject = players.last;

    test('truth_dare alternates prompt type and picks a prompt', () {
      final pack = _truthDarePack();
      final round0 = localRoundShapeFor(
        gameType: MinigameType.truthDare,
        pack: pack,
        players: players,
        round: 0,
        judge: judge,
        subject: subject,
        random: Random(5),
      );
      final round1 = localRoundShapeFor(
        gameType: MinigameType.truthDare,
        pack: pack,
        players: players,
        round: 1,
        judge: judge,
        subject: subject,
        random: Random(5),
      );
      expect(round0, isA<TruthDareRoundShape>());
      expect((round0 as TruthDareRoundShape).promptType, 'verdad');
      expect(round0.prompt, isNotNull);
      expect((round1 as TruthDareRoundShape).promptType, 'reto');
    });

    test('two_lies_one_truth describes 3 statements with 1 truth', () {
      final shape = localRoundShapeFor(
        gameType: MinigameType.twoLiesOneTruth,
        pack: _truthDarePack(),
        players: players,
        round: 0,
        judge: judge,
        subject: subject,
        random: Random(1),
      );
      expect(shape, isA<TwoLiesRoundShape>());
      final twoLies = shape as TwoLiesRoundShape;
      expect(twoLies.subjectId, 'b');
      expect(twoLies.statementCount, 3);
      expect(twoLies.truthCount, 1);
    });

    test('drunk_bottle spin is deterministic and never targets the spinner', () {
      DrunkBottleRoundShape spin() =>
          localRoundShapeFor(
                gameType: MinigameType.drunkBottle,
                pack: _truthDarePack(),
                players: players,
                round: 0,
                judge: judge,
                subject: subject,
                random: Random(9),
              )
              as DrunkBottleRoundShape;

      final first = spin();
      final second = spin();
      expect(first.targetId, second.targetId);
      expect(first.angle, second.angle);
      expect(first.targetId, isNot(first.spinnerId));
      expect(first.angle, inInclusiveRange(0, 360));
    });

    test('charades describes a word and a timer', () {
      final shape = localRoundShapeFor(
        gameType: MinigameType.charades,
        pack: _truthDarePack(),
        players: players,
        round: 0,
        judge: judge,
        subject: subject,
        charadesSeconds: 45,
        random: Random(2),
      );
      expect(shape, isA<CharadesRoundShape>());
      final charades = shape as CharadesRoundShape;
      expect(charades.actorId, 'b');
      expect(charades.word, isNotEmpty);
      expect(charades.seconds, 45);
    });
  });

  group('LocalMatch larger rosters and seeding', () {
    test('two players rotate judge/subject alternately over 6 rounds', () {
      final match = LocalMatch.start(
        LocalMatchConfig(
          gameType: MinigameType.truthDare,
          players: [_p('a', 'Ana'), _p('b', 'Beto')],
          rounds: 6,
          packId: 'pack-td',
          seed: 11,
        ),
        _truthDarePack(),
      );
      final judges = <int>[];
      final subjects = <String>[];
      for (var i = 0; i < 6; i++) {
        judges.add(match.state.judgeIndex);
        subjects.add(match.state.subjectPlayerId!);
        match.markDone();
      }
      expect(judges, [0, 1, 0, 1, 0, 1]);
      expect(subjects, ['b', 'a', 'b', 'a', 'b', 'a']);
      expect(match.state.phase, LocalMatchPhase.finished);
    });

    test('restart replays the same prompt stream for a seeded match', () {
      final match = LocalMatch.start(
        _threePlayers(rounds: 4),
        _truthDarePack(),
      );
      final firstRun = <String>[];
      while (match.state.phase != LocalMatchPhase.finished) {
        firstRun.add(match.state.prompt!.id);
        match.markDone();
      }
      match.restart();
      final secondRun = <String>[];
      while (match.state.phase != LocalMatchPhase.finished) {
        secondRun.add(match.state.prompt!.id);
        match.markDone();
      }
      expect(secondRun, firstRun);
    });

    test('begin is idempotent and does not disturb a playing match', () {
      final match = LocalMatch.start(_threePlayers(), _truthDarePack());
      final before = match.state;
      match.begin();
      match.begin();
      expect(match.state, before);
      expect(match.state.phase, LocalMatchPhase.playing);
    });

    test('a dry pack yields a null prompt but rounds still advance', () {
      const tiny = LocalPromptPack(
        id: 'tiny',
        gameType: MinigameType.truthDare,
        name: 'Tiny',
        version: 1,
        prompts: [
          LocalPrompt(
            id: 'only',
            promptType: 'verdad',
            category: 'suave',
            body: 'Only one',
          ),
        ],
      );
      final match = LocalMatch.start(_threePlayers(rounds: 3), tiny);
      expect(match.state.prompt!.id, 'only');
      match.markDone();
      expect(match.state.prompt, isNull);
      match.markSkip();
      expect(match.state.prompt, isNull);
      match.markDone();
      expect(match.state.phase, LocalMatchPhase.finished);
      expect(match.state.results.length, 3);
    });
  });

  group('LocalMatchSummary store variants', () {
    test('HiveLocalMatchStore round-trips and sorts newest first', () async {
      final box = FakeBox();
      final store = HiveLocalMatchStore(openBox: () async => box);
      final older = LocalMatchSummary(
        id: 'old',
        gameType: MinigameType.drunkBottle,
        playerNames: const ['Ana', 'Beto'],
        scores: const {'Ana': 1, 'Beto': 0},
        rounds: 1,
        finishedAt: DateTime.utc(2026, 1, 1),
      );
      final newer = LocalMatchSummary(
        id: 'new',
        gameType: MinigameType.truthDare,
        playerNames: const ['Ana', 'Beto'],
        scores: const {'Ana': 3, 'Beto': 2},
        rounds: 5,
        finishedAt: DateTime.utc(2026, 3, 1),
      );
      await store.save(older);
      await store.save(newer);

      expect(box.store.keys, containsAll(['local_match:old', 'local_match:new']));
      expect(
        jsonDecode(box.store['local_match:new']!),
        isA<Map<String, dynamic>>(),
      );

      final list = await store.recent();
      expect(list.map((s) => s.id).toList(), ['new', 'old']);
      expect(list.first.scores, {'Ana': 3, 'Beto': 2});
      expect(list.first.gameType, MinigameType.truthDare);
    });

    test('HiveLocalMatchStore skips corrupt blobs', () async {
      final box = FakeBox();
      box.store['local_match:bad'] = 'not json';
      box.store['other:key'] = jsonEncode({'id': 'x'});
      final store = HiveLocalMatchStore(openBox: () async => box);
      expect(await store.recent(), isEmpty);
    });

    test('summary JSON tolerates a missing finished_at', () {
      final copy = LocalMatchSummary.fromJson({
        'id': 'm',
        'game_type': 'charades',
        'player_names': ['Ana'],
        'scores': {'Ana': 0},
        'rounds': 1,
      });
      expect(copy.finishedAt, DateTime.utc(1970));
      expect(copy.gameType, MinigameType.charades);
    });

    test('fromJson falls back to truth_dare on an unknown game type', () {
      final copy = LocalMatchSummary.fromJson({
        'id': 'm',
        'game_type': 'poke_chain',
        'player_names': const <String>[],
        'scores': const <String, int>{},
        'rounds': 0,
        'finished_at': '2026-01-01T00:00:00.000Z',
      });
      expect(copy.gameType, MinigameType.truthDare);
      expect(copy.playerNames, isEmpty);
    });
  });

  group('LocalMatch.renamePlayer (zero-typing start)', () {
    LocalMatch buildMatch() {
      final players = [
        LocalPlayer.create('Jugador 1'),
        LocalPlayer.create('Jugador 2'),
      ];
      final pack = LocalPromptPack(
        id: 'p',
        gameType: MinigameType.truthDare,
        name: 'base',
        version: 1,
        prompts: [
          for (var i = 0; i < 12; i++)
            LocalPrompt(
              id: 'p$i',
              promptType: i.isEven ? 'verdad' : 'reto',
              category: 'general',
              body: 'prompt $i',
            ),
        ],
      );
      final config = LocalMatchConfig(
        gameType: MinigameType.truthDare,
        players: players,
        rounds: 5,
        packId: 'p',
      );
      return LocalMatch.start(config, pack, random: Random(7));
    }

    test('renames a seat and keeps the round + results intact', () {
      final match = buildMatch();
      match.markDone();
      final round = match.state.round;
      final results = match.state.results.length;
      final judge = match.state.judgePlayerId!;

      match.renamePlayer(judge, '  Ana  ');

      expect(match.config.players.firstWhere((p) => p.id == judge).name, 'Ana');
      expect(match.state.round, round);
      expect(match.state.results.length, results);
      // The state references ids, so the rotation is unaffected.
      expect(match.state.judgePlayerId, judge);
    });

    test('keeps the prompt stream (no redraw, no state loss)', () {
      final match = buildMatch();
      final promptId = match.state.prompt!.id;
      match.renamePlayer(match.state.subjectPlayerId!, 'Beto');
      expect(match.state.prompt!.id, promptId);
    });

    test('clamps a long name and rejects a blank one', () {
      final match = buildMatch();
      final id = match.state.subjectPlayerId!;
      match.renamePlayer(id, 'x' * 40);
      expect(
        match.config.players.firstWhere((p) => p.id == id).name.length,
        LocalPlayer.maxNameLength,
      );
      expect(() => match.renamePlayer(id, '   '), throwsArgumentError);
    });

    test('rejects an unknown seat id', () {
      final match = buildMatch();
      expect(() => match.renamePlayer('nope', 'Ana'), throwsArgumentError);
    });
  });
}
