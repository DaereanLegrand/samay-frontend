/// The on-device prompt bank a single-device match draws from.
///
/// A [LocalPromptPack] is the offline substitute for the server-side
/// `minigame_prompts` table: the whole pack ships in the app (or user content)
/// and the match controller picks prompts from it with a seeded [Random], so a
/// replayed match makes the same choices.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:samay/core/services/minigame_service.dart';

/// One prompt row: [promptType] is the game-specific wire value (`verdad` /
/// `reto` for truth-or-dare, `suave` / `medio` / `picante` / `castigo` for the
/// bottle, `word` for charades, …). [category] is the human-facing bucket.
@immutable
class LocalPrompt {
  const LocalPrompt({
    required this.id,
    required this.promptType,
    required this.category,
    required this.body,
  });

  final String id;
  final String promptType;
  final String category;
  final String body;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalPrompt &&
        other.id == id &&
        other.promptType == promptType &&
        other.category == category &&
        other.body == body;
  }

  @override
  int get hashCode => Object.hash(id, promptType, category, body);

  @override
  String toString() => 'LocalPrompt($id, $promptType, $category)';
}

/// An immutable snapshot of a prompt bank for one [gameType].
@immutable
class LocalPromptPack {
  const LocalPromptPack({
    required this.id,
    required this.gameType,
    required this.name,
    required this.version,
    required this.prompts,
  });

  final String id;
  final MinigameType gameType;
  final String name;
  final int version;
  final List<LocalPrompt> prompts;

  /// Every prompt id in this pack (the exclusion seed a match starts from).
  Set<String> get promptIds => {for (final p in prompts) p.id};

  /// The prompts of a `promptType` (all prompts when [promptType] is null).
  List<LocalPrompt> promptsOfType(String? promptType) {
    if (promptType == null) return prompts;
    return [
      for (final p in prompts)
        if (p.promptType == promptType) p,
    ];
  }

  /// Deterministically picks a prompt of [promptType] (nullable = any) that is
  /// not in [excludeIds], using the injected [random].
  ///
  /// Returns null when every candidate is excluded (or the pack is empty for
  /// that type) — the caller decides whether to reuse a prompt or end early.
  LocalPrompt? pickFor({
    String? promptType,
    Set<String> excludeIds = const {},
    required Random random,
  }) {
    final candidates = [
      for (final p in promptsOfType(promptType))
        if (!excludeIds.contains(p.id)) p,
    ];
    if (candidates.isEmpty) return null;
    return candidates[random.nextInt(candidates.length)];
  }

  LocalPromptPack copyWith({
    String? id,
    MinigameType? gameType,
    String? name,
    int? version,
    List<LocalPrompt>? prompts,
  }) {
    return LocalPromptPack(
      id: id ?? this.id,
      gameType: gameType ?? this.gameType,
      name: name ?? this.name,
      version: version ?? this.version,
      prompts: prompts ?? this.prompts,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LocalPromptPack) return false;
    if (other.id != id ||
        other.gameType != gameType ||
        other.name != name ||
        other.version != version ||
        other.prompts.length != prompts.length) {
      return false;
    }
    for (var i = 0; i < prompts.length; i++) {
      if (other.prompts[i] != prompts[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, gameType, name, version, prompts.length);
}
