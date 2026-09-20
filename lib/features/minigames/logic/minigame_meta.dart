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
    'truth_dare' => l10n.minigamesGameTruthDare,
    'drunk_bottle' => l10n.minigamesGameDrunkBottle,
    'two_lies_one_truth' => l10n.minigamesGameTwoLiesOneTruth,
    'charades' => l10n.minigamesGameCharades,
    _ => gameType ?? l10n.minigamesTitle,
  };
}

/// The minigame name rendered LOWERCASE (2026-08-30 user directive): the
/// partida lobby's AppBar title is "verdad o reto" for Verdad o Reto, etc.
/// [minigameGameName] resolves the localized label, then `.toLowerCase()`
/// produces the wire-friendly casing in both locales ("Verdad o Reto" →
/// "verdad o reto").
String minigameGameNameLower(AppLocalizations l10n, String? gameType) {
  return minigameGameName(l10n, gameType).toLowerCase();
}

/// Icon for a [MinigameType].
///
/// Shared by the home-page games section (feed) and the group minigames hub
/// (`minigames_screen.dart`) so the five games always render the same icon
/// everywhere (plugged-UI consistency, 2026-08-13).
IconData minigameIcon(MinigameType type) => switch (type) {
  MinigameType.truthDare => Icons.psychology,
  MinigameType.drunkBottle => Icons.sports_bar,
  MinigameType.twoLiesOneTruth => Icons.psychology_alt,
  MinigameType.charades => Icons.theater_comedy,
};

/// How a minigame is meant to be played — the "con amigos / solo" fact every
/// per-game landing page surfaces.
enum MinigameAudience {
  /// Requires other players (two or more).
  friends,

  /// Playable solo.
  solo,

  /// Works both solo and with others.
  both,
}

/// Per-game metadata for the dedicated landing page (2026-08-28): every
/// [MinigameType] resolves a localized explanation and its [MinigameAudience]
/// so the shared `MinigameDetailScreen` stays game-agnostic and new games
/// only need a l10n pair + this switch arm.
extension MinigameMeta on MinigameType {
  /// The explanation paragraph shown under the game title.
  String explanation(AppLocalizations l10n) => switch (this) {
    MinigameType.truthDare => l10n.minigamesGameTruthDareExplanation,
    MinigameType.drunkBottle => l10n.minigamesGameDrunkBottleExplanation,
    MinigameType.twoLiesOneTruth => l10n.minigamesGameTwoLiesOneTruthExplanation,
    MinigameType.charades => l10n.minigamesGameCharadesExplanation,
  };

  /// Whether the game is played with friends, solo, or both.
  MinigameAudience get audience => switch (this) {
    MinigameType.truthDare => MinigameAudience.friends,
    MinigameType.drunkBottle => MinigameAudience.friends,
    MinigameType.twoLiesOneTruth => MinigameAudience.friends,
    MinigameType.charades => MinigameAudience.friends,
  };

  /// Localized audience label ("Para jugar con amigos", "Para jugar solo",
  /// "Con amigos o solo").
  String audienceLabel(AppLocalizations l10n) => switch (audience) {
    MinigameAudience.friends => l10n.minigamesAudienceFriends,
    MinigameAudience.solo => l10n.minigamesAudienceSolo,
    MinigameAudience.both => l10n.minigamesAudienceBoth,
  };

  /// Localized tagline (the one-liner under the game name).
  String tagline(AppLocalizations l10n) => switch (this) {
    MinigameType.truthDare => l10n.minigamesGameTruthDareTagline,
    MinigameType.drunkBottle => l10n.minigamesGameDrunkBottleTagline,
    MinigameType.twoLiesOneTruth => l10n.minigamesGameTwoLiesOneTruthTagline,
    MinigameType.charades => l10n.minigamesGameCharadesTagline,
  };
}

/// Resolves a minigame type from its wire `game_type` string (tolerant —
/// null/unknown returns null so callers can fall back to a generic screen).
MinigameType? minigameTypeFromString(String? gameType) {
  return switch (gameType) {
    'truth_dare' => MinigameType.truthDare,
    'drunk_bottle' => MinigameType.drunkBottle,
    'two_lies_one_truth' => MinigameType.twoLiesOneTruth,
    'charades' => MinigameType.charades,
    _ => null,
  };
}

/// Display name of a session row: the user-supplied `name` when present
/// (trimmed), otherwise the server-computed `auto_name` (`partida-XX`,
/// 170_minigame_invite_badges) when the row carries it, otherwise the
/// fallback `partida-{index + 1}` running number.
///
/// `auto_name` is the CANONICAL partida-N: the notify trigger now embeds it
/// in the invite notification and both creator and invitee resolve the same
/// name from the row in isolation (the 160 index-based fallback is only kept
/// for rows fetched before 170).
String minigameSessionName(
  AppLocalizations l10n,
  Map<String, dynamic> session, {
  int index = 0,
}) {
  final name = session['name'] as String?;
  final trimmed = name?.trim() ?? '';
  if (trimmed.isNotEmpty) return trimmed;
  final auto = session['auto_name'] as String?;
  final autoTrimmed = auto?.trim() ?? '';
  if (autoTrimmed.isNotEmpty) return autoTrimmed;
  return l10n.minigamesAutoName(index + 1);
}
