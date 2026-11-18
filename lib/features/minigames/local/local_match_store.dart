/// On-device history of finished single-device matches.
///
/// A pass-the-phone match never touches the backend, so its summary is kept
/// locally. [InMemoryLocalMatchStore] is the test / ephemeral store;
/// [HiveLocalMatchStore] persists JSON blobs in an injected Hive box.
///
/// [HiveLocalMatchStore] deliberately does NOT import `storage_service.dart`
/// (no plugin/key coupling here). The caller opens the box through
/// [HiveService]'s existing public init path and hands in an opener, e.g.
///
/// ```dart
/// HiveLocalMatchStore(
///   openBox: () => Hive.openBox<String>(
///     HiveService.minigameSummaryBoxName,
///     encryptionCipher: HiveAesCipher(key),
///   ),
/// )
/// ```
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:samay/core/services/minigame_service.dart';

/// The durable record of one finished local match.
@immutable
class LocalMatchSummary {
  const LocalMatchSummary({
    required this.id,
    required this.gameType,
    required this.playerNames,
    required this.scores,
    required this.rounds,
    required this.finishedAt,
  });

  final String id;
  final MinigameType gameType;
  final List<String> playerNames;

  /// `{player_name: score}` — the final board.
  final Map<String, int> scores;
  final int rounds;
  final DateTime finishedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'game_type': gameType.value,
    'player_names': playerNames,
    'scores': scores,
    'rounds': rounds,
    'finished_at': finishedAt.toIso8601String(),
  };

  factory LocalMatchSummary.fromJson(Map<String, dynamic> json) {
    final rawNames = json['player_names'];
    final rawScores = json['scores'];
    return LocalMatchSummary(
      id: json['id'] as String? ?? '',
      gameType: _gameTypeFromWire(json['game_type'] as String?),
      playerNames: rawNames is List
          ? [
              for (final n in rawNames)
                if (n is String) n,
            ]
          : const [],
      scores: rawScores is Map
          ? {
              for (final e in rawScores.entries)
                if (e.value is num) e.key.toString(): (e.value as num).toInt(),
            }
          : const {},
      rounds: json['rounds'] is num ? (json['rounds'] as num).toInt() : 0,
      finishedAt:
          DateTime.tryParse(json['finished_at'] as String? ?? '') ??
          DateTime.utc(1970),
    );
  }

  static MinigameType _gameTypeFromWire(String? wire) {
    for (final type in MinigameType.values) {
      if (type.value == wire) return type;
    }
    return MinigameType.truthDare;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalMatchSummary &&
        other.id == id &&
        other.gameType == gameType &&
        listEquals(other.playerNames, playerNames) &&
        mapEquals(other.scores, scores) &&
        other.rounds == rounds &&
        other.finishedAt == finishedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    gameType,
    Object.hashAll(playerNames),
    Object.hashAll(scores.entries.map((e) => Object.hash(e.key, e.value))),
    rounds,
    finishedAt,
  );
}

/// Persistence contract for local match history.
abstract class LocalMatchStore {
  Future<void> save(LocalMatchSummary summary);
  Future<List<LocalMatchSummary>> recent();
}

/// Volatile store (tests / previews). [recent] is newest-first.
class InMemoryLocalMatchStore implements LocalMatchStore {
  final List<LocalMatchSummary> _items = [];

  @override
  Future<void> save(LocalMatchSummary summary) async {
    _items.removeWhere((s) => s.id == summary.id);
    _items.add(summary);
  }

  @override
  Future<List<LocalMatchSummary>> recent() async {
    final copy = [..._items];
    copy.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    return copy;
  }
}

/// Hive-backed store: one JSON-encoded [LocalMatchSummary] per key
/// `local_match:<id>` in the injected box.
class HiveLocalMatchStore implements LocalMatchStore {
  HiveLocalMatchStore({required Future<Box<String>> Function() openBox})
    : _openBox = openBox;

  static const String keyPrefix = 'local_match:';

  final Future<Box<String>> Function() _openBox;

  String _key(String id) => '$keyPrefix$id';

  @override
  Future<void> save(LocalMatchSummary summary) async {
    final box = await _openBox();
    await box.put(_key(summary.id), jsonEncode(summary.toJson()));
  }

  @override
  Future<List<LocalMatchSummary>> recent() async {
    final box = await _openBox();
    final summaries = <LocalMatchSummary>[];
    for (final key in box.keys) {
      if (key is! String || !key.startsWith(keyPrefix)) continue;
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          summaries.add(
            LocalMatchSummary.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } on FormatException {
        // A corrupt blob never blocks the history list.
      }
    }
    summaries.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    return summaries;
  }
}
