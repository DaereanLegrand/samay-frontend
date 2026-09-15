import 'dart:convert';

import 'package:samay/features/minigames/logic/minigame_engine.dart';

/// One statement in the "2 mentiras, 1 verdad" minigame.
class TwoLiesStatement {
  const TwoLiesStatement({
    required this.index,
    required this.text,
    required this.isTruth,
  });

  final int index;
  final String text;
  final bool isTruth;

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'is_truth': isTruth,
  };

  factory TwoLiesStatement.fromJson(Map<String, dynamic> json) => TwoLiesStatement(
    index: json['index'] is num ? (json['index'] as num).toInt() : 0,
    text: json['text'] as String? ?? '',
    isTruth: json['is_truth'] == true,
  );
}

/// The encrypted round payload for "2 mentiras, 1 verdad" (206_minigame_two_lies_one_truth).
///
/// Holds the 3 statements created by the subject and the secret [truthIndex]
/// indicating which one (0, 1, or 2) is the single true statement.
class TwoLiesPayload {
  const TwoLiesPayload({
    required this.statements,
    required this.truthIndex,
  });

  final List<TwoLiesStatement> statements;
  final int truthIndex;

  Map<String, dynamic> toJson() => {
    'statements': statements.map((s) => s.toJson()).toList(),
    'truth_index': truthIndex,
  };

  factory TwoLiesPayload.fromJson(Map<String, dynamic> json) {
    final list = (json['statements'] as List?)
            ?.map((e) => TwoLiesStatement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [];
    final truthIdx = json['truth_index'] is num ? (json['truth_index'] as num).toInt() : 0;
    return TwoLiesPayload(statements: list, truthIndex: truthIdx);
  }

  String encode() => jsonEncode(toJson());

  static TwoLiesPayload? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return TwoLiesPayload.fromJson(decoded);
      }
      if (decoded is Map) {
        return TwoLiesPayload.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

/// Resolves the vote index (0, 1, or 2) from a [ReactionKind], or null if not a vote.
int? twoLiesVoteIndexFromReaction(ReactionKind? reaction) {
  return switch (reaction) {
    ReactionKind.vote0 => 0,
    ReactionKind.vote1 => 1,
    ReactionKind.vote2 => 2,
    _ => null,
  };
}

/// Converts a statement index (0, 1, or 2) into the wire reaction string ('vote_0'..'vote_2').
String twoLiesWireReactionForIndex(int index) => 'vote_$index';
