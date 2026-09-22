import 'package:flutter/material.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/l10n/app_localizations.dart';

/// Line-2 text shared by every minigame play header: the by-turns round counter
/// when the game has a round target, otherwise the lowercase game name.
String minigameHeaderSecondary(
  GameTurnSkeleton skeleton,
  String gameNameLower,
  AppLocalizations l10n,
) =>
    skeleton.playMode == MinigamePlayMode.byTurns && skeleton.roundTarget != null
    ? l10n.minigamesRoundCounter(skeleton.round + 1, skeleton.roundTarget!)
    : gameNameLower;

/// The turn line shared by every turn-based play header: "tu turno…" when the
/// caller is the subject, otherwise "turno de {displayName}" (a raw id/empty
/// name never renders — it falls back to the generic turn word).
Widget minigameTurnTitle({
  required bool isMine,
  required String displayName,
  required String secondary,
  required AppLocalizations l10n,
}) {
  if (isMine) {
    return MinigameHeaderTitle(
      word: l10n.minigamesYourTurn,
      secondary: secondary,
    );
  }
  if (displayName.isEmpty) {
    return MinigameHeaderTitle(
      word: l10n.minigamesTurnGeneric.toLowerCase(),
      secondary: secondary,
    );
  }
  return MinigameHeaderTitle(
    prefix: l10n.minigamesTurnBarPrefix,
    name: displayName,
    suffix: l10n.minigamesTurnBarSuffix,
    secondary: secondary,
  );
}

/// A single-word status header (esperando… / error / respondiendo /
/// clasificación).
Widget minigameStatusTitle({
  required String word,
  required String secondary,
  required AppLocalizations l10n,
}) => MinigameHeaderTitle(word: word, secondary: secondary);
