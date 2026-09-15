/// Reusable play engine for the five minigame types (150_minigame_play).
///
/// The DB owns randomness (server-random subject/prompt draws) and the prompt
/// bank; this pure-Dart layer owns the game-agnostic turn skeleton parsing,
/// the round-robin judge rotation and the completed-round records — the
/// shared shape every game (poke_chain, questions, truth_dare, drunk_bottle,
/// challenge) builds its rounds on.
///
/// A game state row from `get_minigame_game_state` / `init_*` / `advance_*`
/// / `reveal_*` is an object like:
///
/// ```json
/// {
///   "session_id": "...", "game_type": "truth_dare",
///   "state": {
///     "judge_index": 0, "round": 0, "phase": "playing",
///     "subject_id": "...", "prompt_type": "verdad", "prompt": {...}
///   },
///   "rounds": [...], "created_at": "...", "updated_at": "..."
/// }
/// ```
///
/// The turn skeleton is NESTED under the outer `state` key — [GameTurnSkeleton]
/// parses it, [MinigameGameState] parses the whole row.
library;

import 'dart:math';

/// Lifecycle phase of a minigame session's play engine.
enum MinigamePhase {
  /// The session exists but no game-state row is initialized yet.
  setup,

  /// The host tapped Start; the 5s pre-play countdown is running on every
  /// device (on-device clock, no server deadline). The HOST's device confirms
  /// via `start_minigame_match` → [playing], or cancels → [setup].
  /// 190_minigame_countdown + 203_minigame_host_start.
  countdown,

  /// Rounds are being played (a subject + prompt are current).
  playing,

  /// The game ended (`complete_minigame_game` flipped the phase).
  finished,
}

/// Parses a `state.phase` string into [MinigamePhase] (tolerant: unknown /
/// missing values fall back to [MinigamePhase.setup]).
MinigamePhase minigamePhaseFromString(String? value) {
  return switch (value) {
    'playing' => MinigamePhase.playing,
    'finished' => MinigamePhase.finished,
    'countdown' => MinigamePhase.countdown,
    _ => MinigamePhase.setup,
  };
}

/// How a completed round resolved — the only two outcomes a party game needs.
enum PromptOutcome {
  /// The subject did it (truth answered / dare completed) — the round closes
  /// and the turn advances.
  done,

  /// The subject skipped — the round still closes and the turn advances.
  skip,
}

/// The number of paid prize positions N frozen at session creation
/// (201_minigame_voting). The backend splits the pot HARMONICALLY by rank:
/// share_i = (1/i) / Σ_{k=1..N}(1/k). N is an integer (not a fixed top-1 /
/// top-3 enum) — the UI choice of "how many winners get paid" is deferred
/// (TODO); the client sends a default N = 3.
///
/// The default used when the payload omits it.
const int kDefaultPrizePositions = 3;

/// The play engine's round mode (202_minigame_play_v2), settable at match
/// creation.
enum MinigamePlayMode {
  /// Total-rounds mode: a current subject answers, every OTHER participant
  /// reacts or passes, then the next turn begins. Auto-finishes when the
  /// total `round_target` is reached.
  byTurns('by_turns'),

  /// Per-player mode: each player completes their own rounds any time (the
  /// "reactable rounds" list streams completed rounds to the others), and the
  /// match auto-finishes on the settable [asyncEndsAt] deadline (no override)
  /// or when every player reaches their per-player target.
  async('async');

  const MinigamePlayMode(this.wire);

  final String wire;
}

/// Parses a `play_mode` wire value into [MinigamePlayMode] (defaults to
/// [MinigamePlayMode.byTurns] for absent / unknown values — the pre-202
/// sessions stay by_turns).
MinigamePlayMode minigamePlayModeFromString(String? value) {
  return switch (value) {
    'async' => MinigamePlayMode.async,
    _ => MinigamePlayMode.byTurns,
  };
}

/// One E2EE answer row — ciphertext only (the server never sees plaintext).
/// The caller (UI) decrypts locally; `answerCiphertext` rides the game-state
/// payload / `minigame_answers`, and `imageStoragePath` is the optional
/// private-bucket object path of the ENCRYPTED image bytes (the raw blob lives
/// in `minigame_images`, never in the DB).
class MinigameAnswer {
  const MinigameAnswer({
    required this.round,
    required this.subjectId,
    this.promptType,
    this.promptId,
    this.answerCiphertext,
    this.imageStoragePath,
    this.passed = false,
  });

  final int round;
  final String subjectId;
  final String? promptType;
  final String? promptId;
  final String? answerCiphertext;
  final String? imageStoragePath;
  final bool passed;

  bool get hasAnswer => answerCiphertext != null && answerCiphertext!.isNotEmpty;
  bool get hasImage => imageStoragePath != null && imageStoragePath!.isNotEmpty;

  /// Parses the nested `state.answer` payload (the current by_turns round).
  factory MinigameAnswer.fromJson(Map<String, dynamic> json) {
    return MinigameAnswer(
      round: json['round'] is num ? (json['round'] as num).toInt() : 0,
      subjectId: json['subject_id'] as String? ?? '',
      promptType: json['prompt_type'] as String?,
      promptId: json['prompt_id'] as String?,
      answerCiphertext: json['answer_ciphertext'] as String?,
      imageStoragePath: json['image_storage_path'] as String?,
      passed: json['passed'] == true,
    );
  }
}

/// The reactions of the realtime voting (201_minigame_voting + 204_minigame_pasar).
/// `.wire` is the DB value on `minigame_reactions.reaction` and the
/// `submit_minigame_reaction` / `react_minigame_round` RPC params.
///
/// [ReactionKind.pass] is the reactor-side Pasar (204): a NON-subject opts
/// out of emoji-reacting on a round; the server stores a NULL-reaction row
/// and the round's subject scores -0.5 per passer. It has NO emoji face —
/// the [reactionEmojiKinds] list is what the reaction row renders.
enum ReactionKind {
  /// 😖 — disgust
  disgust('disgust'),

  /// 😢 — sad
  sad('sad'),

  /// 😲 — surprised
  surprised('surprised'),

  /// 🤩 — excited
  excited('excited'),

  /// 😈 — demon
  demon('demon'),

  /// ❤️ — heart
  heart('heart'),

  /// Reactor Pasar (204_minigame_pasar): no emoji, the subject scores -0.5.
  pass('pasar'),

  /// 206_minigame_two_lies_one_truth: votes for statement 0, 1, or 2.
  vote0('vote_0'),
  vote1('vote_1'),
  vote2('vote_2');

  const ReactionKind(this.wire);

  final String wire;
}

/// The emoji face of a [ReactionKind] (the user sees these, never the wire).
const Map<ReactionKind, String> reactionEmoji = {
  ReactionKind.disgust: '😖',
  ReactionKind.sad: '😢',
  ReactionKind.surprised: '😲',
  ReactionKind.excited: '🤩',
  ReactionKind.demon: '😈',
  ReactionKind.heart: '❤️',
};

/// The emoji reactions the reaction row renders — [ReactionKind.pass] is
/// excluded (it is a separate Pasar button, never an emoji tile).
const Iterable<ReactionKind> reactionEmojiKinds = [
  ReactionKind.disgust,
  ReactionKind.sad,
  ReactionKind.surprised,
  ReactionKind.excited,
  ReactionKind.demon,
  ReactionKind.heart,
];

/// Parses a `reaction` wire value into [ReactionKind] (null on unknown /
/// missing values).
ReactionKind? reactionKindFromWire(String? value) {
  return switch (value) {
    'disgust' => ReactionKind.disgust,
    'sad' => ReactionKind.sad,
    'surprised' => ReactionKind.surprised,
    'excited' => ReactionKind.excited,
    'demon' => ReactionKind.demon,
    'heart' => ReactionKind.heart,
    'pasar' => ReactionKind.pass,
    'vote_0' => ReactionKind.vote0,
    'vote_1' => ReactionKind.vote1,
    'vote_2' => ReactionKind.vote2,
    _ => null,
  };
}

/// A voter's committed action on a round (207 per-voter `voters` mirror map):
/// either a specific [kind] emoji or the reactor [pass].
///
/// Emoji ↔ Pasar exclusivity (2026-09-04): once a voter has acted they cannot
/// switch to the OTHER mode — the server rejects the cross-mode tap and the
/// UI greys out the unavailable mode. Emoji → emoji re-votes stay allowed.
class ReactionVote {
  const ReactionVote(this.kind);

  /// The voter's emoji. [ReactionKind.pass] marks the reactor-Pasar sentinel
  /// (the mirror stores a NULL reaction for a pass).
  final ReactionKind kind;

  /// The voter PASSED (mirror value null).
  static const ReactionVote pass = ReactionVote(ReactionKind.pass);

  bool get isPass => kind == ReactionKind.pass;

  ReactionKind get emojiKind => kind;
}

/// One per-tap reaction EVENT (207_minigame_reaction_event, 2026-09-03):
/// the last reaction write the server recorded against a session, streamed on
/// the game-state realtime row as `state.reactions_event`
/// `{"seq": N, "round": R, "reaction": "<emoji wire>", "voter_id": "<uuid>"}`.
///
/// The [seq] is a SESSION-GLOBAL monotonic counter (never reset on round
/// advance), so two events compare by seq; the [round] tells a consumer
/// whether the event belongs to the window it is showing (a round advance
/// leaves a stale last event behind — its round no longer matches). A
/// reactor Pasar records [kind] = [ReactionKind.pass] (the wire `reaction`
/// is NULL) — the UI renders no rise for a pass.
class ReactionEvent {
  const ReactionEvent({
    required this.seq,
    required this.round,
    required this.kind,
    required this.voterId,
  });

  final int seq;
  final int round;
  final ReactionKind kind;
  final String voterId;

  /// Whether this event carries an actual emoji (a Pasar does not).
  bool get hasEmoji => kind != ReactionKind.pass;

  /// Tolerant parse of a `state.reactions_event` json object (null when the
  /// payload is absent / malformed).
  factory ReactionEvent.fromJson(Map<String, dynamic> json) {
    return ReactionEvent(
      seq: json['seq'] is num ? (json['seq'] as num).toInt() : 0,
      round: json['round'] is num ? (json['round'] as num).toInt() : 0,
      kind: reactionKindFromWire(json['reaction'] as String?) ?? ReactionKind.pass,
      voterId: json['voter_id'] as String? ?? '',
    );
  }
}

/// The score a subject earns for a round with [reactionCount] emoji
/// reactions — +1 per emoji, and -1 when they received NONE (the no-
/// reactions penalty, 201 product contract). The reactor-side Pasar (-0.5
/// per passer, 204) is scored SERVER-side; this legacy helper keeps the
/// emoji-only formula for the non-fractional path.
int reactionScore(int reactionCount) {
  return reactionCount > 0 ? reactionCount : -1;
}

/// The HARMONIC integer prize split of a [pot] shards across [positions] paid
/// ranks: share_i = (1/i) / Σ_{k=1..positions}(1/k), computed in exact
/// integer arithmetic (LCM-normalized weights + largest-remainder) so the
/// returned prizes ALWAYS sum exactly to [pot] — never a shard more or less.
///
/// [positions] is capped at [playerCount] (you cannot pay more places than
/// players). Throws [ArgumentError] for a non-positive pot or positions.
List<int> harmonicPrizes(int pot, {required int positions, int playerCount = 3}) {
  if (pot <= 0) {
    throw ArgumentError.value(pot, 'pot', 'must be > 0');
  }
  final n = positions.clamp(1, playerCount);
  // LCM of 1..n.
  var lcm = 1;
  for (var i = 1; i <= n; i++) {
    lcm = lcm ~/ _gcd(lcm, i) * i;
  }
  final weights = [for (var i = 1; i <= n; i++) lcm ~/ i];
  final denom = weights.fold<int>(0, (a, b) => a + b);
  final base = [for (final w in weights) (pot * w) ~/ denom];
  var remaining = pot - base.fold<int>(0, (a, b) => a + b);
  // Largest-remainder: hand the leftover shards to the top ranks first.
  for (var i = 0; i < remaining; i++) {
    base[i % n] += 1;
  }
  return base;
}

int _gcd(int a, int b) {
  while (b != 0) {
    final t = a % b;
    a = b;
    b = t;
  }
  return a;
}

/// The game-agnostic turn skeleton, parsed from the nested `state` jsonb.
///
/// `judgeIndex` is the rotation pointer (advances round-robin server-side);
/// `subjectId` is the CURRENT player the turn belongs to (server-random);
/// `nextSubjectId` is the server-authoritative "who's next" (190); `promptType`
/// + `prompt` hold the revealed prompt for the current turn. During the
/// pre-play countdown (`phase == countdown`) every device runs its OWN
/// on-device 5s countdown — there is no server deadline (203_minigame_host_start;
/// the host's device confirms start via start_minigame_match).
class GameTurnSkeleton {
  const GameTurnSkeleton({
    this.judgeIndex = 0,
    this.round = 0,
    this.phase = MinigamePhase.setup,
    this.subjectId,
    this.roundTarget,
    this.reactions = const {},
    this.reactionCounts = const {},
    this.reactionPassCounts = const {},
    this.reactionVoters = const {},
    this.prizePositions = kDefaultPrizePositions,
    this.nextSubjectId,
    this.promptType,
    this.prompt,
    this.playMode = MinigamePlayMode.byTurns,
    this.anonymous = false,
    this.asyncEndsAt,
    this.asyncRoundsPerPlayer = 1,
    this.roundMap = const {},
    this.answers = const [],
    this.answer,
    this.keyRequests = const {},
    this.reactionsSeq = 0,
    this.reactionEvent,
    this.bottleSpinning = false,
    this.bottleSelectedId,
    this.bottleSeq = 0,
    this.bottleSeats = const [],
    this.bottleAngle,
    this.bottleDare,
    this.bottleDareCategory,
    this.bottleSpunBy,
    this.charadesPhase,
    this.charadesTurnId,
    this.charadesWord,
    this.charadesCategory,
    this.charadesEndsAt,
    this.charadesSeconds = 60,
    this.charadesHits = 0,
    this.charadesMisses = 0,
    this.charadesScores = const {},
    this.charadesLog = const [],
    this.charadesSeq = 0,
  });

  final int judgeIndex;
  final int round;
  final MinigamePhase phase;
  final String? subjectId;

  /// The total-turn target frozen at session creation (201_minigame_voting):
  /// the play engine auto-finishes once [round] reaches it. Null for legacy
  /// open-ended games.
  final int? roundTarget;

  /// The round mode (202_minigame_play_v2): by_turns (total rounds) vs async
  /// (per-player rounds). Defaults to [MinigamePlayMode.byTurns].
  final MinigamePlayMode playMode;

  /// Whether usernames are hidden during play (202_minigame_play_v2) — the
  /// roster renders temp nicknames until the leaderboard reveals real names.
  final bool anonymous;

  /// The async mode hard deadline (settable at creation, no override); null
  /// for by_turns sessions.
  final DateTime? asyncEndsAt;

  /// The async per-player round target (202_minigame_play_v2, default 1).
  final int asyncRoundsPerPlayer;

  /// The async per-player progress — `{participant_id: rounds_completed}`
  /// (202_minigame_play_v2).
  final Map<String, int> roundMap;

  /// Participants who flagged that they LOST their local round keys (app
  /// reinstall / data clear / account switch regenerated the E2EE identity
  /// — 206_minigame_key_request, 2026-09-03). Rides the game-state payload as
  /// `state.key_requests` (jsonb uuid[]) so the marker streams to every
  /// participant on the existing realtime channel. ANY participant who holds
  /// the key history may serve them; the marker clears once a holder delivers.
  final Set<String> keyRequests;

  /// Whether [participantId] is currently awaiting a round-key re-share.
  bool isRequestingKeys(String participantId) => keyRequests.contains(participantId);

  /// The async completed rounds (the "reactable rounds" list) —
  /// ciphertext-only [MinigameAnswer] rows (202_minigame_play_v2).
  final List<MinigameAnswer> answers;

  /// The CURRENT by_turns round's E2EE answer (ciphertext-only), populated
  /// after the subject submits; null before the answer / after advance
  /// (202_minigame_play_v2).
  final MinigameAnswer? answer;

  /// The live reaction tally of the current turn — `{subject_id: [emoji…]}`
  /// streamed on the game-state realtime channel (201_minigame_voting).
  /// Populated by `submit_minigame_reaction`, cleared by `advance`.
  ///
  /// The wire payload (202 security hardening 2026-08-31) carries the tally as
  /// `{subject_id: {"list": [emoji…], "count": N, "pass": P}}` (204 adds the
  /// `pass` reactor-Pasar count) — this map keeps the typed emoji lists for
  /// the legacy/UI rendering, [reactionCounts] the distinct-voter count (never
  /// row count) and [reactionPassCounts] the reactor-Pasar count.
  final Map<String, List<ReactionKind>> reactions;

  /// The distinct-voter reaction count per subject —
  /// `{subject_id: N}` (202_minigame_play_v2 mirror shape, security hardening
  /// 2026-08-31: `count` is distinct voters, never rows). Falls back to the
  /// list length when a legacy flat-shape payload is parsed.
  final Map<String, int> reactionCounts;

  /// The reactor Pasar count per subject — `{subject_id: P}` read from the
  /// mirror's `pass` key (204_minigame_pasar; absent/legacy payloads → 0).
  final Map<String, int> reactionPassCounts;

  /// The per-voter action on the CURRENT round, mirror-read
  /// `{subject_id: {voter_id: <emoji wire> | null}}` (207 — null = the voter
  /// PASSED). Lets a client grey out the OTHER mode on its own deck once it
  /// has acted (emoji ↔ Pasar exclusivity, 2026-09-04). Keyed by subject id.
  final Map<String, Map<String, ReactionVote>> reactionVoters;

  /// The distinct-voter reaction count for [subjectId], or null when the
  /// subject has no tally in the current turn.
  int? reactionCount(String subjectId) => reactionCounts[subjectId];

  /// The reactor Pasar count for [subjectId] (0 when the mirror carries no
  /// `pass` key / the subject has no tally — a legacy payload).
  int reactionPassCount(String subjectId) => reactionPassCounts[subjectId] ?? 0;

  /// The per-voter committed actions on the current round for [subjectId]
  /// (empty when the mirror carries no `voters` map — a legacy payload or a
  /// round with no actions yet).
  Map<String, ReactionVote> votersFor(String subjectId) =>
      reactionVoters[subjectId] ?? const {};

  /// Whether [voterId] has already emoji-reacted on the current round for
  /// [subjectId] (the emoji ↔ Pasar exclusivity helper — the deck disables
  /// Pasar for this voter once true).
  bool hasVoterEmojiReacted(String subjectId, String voterId) {
    final vote = votersFor(subjectId)[voterId];
    return vote != null && !vote.isPass;
  }

  /// Whether [voterId] has already PASSED on the current round for
  /// [subjectId] (the deck disables every emoji tile for this voter once
  /// true).
  bool hasVoterPassed(String subjectId, String voterId) {
    final vote = votersFor(subjectId)[voterId];
    return vote != null && vote.isPass;
  }

  /// The number of paid prize positions N (201_minigame_voting). Defaults to
  /// [kDefaultPrizePositions].
  final int prizePositions;

  /// The per-session monotonic reaction-write counter (207_minigame_reaction_event).
  /// Bumped by 1 on EVERY reaction write — including a same-emoji re-tap whose
  /// [reactions] mirror stays byte-identical — so clients can tell "tapped
  /// again" from "nothing" by comparing seq between realtime rows. Session-
  /// global: never reset on round advance (the [reactionEvent]'s own round
  /// disambiguates which window an event belongs to).
  final int reactionsSeq;

  /// The LAST reaction event the server recorded (207_minigame_reaction_event),
  /// null when none has happened yet in this session / the payload predates
  /// the migration.
  final ReactionEvent? reactionEvent;

  /// Drunk bottle (208_minigame_drunk_bottle): whether the bottle is
  /// currently spinning on every viewer's screen.
  final bool bottleSpinning;

  /// Drunk bottle: the participant id the bottle landed on when it last
  /// stopped (null before the first spin).
  final String? bottleSelectedId;

  /// Drunk bottle: monotonic per-write counter (mirrors [reactionsSeq]) so a
  /// client can tell a fresh spin/stop from a same-value re-delivery.
  final int bottleSeq;

  /// Drunk bottle "pizza" (209_minigame_bottle_pizza): the seating order the
  /// server dealt for the CURRENT spin. Sector k of the pie (k * 360/n
  /// degrees wide) belongs to `bottleSeats[k]`, so the drawn
  /// [bottleAngle] and the announced [bottleSelectedId] always agree. The
  /// server reshuffles this on every spin — players change seats each throw.
  final List<String> bottleSeats;

  /// Drunk bottle: the resting angle in degrees `[0, 360)` the server drew
  /// for the last stop (null while spinning / before the first stop). The
  /// sector containing it owns the round.
  final double? bottleAngle;

  /// Drunk bottle: the reto the server drew for the selected player.
  final String? bottleDare;

  /// Drunk bottle: the reto's category (`suave` / `medio` / `picante` /
  /// `castigo`) — the UI tags the card with it.
  final String? bottleDareCategory;

  /// Drunk bottle: who launched the current spin.
  final String? bottleSpunBy;

  /// The pizza sector index owned by [participantId] for the current spin,
  /// or -1 when they hold no seat (not dealt in yet).
  int bottleSeatOf(String participantId) => bottleSeats.indexOf(participantId);

  // ── Charadas (211_minigame_charades) ────────────────────────────────
  // One player holds the phone on their forehead while the room acts the
  // word out; the turn runs against a SERVER-anchored deadline.

  /// `idle` (nobody playing) / `playing` (a turn is running) / `summary`
  /// (the turn closed and its score is on the board). Null before the first
  /// turn of the session.
  final String? charadesPhase;

  /// The player holding the phone this turn.
  final String? charadesTurnId;

  /// The word currently on screen (the guesser must not look).
  final String? charadesWord;

  /// The category the turn was started with (null = every category).
  final String? charadesCategory;

  /// The SERVER-anchored deadline of the running turn — the client counts
  /// down against this, never against a locally chosen start time.
  final DateTime? charadesEndsAt;

  /// The turn length in seconds the starter chose.
  final int charadesSeconds;

  /// Words guessed in the CURRENT turn.
  final int charadesHits;

  /// Words skipped in the CURRENT turn.
  final int charadesMisses;

  /// Session scoreboard `{participant_id: total hits}`, banked per closed
  /// turn.
  final Map<String, int> charadesScores;

  /// The current turn's word-by-word record: `{word, correct}` entries, in
  /// play order — the summary lists them back.
  final List<({String word, bool correct})> charadesLog;

  /// Monotonic per-write counter for the charades state.
  final int charadesSeq;

  /// Whether a charades turn is running right now.
  bool get charadesIsPlaying => charadesPhase == 'playing';

  /// Whether [participantId] is the one holding the phone.
  bool charadesIsMyTurn(String? participantId) =>
      participantId != null && participantId == charadesTurnId;

  /// The server-drawn player whose turn comes after the current one
  /// (authoritative — the "Siguiente: {name}" indicator).
  final String? nextSubjectId;

  final String? promptType;
  final Map<String, dynamic>? prompt;

  /// Whether the phase is [MinigamePhase.finished].
  bool get isFinished => phase == MinigamePhase.finished;

  /// Whether the pre-play countdown is running.
  bool get isCountdown => phase == MinigamePhase.countdown;

  /// Whether a prompt has been revealed for the current turn.
  bool get hasPrompt => prompt != null;

  /// Tolerant parse of the nested `state` object (missing keys → defaults).
  factory GameTurnSkeleton.fromJson(Map<String, dynamic> json) {
    return GameTurnSkeleton(
      judgeIndex: _asInt(json['judge_index']),
      round: _asInt(json['round']),
      phase: minigamePhaseFromString(json['phase'] as String?),
      subjectId: json['subject_id'] as String?,
      roundTarget: json['round_target'] is num
          ? (json['round_target'] as num).toInt()
          : null,
      reactions: _parseReactions(json['reactions']),
      reactionCounts: _parseReactionCounts(json['reactions']),
      reactionPassCounts: _parseReactionPassCounts(json['reactions']),
      reactionVoters: _parseReactionVoters(json['reactions']),
      prizePositions: _asInt(json['prize_positions']) > 0
          ? _asInt(json['prize_positions'])
          : kDefaultPrizePositions,
      nextSubjectId: json['next_subject_id'] as String?,
      promptType: json['prompt_type'] as String?,
      prompt: json['prompt'] is Map
          ? Map<String, dynamic>.from(json['prompt'] as Map)
          : null,
      playMode: minigamePlayModeFromString(json['play_mode'] as String?),
      anonymous: json['anonymous'] == true,
      asyncEndsAt: DateTime.tryParse(json['async_ends_at'] as String? ?? ''),
      asyncRoundsPerPlayer: _asInt(json['async_rounds_per_player']) > 0
          ? _asInt(json['async_rounds_per_player'])
          : 1,
      roundMap: _parseRoundMap(json['round_map']),
      answers: _parseAnswers(json['answers']),
      answer: json['answer'] is Map
          ? MinigameAnswer.fromJson(
              Map<String, dynamic>.from(json['answer'] as Map),
            )
          : null,
      keyRequests: _parseKeyRequests(json['key_requests']),
      reactionsSeq: _asInt(json['reactions_seq']),
      reactionEvent: json['reactions_event'] is Map
          ? ReactionEvent.fromJson(
              Map<String, dynamic>.from(json['reactions_event'] as Map),
            )
          : null,
      bottleSpinning: json['bottle_spinning'] == true,
      bottleSelectedId: json['bottle_selected_id'] as String?,
      bottleSeq: _asInt(json['bottle_seq']),
      bottleSeats: json['bottle_seats'] is List
          ? [
              for (final s in json['bottle_seats'] as List)
                if (s is String && s.isNotEmpty) s,
            ]
          : const [],
      bottleAngle: json['bottle_angle'] is num
          ? (json['bottle_angle'] as num).toDouble()
          : null,
      bottleDare: json['bottle_dare'] as String?,
      bottleDareCategory: json['bottle_dare_category'] as String?,
      bottleSpunBy: json['bottle_spun_by'] as String?,
      charadesPhase: json['charades_phase'] as String?,
      charadesTurnId: json['charades_turn_id'] as String?,
      charadesWord: json['charades_word'] as String?,
      charadesCategory: json['charades_category'] as String?,
      charadesEndsAt: DateTime.tryParse(
        json['charades_ends_at'] as String? ?? '',
      ),
      charadesSeconds: _asInt(json['charades_seconds']) > 0
          ? _asInt(json['charades_seconds'])
          : 60,
      charadesHits: _asInt(json['charades_hits']),
      charadesMisses: _asInt(json['charades_misses']),
      charadesScores: _parseRoundMap(json['charades_scores']),
      charadesLog: _parseCharadesLog(json['charades_log']),
      charadesSeq: _asInt(json['charades_seq']),
    );
  }

  /// Parses the `charades_log` array of `{word, correct}` entries
  /// (tolerant — malformed entries drop).
  static List<({String word, bool correct})> _parseCharadesLog(Object? value) {
    if (value is! List) return const [];
    return [
      for (final e in value)
        if (e is Map && e['word'] is String)
          (word: e['word'] as String, correct: e['correct'] == true),
    ];
  }

  /// Parses the `state.key_requests` jsonb uuid[] (206_minigame_key_request)
  /// into a [Set] of participant ids. Tolerant — absent / non-array / non-
  /// string entries drop (an empty set means nobody is awaiting keys).
  static Set<String> _parseKeyRequests(Object? value) {
    if (value is! List) return const {};
    return {
      for (final id in value)
        if (id is String && id.isNotEmpty) id,
    };
  }

  /// Parses the `{participant_id: rounds_completed}` async progress map.
  static Map<String, int> _parseRoundMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final e in value.entries)
        if (e.value is num)
          e.key.toString(): (e.value as num).toInt(),
    };
  }

  /// Parses the async `answers` list (ciphertext-only rows, tolerant).
  static List<MinigameAnswer> _parseAnswers(Object? value) {
    if (value is! List) return const [];
    return [
      for (final a in value)
        if (a is Map) MinigameAnswer.fromJson(Map<String, dynamic>.from(a)),
    ];
  }

  /// Parses the `{subject_id: [emoji_wire,…]}` reactions payload into the
  /// typed per-subject reaction lists (tolerant — unknown emojis drop).
  ///
  /// Accepts BOTH wire shapes (202 security hardening 2026-08-31): the legacy
  /// flat `{subject_id: [emoji…]}` and the mirror
  /// `{subject_id: {"list": [emoji…], "count": N}}`.
  static Map<String, List<ReactionKind>> _parseReactions(Object? value) {
    if (value is! Map) return const {};
    final result = <String, List<ReactionKind>>{};
    for (final entry in value.entries) {
      final raw = entry.value;
      final list = raw is Map ? raw['list'] : raw;
      if (list is! List) continue;
      final kinds = <ReactionKind>[];
      for (final r in list) {
        final kind = reactionKindFromWire(r is String ? r : null);
        if (kind != null) kinds.add(kind);
      }
      result[entry.key.toString()] = kinds;
    }
    return result;
  }

  /// Parses the distinct-voter reaction count per subject from the SAME
  /// reactions payload: `{subject_id: {"list": […], "count": N}}` uses the
  /// map's `count`; the legacy flat shape `{subject_id: [emoji…]}` falls back
  /// to the list length. Tolerant — subjects without a tally are skipped.
  static Map<String, int> _parseReactionCounts(Object? value) {
    if (value is! Map) return const {};
    final result = <String, int>{};
    for (final entry in value.entries) {
      final raw = entry.value;
      if (raw is Map) {
        final count = raw['count'];
        if (count is num) {
          result[entry.key.toString()] = count.toInt();
        }
        continue;
      }
      if (raw is List) {
        result[entry.key.toString()] = raw.length;
      }
    }
    return result;
  }

  /// Parses the reactor Pasar count per subject from the mirror shape
  /// `{subject_id: {"list": […], "count": N, "pass": P}}` (204_minigame_pasar).
  /// Tolerant — absent `pass` keys / legacy flat payloads yield no entries
  /// (callers read 0 via [reactionPassCount]).
  static Map<String, int> _parseReactionPassCounts(Object? value) {
    if (value is! Map) return const {};
    final result = <String, int>{};
    for (final entry in value.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final pass = raw['pass'];
      if (pass is num) {
        result[entry.key.toString()] = pass.toInt();
      }
    }
    return result;
  }

  /// Parses the per-voter action map from the mirror shape
  /// `{subject_id: {"voters": {voter_id: <emoji wire> | null}}}` (207).
  /// Tolerant — absent `voters` keys / legacy payloads yield no entries. A
  /// null action value (the JSON pass marker) becomes [ReactionVote.pass].
  static Map<String, Map<String, ReactionVote>> _parseReactionVoters(
    Object? value,
  ) {
    if (value is! Map) return const {};
    final result = <String, Map<String, ReactionVote>>{};
    for (final entry in value.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final voters = raw['voters'];
      if (voters is! Map) continue;
      final perVoter = <String, ReactionVote>{};
      for (final v in voters.entries) {
        final vote = _voteFromWire(v.value);
        if (vote != null && v.key is String) {
          perVoter[v.key.toString()] = vote;
        }
      }
      result[entry.key.toString()] = perVoter;
    }
    return result;
  }

  static ReactionVote? _voteFromWire(Object? value) {
    // null value = the reactor Pasar marker (a NULL reaction row, 204).
    if (value == null) return ReactionVote.pass;
    final kind = reactionKindFromWire(value is String ? value : null);
    if (kind == null || kind == ReactionKind.pass) return null;
    return ReactionVote(kind);
  }

  /// Coerces a json value (int, double or numeric string) into an int,
  /// defaulting to 0 when absent / unparseable.
  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// A completed round — the record appended to `minigame_game_state.rounds`
/// and passed to `advance_minigame_turn` as `p_round`.
class GameRoundRecord {
  GameRoundRecord({
    required this.subjectId,
    required this.outcome,
    this.promptType,
    this.promptId,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String subjectId;
  final PromptOutcome outcome;
  final String? promptType;
  final String? promptId;
  final DateTime at;

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'prompt_type': promptType,
      'prompt_id': promptId,
      'outcome': outcome == PromptOutcome.done ? 'done' : 'skip',
      'at': at.toIso8601String(),
    };
  }

  factory GameRoundRecord.fromJson(Map<String, dynamic> json) {
    return GameRoundRecord(
      subjectId: json['subject_id'] as String,
      promptType: json['prompt_type'] as String?,
      promptId: json['prompt_id'] as String?,
      outcome: json['outcome'] == 'done' ? PromptOutcome.done : PromptOutcome.skip,
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// The full `minigame_game_state` row — the outer object returned by the
/// play-engine RPCs, with the turn skeleton nested under `state`.
class MinigameGameState {
  const MinigameGameState({
    required this.sessionId,
    required this.gameType,
    required this.skeleton,
    required this.rounds,
    required this.ready,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sessionId;
  final String gameType;
  final GameTurnSkeleton skeleton;
  final List<GameRoundRecord> rounds;

  /// The partida lobby's authoritative ready map — `{participant_id: bool}`
  /// (180_minigame_lobby). Written ONLY through `set_minigame_ready` and
  /// streamed live via the `minigame_game_state` realtime subscription, so a
  /// participant's Ready toggle lands here instantly for the whole lobby.
  final Map<String, bool> ready;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFinished => skeleton.isFinished;

  bool get hasPrompt => skeleton.hasPrompt;

  /// Whether [participantId] has toggled Ready (absent → not ready).
  bool isReady(String participantId) => ready[participantId] ?? false;

  /// Parses a play-engine row. The turn skeleton is read from the nested
  /// `state.state` object (tolerant: any missing piece falls back to a
  /// default skeleton); the `ready` map tolerates absence (`{}`).
  factory MinigameGameState.fromRow(Map<String, dynamic> row) {
    final nested = row['state'] is Map
        ? Map<String, dynamic>.from(row['state'] as Map)
        : <String, dynamic>{};
    final rawRounds = row['rounds'];
    final rawReady = row['ready'];
    return MinigameGameState(
      sessionId: row['session_id'] as String? ?? '',
      gameType: row['game_type'] as String? ?? '',
      skeleton: GameTurnSkeleton.fromJson(nested),
      rounds: rawRounds is List
          ? [
              for (final r in rawRounds)
                if (r is Map) GameRoundRecord.fromJson(Map<String, dynamic>.from(r)),
            ]
          : const [],
      ready: rawReady is Map
          ? {
              for (final e in rawReady.entries)
                if (e.value is bool) e.key.toString(): e.value as bool,
            }
          : const {},
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// One ranked row of the settled leaderboard (201_minigame_voting) — a
/// participant's final score, rank and paid prize.
class MinigameResultRow {
  const MinigameResultRow({
    required this.participantId,
    required this.score,
    required this.rank,
    required this.prize,
    this.username = '',
  });

  final String participantId;
  final String username;
  final int score;
  final int rank;
  final int prize;

  /// Parses one `results` jsonb row (tolerant — missing username/prize
  /// default to empty/0).
  factory MinigameResultRow.fromJson(Map<String, dynamic> json) {
    return MinigameResultRow(
      participantId: json['participant_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      score: json['score'] is num ? (json['score'] as num).toInt() : 0,
      rank: json['rank'] is num ? (json['rank'] as num).toInt() : 0,
      prize: json['prize'] is num ? (json['prize'] as num).toInt() : 0,
    );
  }
}

/// The settled leaderboard of a finished minigame (201_minigame_voting) —
/// the `minigame_results` row the client renders after the game ends.
class MinigameResult {
  const MinigameResult({required this.sessionId, required this.rows});

  final String sessionId;

  /// The ranked rows, ordered by rank ascending.
  final List<MinigameResultRow> rows;

  /// The total prize paid out (0 for a free game).
  int get totalPrize => rows.fold<int>(0, (sum, r) => sum + r.prize);

  /// Parses a `minigame_results` row (tolerant — missing/empty results
  /// default to an empty leaderboard).
  factory MinigameResult.fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    return MinigameResult(
      sessionId: json['session_id'] as String? ?? '',
      rows: raw is List
          ? [
              for (final r in raw)
                if (r is Map)
                  MinigameResultRow.fromJson(Map<String, dynamic>.from(r)),
            ]
          : const [],
    );
  }
}

/// The round-robin judge rotation: the next judge is `(current + 1) % count`.
/// Throws [ArgumentError] for a non-positive [participantCount] — a rotation
/// over zero players is meaningless.
int nextJudgeIndex({required int currentIndex, required int participantCount}) {
  if (participantCount <= 0) {
    throw ArgumentError.value(
      participantCount,
      'participantCount',
      'must be > 0',
    );
  }
  return (currentIndex + 1) % participantCount;
}

/// A random participant index in `[0, participantCount)` using [rng] — the
/// client-side mirror of the server's random subject draw (used for previews;
/// the server never trusts it). Throws [ArgumentError] for a non-positive
/// [participantCount].
int randomParticipantIndex({
  required int participantCount,
  required Random rng,
}) {
  if (participantCount <= 0) {
    throw ArgumentError.value(
      participantCount,
      'participantCount',
      'must be > 0',
    );
  }
  return rng.nextInt(participantCount);
}

/// Whether [callerId] may react to the CURRENT by_turns round
/// (202_minigame_play_v2 answer-first contract):
///   * reactions open only when the subject has answered (an [answer] row
///     exists and is NOT passed),
///   * the current subject can NEVER react to their own round.
/// Returns false in every other state (no prompt, waiting for the answer,
/// passed round) — the reaction row must NOT render at all (gated
/// availability, never a disabled stub). A voter who already reacted may
/// re-tap (the server upsert replaces their one action per round).
bool canReactToCurrentRound(
  GameTurnSkeleton skeleton, {
  required String? callerId,
}) {
  if (skeleton.phase != MinigamePhase.playing) return false;
  if (skeleton.subjectId == null) return false;
  if (callerId == null || callerId.isEmpty) return false;
  // The subject never reacts to their own round.
  if (callerId == skeleton.subjectId) return false;
  // Reactions open only after the subject answered (not passed).
  final answer = skeleton.answer;
  if (answer == null || answer.passed) return false;
  return true;
}

/// Whether [callerId] may react to the async completed round [answer]
/// (202_minigame_play_v2): not the round's subject, round not passed. The
/// "available to react" list only shows these rounds.
bool canReactToAsyncRound(
  MinigameAnswer answer, {
  required String? callerId,
}) {
  if (callerId == null || callerId.isEmpty) return false;
  if (answer.passed) return false;
  if (answer.subjectId == callerId) return false;
  return true;
}

/// The async rounds [callerId] can react to (the "available to react ones"
/// list — only those that pass [canReactToAsyncRound] appear at all).
List<MinigameAnswer> reactableAsyncRounds(
  GameTurnSkeleton skeleton, {
  required String? callerId,
}) {
  if (skeleton.playMode != MinigamePlayMode.async) return const [];
  return [
    for (final answer in skeleton.answers)
      if (canReactToAsyncRound(answer, callerId: callerId)) answer,
  ];
}

/// Whether [callerId] has reacted to the current by_turns round (the tally
/// rides `state.reactions[subjectId]`). The mirror's `list` holds emojis and
/// its `pass` count holds passers — either counts as a reaction (the voter
/// used their one action for the round, 204_minigame_pasar).
bool hasReactedToCurrentRound(
  GameTurnSkeleton skeleton, {
  required String? callerId,
}) {
  if (callerId == null || callerId.isEmpty) return false;
  final tally = skeleton.reactions[skeleton.subjectId];
  if (tally != null && tally.isNotEmpty) return true;
  return skeleton.reactionPassCount(skeleton.subjectId ?? '') > 0;
}
