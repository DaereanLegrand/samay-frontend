/// Verdad o Reto (truth_dare) game rules, thin on top of the reusable
/// [minigame_engine.dart] skeleton. The DB owns the random subject draws, the
/// prompt bank and the turn rotation; this file only maps the wire values
/// (`'verdad'` / `'reto'`) to display concepts and pulls the revealed prompt
/// body out of the shared game state.
library;

import 'package:samay/l10n/app_localizations.dart';

/// The two prompt kinds of Verdad o Reto. `.wire` is the value stored in
/// `minigame_prompts.prompt_type` and passed to `reveal_minigame_prompt`.
enum TruthDareKind {
  truth('verdad'),
  dare('reto');

  const TruthDareKind(this.wire);

  final String wire;
}

/// Parses a `prompt_type` wire value into [TruthDareKind] (null on unknown /
/// missing values).
TruthDareKind? truthDareKindFromWire(String? value) {
  return switch (value) {
    'verdad' => TruthDareKind.truth,
    'reto' => TruthDareKind.dare,
    _ => null,
  };
}

/// The localized label of a prompt kind ("Verdad" / "Reto").
String truthDareKindLabel(AppLocalizations l10n, TruthDareKind kind) {
  return switch (kind) {
    TruthDareKind.truth => l10n.minigamesTruth,
    TruthDareKind.dare => l10n.minigamesDare,
  };
}

/// The prompt as displayed: the localized kind label, a colon and a newline,
/// then the body — e.g. `Reto:\nBaila 10 segundos` (`Verdad:\n…` for a
/// question). Falls back to the bare body when the kind is unknown.
String truthDarePromptDisplay(
  AppLocalizations l10n, {
  required String body,
  TruthDareKind? kind,
}) {
  if (kind == null) return body;
  return '${truthDareKindLabel(l10n, kind)}:\n$body';
}

/// The revealed prompt body for the current turn, or null when no prompt has
/// been revealed yet. Reads the nested `skeleton.prompt['body']` (the prompt
/// row jsonb the reveal RPC persisted).
String? truthDarePromptBody(Map<String, dynamic>? prompt) {
  final body = prompt?['body'];
  return body is String && body.isNotEmpty ? body : null;
}

/// The default anonymous temp nickname for a participant (202_minigame_play_v2):
/// localized `anónimoXXX` with a random-unique numeric suffix.
String defaultAnonAlias(AppLocalizations l10n, {required String seed}) {
  final code = seed.hashCode.abs() % 1000;
  return '${l10n.minigamesAnonAliasPrefix}$code';
}
