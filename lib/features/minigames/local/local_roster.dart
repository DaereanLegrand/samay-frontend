/// The roster a pass-the-phone game starts with, and the lobby that collects it.
///
/// The lobby is deliberately the same for every game: ask how many people play,
/// collect one name per seat ("pass the device to your right"), offer to save
/// the roster as a reusable group, then show the roster with symbol-only CRUD
/// and one big play button.
///
/// The game-specific knobs live here too — rounds for the prompt games, turn
/// seconds and deck for charadas — so a play screen only reads one object and
/// never re-asks anything.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/local/local_player.dart';

/// Which game the lobby is configuring, and with what.
@immutable
class LocalRoster {
  const LocalRoster({
    required this.gameType,
    required this.players,
    this.rounds = 5,
    this.seconds = 60,
    this.deckId,
  });

  final MinigameType gameType;
  final List<LocalPlayer> players;

  /// Rounds for the prompt games (truth/dare, two lies).
  final int rounds;

  /// Turn length for charadas.
  final int seconds;

  /// The charades deck id; null = every deck.
  final String? deckId;

  /// The smallest playable party. Two is the floor the game rules need (a judge
  /// and a subject); the lobby lets the table grow from there with `+`.
  static const int minPlayers = 2;

  bool get isPlayable => players.length >= minPlayers;

  LocalRoster copyWith({
    List<LocalPlayer>? players,
    int? rounds,
    int? seconds,
    String? deckId,
    bool clearDeck = false,
  }) {
    return LocalRoster(
      gameType: gameType,
      players: players ?? this.players,
      rounds: rounds ?? this.rounds,
      seconds: seconds ?? this.seconds,
      deckId: clearDeck ? null : (deckId ?? this.deckId),
    );
  }
}

/// The roster currently being configured, per game.
///
/// Deliberately NOT `autoDispose`: the lobby WRITES it and the play screen
/// (which the lobby pushes on top) READS it in `initState`. An auto-dispose
/// provider loses the roster exactly when the lobby unmounts under the push,
/// which is how the roster once rendered empty right after "Guardar".
class LocalRosterNotifier extends FamilyNotifier<LocalRoster, MinigameType> {
  @override
  LocalRoster build(MinigameType arg) {
    return LocalRoster(gameType: arg, players: const []);
  }

  /// Applies a saved/typed roster, keeping the game's knobs.
  void setPlayers(List<String> names) {
    state = state.copyWith(
      players: [
        for (final name in names)
          if (name.trim().isNotEmpty) LocalPlayer.create(name),
      ],
    );
  }

  void rename(String playerId, String name) {
    state = state.copyWith(
      players: [
        for (final p in state.players)
          if (p.id == playerId) p.copyWith(name: LocalPlayer.create(name).name) else p,
      ],
    );
  }

  void remove(String playerId) {
    state = state.copyWith(
      players: [
        for (final p in state.players)
          if (p.id != playerId) p,
      ],
    );
  }

  void add(String name) {
    state = state.copyWith(
      players: [...state.players, LocalPlayer.create(name)],
    );
  }

  /// Moves the seat at [from] to [to] — the roster's drag-to-reorder. The
  /// rotation (judge/subject) follows this order, so it is the turn order too.
  void reorder(int from, int to) {
    if (from == to) return;
    final players = [...state.players];
    if (from < 0 || from >= players.length) return;
    final target = to.clamp(0, players.length - 1);
    final moved = players.removeAt(from);
    players.insert(target, moved);
    state = state.copyWith(players: players);
  }

  void setRounds(int rounds) => state = state.copyWith(rounds: rounds);

  void setSeconds(int seconds) => state = state.copyWith(seconds: seconds);

  void setDeck(String? deckId) => state = deckId == null
      ? state.copyWith(clearDeck: true)
      : state.copyWith(deckId: deckId);

  void reset() => state = LocalRoster(gameType: arg, players: const []);
}

final localRosterProvider =
    NotifierProvider.family<
      LocalRosterNotifier,
      LocalRoster,
      MinigameType
    >(LocalRosterNotifier.new);
