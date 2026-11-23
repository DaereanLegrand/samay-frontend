import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/services/storage_service.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/minigames/local/charades_decks.dart';
import 'package:samay/features/minigames/local/local_match_store.dart';
import 'package:samay/features/minigames/local/local_player.dart';
import 'package:samay/features/minigames/local/local_roster.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// The pass-the-phone CHARADES turn: the player holds the device on their
/// forehead, the room acts and they guess.
///
/// ## Controls
///
/// The gesture convention is the one every heads-up app ships (Heads Up!, Tilt,
/// Charades!): **face DOWN = correct (+1)**, **face UP = skip (0)**. Tilt works
/// off the accelerometer with hysteresis, so one flick scores once and the
/// device must come back near flat before the next card can be judged. Tap
/// zones at the bottom do exactly the same thing, so the game is still playable
/// when the sensor is unavailable (simulators, tablets on a stand).
///
/// ## Turn flow
///
/// One turn = one player, one countdown (set in the lobby: 30/60/90 s). Every
/// card — correct or skipped — advances immediately and is logged, so the
/// summary can show the words the room nailed and the ones it missed.
///
/// ## Data
///
/// Words come from [kCharadesDecks]: Peruvian categories (animals, pop culture,
/// literature, art, sports, drama, food) that ship in the app, so the game needs
/// no account and no network.
class LocalCharadesScreen extends ConsumerStatefulWidget {
  const LocalCharadesScreen({super.key, required this.gameType});

  /// The game this screen plays (always [MinigameType.charades]; carried so the
  /// route table and the lobby stay game-generic).
  final MinigameType gameType;

  @override
  ConsumerState<LocalCharadesScreen> createState() => _LocalCharadesScreenState();
}

/// One scored card in the turn's log.
class _CharadesLogEntry {
  const _CharadesLogEntry({required this.word, required this.correct});

  final String word;
  final bool correct;
}

class _LocalCharadesScreenState extends ConsumerState<LocalCharadesScreen> {
  /// Every deck, or the one picked in the lobby.
  late CharadesHand _hand;
  int _seconds = 60;

  /// Whose turn it is (seat index).
  int _turnIndex = 0;

  /// Per-player scores, keyed by player id.
  final Map<String, int> _scores = {};

  final List<_CharadesLogEntry> _log = [];

  /// The word on screen right now.
  String? _word;

  /// Countdown of the live turn; null while not playing.
  Timer? _ticker;
  DateTime? _endsAt;

  /// The last tilt we scored, so one gesture cannot fire twice.
  bool _tiltArmed = true;

  /// The live turn's outcome, kept until the player dismisses it.
  bool _turnOver = false;

  /// The players from the lobby roster.
  List<LocalPlayer> _players = const [];

  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final roster = ref.read(localRosterProvider(widget.gameType));
    _players = roster.players;
    _seconds = roster.seconds;
    final decks = _decksFor(roster.deckId);
    _hand = CharadesHand.deal(decks);
    _listenTilt();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tiltSubscription?.cancel();
    super.dispose();
  }

  /// The decks this turn draws from: the one picked in the lobby, or a merged
  /// hand when every category is selected.
  static List<CharadesDeck> _decksFor(String? deckId) {
    if (deckId == null) return kCharadesDecks;
    final picked = [
      for (final d in kCharadesDecks)
        if (d.id == deckId) d,
    ];
    return picked.isEmpty ? kCharadesDecks : picked;
  }

  // ── Tilt ────────────────────────────────────────────────────────────────

  StreamSubscription<AccelerometerEvent>? _tiltSubscription;

  /// Scores a card: face down = correct, face up = skip.
  ///
  /// The accelerometer is used instead of the gyroscope on purpose: the pitch
  /// of a phone held on a forehead is exactly the y axis, the sensor is present
  /// on every device, and a single axis keeps the hysteresis trivial. One
  /// gesture fires once (`_tiltArmed`) and re-arms only when the device comes
  /// back near flat, which is what stops a single flick from clearing the hand.
  void _listenTilt() {
    try {
      _tiltSubscription = accelerometerEventStream().listen(
        (event) {
          if (!_playing || !mounted) return;
          // Gravity on the screen's y axis: ~+9.8 face up, ~-9.8 face down.
          final y = event.y;
          const threshold = 6.0;
          const rearm = 3.0;
          if (_tiltArmed && y <= -threshold) {
            _tiltArmed = false;
            _score(correct: true);
          } else if (_tiltArmed && y >= threshold) {
            _tiltArmed = false;
            _score(correct: false);
          } else if (!_tiltArmed && y.abs() < rearm) {
            _tiltArmed = true;
          }
        },
        onError: (_) {
          // No sensor (simulator, restricted device): tap zones stay.
        },
      );
    } catch (_) {
      // Plugin unavailable — the tap zones are the whole control surface.
    }
  }

  // ── Turn ────────────────────────────────────────────────────────────────

  void _startTurn() {
    if (_players.isEmpty) return;
    setState(() {
      _playing = true;
      _turnOver = false;
      _log.clear();
      _tiltArmed = true;
      _endsAt = DateTime.now().add(Duration(seconds: _seconds));
      _word = _hand.draw();
    });
    _haptic(HapticFeedback.selectionClick);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_remaining <= Duration.zero) {
        _endTurn();
      } else {
        setState(() {});
      }
    });
  }

  Duration get _remaining {
    final endsAt = _endsAt;
    if (endsAt == null) return Duration.zero;
    final left = endsAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _endTurn() {
    _ticker?.cancel();
    setState(() {
      _playing = false;
      _turnOver = true;
      _endsAt = null;
      _word = null;
    });
  }

  /// Logs the card on screen and deals the next one. Ends the turn when the
  /// hand runs out.
  void _score({required bool correct}) {
    final word = _word;
    if (!_playing || word == null) return;
    final player = _players[_turnIndex % _players.length];
    setState(() {
      _log.add(_CharadesLogEntry(word: word, correct: correct));
      if (correct) {
        _scores[player.id] = (_scores[player.id] ?? 0) + 1;
      }
      _word = _hand.draw();
    });
    _haptic(
      correct ? HapticFeedback.mediumImpact : HapticFeedback.lightImpact,
    );
    if (_word == null) _endTurn();
  }

  void _nextPlayer() {
    setState(() {
      _turnIndex = (_turnIndex + 1) % _players.length;
      _turnOver = false;
      _log.clear();
    });
    _hand.reset();
    _startTurn();
  }

  void _haptic(Future<void> Function() effect) {
    try {
      effect();
    } catch (_) {
      // Haptics are a nicety.
    }
  }

  /// Records the finished set of turns in the local history.
  Future<void> _persistIfDone() async {
    if (_scores.isEmpty) return;
    final summary = LocalMatchSummary(
      id: 'charades-${DateTime.now().microsecondsSinceEpoch}',
      gameType: MinigameType.charades,
      playerNames: [for (final p in _players) p.name],
      scores: {
        for (final p in _players) p.name: _scores[p.id] ?? 0,
      },
      rounds: _players.length,
      finishedAt: DateTime.now(),
    );
    try {
      await HiveLocalMatchStore(
        openBox: () async =>
            Hive.box<String>(HiveService.minigameSummaryBoxName),
      ).save(summary);
    } catch (_) {
      // History is a convenience.
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = minigameGameNameLower(l10n, widget.gameType.value);
    final player = _players.isEmpty
        ? null
        : _players[_turnIndex % _players.length];

    if (_players.isEmpty) {
      return Scaffold(
        backgroundColor: context.palette.background,
        body: VHeaderBar(
          titleWidget: MinigameHeaderTitle(word: title),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                l10n.minigamesLobbyNeedPlayers,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        titleWidget: MinigameHeaderTitle(
          word: _playing
              ? l10n.minigamesLocalCharadesTurn(player!.name)
              : title,
          secondary: _playing ? title : null,
        ),
        child: _turnOver
            ? _summary(context, l10n)
            : (_playing ? _playingView(context, l10n) : _ready(context, l10n)),
      ),
    );
  }

  Widget _ready(BuildContext context, AppLocalizations l10n) {
    final player = _players[_turnIndex % _players.length];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.phone_iphone,
          size: 64,
          color: context.palette.foreground,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.charadesHoldForehead,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.minigamesLocalCharadesTurn(player.name),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.palette.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _gestureRow(context, l10n),
        const SizedBox(height: AppSpacing.lg),
        if (_scores.isNotEmpty) _scoreList(context, l10n),
        const SizedBox(height: AppSpacing.xl),
        VButton.emphasized(
          label: l10n.charadesStartTurn,
          onPressed: _startTurn,
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () {
            final navigator = Navigator.of(context);
            _persistIfDone().whenComplete(navigator.maybePop);
          },
          child: Text(
            l10n.minigamesLobbyPlay,
            style: TextStyle(color: context.palette.mutedForeground),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _gestureRow(BuildContext context, AppLocalizations l10n) {
    Widget item(IconData icon, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 32, color: context.palette.foreground),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.mutedForeground,
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        item(Icons.arrow_downward, l10n.charadesTiltDown),
        const SizedBox(width: AppSpacing.md),
        item(Icons.arrow_upward, l10n.charadesTiltUp),
      ],
    );
  }

  Widget _playingView(BuildContext context, AppLocalizations l10n) {
    final seconds = _remaining.inSeconds;
    final total = _seconds;
    final fraction = total <= 0 ? 0.0 : (seconds / total).clamp(0.0, 1.0);
    final urgent = seconds <= 10;
    final ink = urgent ? AppColors.glowPink : context.palette.foreground;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              Text(
                '$seconds',
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(color: ink),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 5,
                  backgroundColor: context.palette.hairline,
                  valueColor: AlwaysStoppedAnimation<Color>(ink),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _word ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: context.palette.foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Tally(
              label: l10n.charadesHit,
              value: _correctCount,
              color: AppColors.mint,
            ),
            const SizedBox(width: AppSpacing.xl),
            _Tally(
              label: l10n.charadesPass,
              value: _passCount,
              color: context.palette.mutedForeground,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Tap zones mirroring the tilt, so the turn works without a sensor.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: VButton.outlined(
                    label: l10n.charadesPass,
                    onPressed: () => _score(correct: false),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: VButton.emphasized(
                    label: l10n.charadesHit,
                    onPressed: () => _score(correct: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, AppLocalizations l10n) {
    final correct = _correctCount;
    final total = _log.length;
    final precision = total == 0 ? 0 : (correct * 100 / total).round();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.charadesTimeUp,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.charadesTurnScore(correct),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.palette.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.charadesPrecision(precision),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.palette.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_log.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: context.palette.surfaceAlt,
              border: Border.all(color: context.palette.hairline),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (final entry in _log)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          entry.correct ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: entry.correct
                              ? AppColors.mint
                              : context.palette.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            entry.word,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: entry.correct
                                      ? context.palette.foreground
                                      : context.palette.mutedForeground,
                                  decoration: entry.correct
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        _scoreList(context, l10n),
        const SizedBox(height: AppSpacing.xl),
        VButton.emphasized(
          label: l10n.charadesNextPlayer,
          onPressed: _nextPlayer,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _scoreList(BuildContext context, AppLocalizations l10n) {
    final rows = [
      for (final p in _players) (player: p, score: _scores[p.id] ?? 0),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.charadesScoreboard.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.palette.mutedForeground,
                    ),
                  ),
                ),
                Expanded(child: Text(rows[i].player.name)),
                Text(
                  '${rows[i].score}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  int get _correctCount => _log.where((e) => e.correct).length;
  int get _passCount => _log.where((e) => !e.correct).length;
}

class _Tally extends StatelessWidget {
  const _Tally({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: color),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.palette.mutedForeground,
          ),
        ),
      ],
    );
  }
}
