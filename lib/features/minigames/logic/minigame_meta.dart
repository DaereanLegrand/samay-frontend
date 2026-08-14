import 'package:flutter/material.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/l10n/app_localizations.dart';

/// Localized name of a `game_type` column value (the DB enum string maps to
/// the l10n label; unknown values fall back to the raw data string).
///
/// Shared by the home games section, the group minigames hub and the session
/// list so every surface names a game identically.
String minigameGameName(AppLocalizations l10n, String? gameType) {
  return switch (gameType) {
    'poke_chain' => l10n.minigamesGamePokeChain,
    'questions' => l10n.minigamesGameQuestions,
    'truth_dare' => l10n.minigamesGameTruthDare,
    'drunk_bottle' => l10n.minigamesGameDrunkBottle,
    'challenge' => l10n.minigamesGameChallenge,
    _ => gameType ?? l10n.minigamesTitle,
  };
}

/// Icon for a [MinigameType].
///
/// Shared by the home-page games section (feed) and the group minigames hub
/// (`minigames_screen.dart`) so the five games always render the same icon
/// everywhere (plugged-UI consistency, 2026-08-13).
IconData minigameIcon(MinigameType type) => switch (type) {
  MinigameType.pokeChain => Icons.bolt,
  MinigameType.questions => Icons.question_answer,
  MinigameType.truthDare => Icons.psychology,
  MinigameType.drunkBottle => Icons.sports_bar,
  MinigameType.challenge => Icons.emoji_events,
};
