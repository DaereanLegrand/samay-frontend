/// Persistent "groups" of pass-the-phone players.
///
/// A group is just a saved roster: a name and the player names that were typed
/// in during the lobby. Reusing one skips the whole "how many players / type a
/// name / pass the phone" dance on the next game night.
///
/// Stored as JSON in the same encrypted Hive box as the match history (the
/// caller supplies the opener), so it needs no backend and no new box.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// A saved roster of pass-the-phone players.
@immutable
class LocalGroup {
  const LocalGroup({
    required this.id,
    required this.name,
    required this.playerNames,
  });

  static const Uuid _uuid = Uuid();

  /// The longest group name the lobby renders on one line.
  static const int maxNameLength = 32;

  /// The name the lobby suggests: the players themselves ("Ana, Beto y Caro").
  static String suggestedName(List<String> names) {
    final clean = [for (final n in names) n.trim()]
      ..removeWhere((n) => n.isEmpty);
    if (clean.isEmpty) return 'grupo';
    if (clean.length == 1) return clean.first;
    return clean.join(', ');
  }

  /// A stable id derived from the group's name + roster, so saving the same
  /// table twice updates the existing group instead of stacking duplicates.
  static String stableId(String name, List<String> playerNames) {
    final key = '${name.trim().toLowerCase()}|${playerNames.join('|').toLowerCase()}';
    return 'group-${key.hashCode.toUnsigned(32).toRadixString(16)}';
  }

  factory LocalGroup.create(String name, List<String> playerNames) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    final clamped = trimmed.length > maxNameLength
        ? trimmed.substring(0, maxNameLength)
        : trimmed;
    final names = [
      for (final n in playerNames)
        if (n.trim().isNotEmpty) n.trim(),
    ];
    return LocalGroup(
      id: stableId(clamped, names),
      name: clamped,
      playerNames: names,
    );
  }

  final String id;
  final String name;
  final List<String> playerNames;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'player_names': playerNames,
  };

  factory LocalGroup.fromJson(Map<String, dynamic> json) {
    final raw = json['player_names'];
    return LocalGroup(
      id: json['id'] as String? ?? _uuid.v4(),
      name: json['name'] as String? ?? 'grupo',
      playerNames: raw is List
          ? [
              for (final n in raw)
                if (n is String) n,
            ]
          : const [],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalGroup &&
        other.id == id &&
        other.name == name &&
        listEquals(other.playerNames, playerNames);
  }

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(playerNames));
}

/// Persistence contract for saved groups.
abstract class LocalGroupStore {
  Future<void> save(LocalGroup group);
  Future<void> delete(String id);
  Future<List<LocalGroup>> all();
}

/// Volatile store (previews).
class InMemoryLocalGroupStore implements LocalGroupStore {
  final List<LocalGroup> _groups = [];

  @override
  Future<void> save(LocalGroup group) async {
    _groups.removeWhere((g) => g.id == group.id);
    _groups.add(group);
  }

  @override
  Future<void> delete(String id) async => _groups.removeWhere((g) => g.id == id);

  @override
  Future<List<LocalGroup>> all() async => [..._groups];
}

/// Hive-backed store: one JSON blob per group under `local_group:<id>`, in the
/// caller-supplied box.
class HiveLocalGroupStore implements LocalGroupStore {
  HiveLocalGroupStore({required Future<Box<String>> Function() openBox})
    : _openBox = openBox;

  static const String keyPrefix = 'local_group:';

  final Future<Box<String>> Function() _openBox;

  @override
  Future<void> save(LocalGroup group) async {
    final box = await _openBox();
    await box.put('$keyPrefix${group.id}', jsonEncode(group.toJson()));
  }

  @override
  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete('$keyPrefix$id');
  }

  @override
  Future<List<LocalGroup>> all() async {
    final box = await _openBox();
    // Keyed by name+roster, NOT by stored id: earlier builds saved a random
    // UUID per save, so the same table accumulated one row per game night.
    // Reading through this map collapses those legacy duplicates.
    final byContent = <String, LocalGroup>{};
    for (final key in box.keys) {
      if (key is! String || !key.startsWith(keyPrefix)) continue;
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final group = LocalGroup.fromJson(Map<String, dynamic>.from(decoded));
          final content = LocalGroup.stableId(group.name, group.playerNames);
          byContent.putIfAbsent(content, () => group);
        }
      } on FormatException {
        // A corrupt blob never blocks the list.
      }
    }
    final groups = byContent.values.toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return groups;
  }
}
