/// The frozen inputs of one single-device match.
///
/// A [LocalMatchConfig] is validated ONCE (`assertValid`) before a match
/// starts: the pass-the-phone UI has no server to reject a bad roster, so the
/// client must fail loud and early.
library;

import 'package:flutter/foundation.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/local/local_player.dart';

@immutable
class LocalMatchConfig {
  const LocalMatchConfig({
    required this.gameType,
    required this.players,
    required this.rounds,
    required this.packId,
    this.anonymous = false,
    this.seed,
  });

  final MinigameType gameType;
  final List<LocalPlayer> players;
  final int rounds;

  /// The [LocalPromptPack] id this match draws prompts from.
  final String packId;

  /// Whether the roster renders temp aliases instead of player names.
  final bool anonymous;

  /// The match seed. When null the controller draws a fresh [Random] (a
  /// one-device match is not replayable across app launches unless seeded).
  final int? seed;

  /// The config with a different round target (the setup screen's stepper).
  LocalMatchConfig withRounds(int rounds) => LocalMatchConfig(
    gameType: gameType,
    players: players,
    rounds: rounds,
    packId: packId,
    anonymous: anonymous,
    seed: seed,
  );

  /// Throws [ArgumentError] when the roster or round target cannot be played:
  /// fewer than two players, `rounds < 1`, duplicate player ids, or a blank
  /// display name.
  void assertValid() {
    if (players.length < 2) {
      throw ArgumentError.value(
        players.length,
        'players',
        'a local match needs at least 2 players',
      );
    }
    if (rounds < 1) {
      throw ArgumentError.value(rounds, 'rounds', 'must be >= 1');
    }
    final seen = <String>{};
    for (final player in players) {
      if (player.id.trim().isEmpty) {
        throw ArgumentError.value(player.id, 'players', 'player id is blank');
      }
      if (!seen.add(player.id)) {
        throw ArgumentError.value(player.id, 'players', 'duplicate player id');
      }
      if (player.name.trim().isEmpty) {
        throw ArgumentError.value(player.name, 'players', 'blank player name');
      }
    }
  }
}
