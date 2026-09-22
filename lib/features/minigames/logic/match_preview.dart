/// One player inside a [MatchPreview]'s nested avatar cluster — the minimal
/// profile triple the Games-tab bubbles need, deliberately decoupled from the
/// provider/feed models so the card widgets stay pure (no provider import).
class MatchPlayer {
  const MatchPlayer({required this.id, required this.username, this.avatarUrl});

  final String id;
  final String username;

  /// Remote avatar photo; null falls back to initials.
  final String? avatarUrl;
}

/// A recent match of one game, as the Games-tab deck card draws it: the
/// session id, when it was created (the "most recent first" ranking metric)
/// and the roster to nest inside the match's mega bubble.
///
/// Built by `gameTabMatchesProvider` from the caller's sessions — the deck
/// itself never reads providers.
class MatchPreview {
  const MatchPreview({
    required this.sessionId,
    required this.createdAt,
    required this.players,
    required this.totalPlayers,
  });

  final String sessionId;

  /// Creation time — the recency metric used to pick which matches show.
  final DateTime createdAt;

  /// The roster, capped at the number the bubble nests (see the bubble field).
  final List<MatchPlayer> players;

  /// Full participant count (may exceed `players.length`, driving the `+N`).
  final int totalPlayers;
}
