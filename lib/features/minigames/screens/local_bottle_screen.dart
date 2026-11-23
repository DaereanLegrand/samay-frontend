import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/services/storage_service.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/minigames/local/local_match_store.dart';
import 'package:samay/features/minigames/local/local_player.dart';
import 'package:samay/features/minigames/local/local_roster.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/widgets/bottle_board.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The pass-the-phone BOTELLA: a real spinning bottle on a pizza board.
///
/// The animation is the SAME widget the multi-device game paints
/// ([BottleBoard]): a free-running spin while the player holds "girar", then a
/// three-turn deceleration onto the final angle. The draw itself is local, so
/// the bottle can never disagree with the name it announces.
class LocalBottleScreen extends ConsumerStatefulWidget {
  const LocalBottleScreen({super.key, required this.gameType});

  /// The game this screen plays (always [MinigameType.drunkBottle]).
  final MinigameType gameType;

  @override
  ConsumerState<LocalBottleScreen> createState() => _LocalBottleScreenState();
}

class _LocalBottleScreenState extends ConsumerState<LocalBottleScreen>
    with TickerProviderStateMixin {
  List<LocalPlayer> _players = const [];

  /// Free-running spin while the button says "parar".
  late final AnimationController _spin;
  Animation<double>? _settleTween;

  /// One-shot deceleration onto the drawn angle.
  late final AnimationController _settle;

  /// Current rotation in radians (0 = pointing at seat 0, at 12 o'clock).
  double _angle = 0;

  /// The seat the bottle landed on, once the deceleration has landed.
  String? _landedId;
  bool _spinning = false;

  /// The angle the throw should settle on, decided when the spin stops.
  double _targetAngle = 0;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _players = ref.read(localRosterProvider(widget.gameType)).players;
    _spin =
        AnimationController(
          duration: const Duration(milliseconds: 700),
          vsync: this,
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _settle = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    )..addListener(() {
        final tween = _settleTween;
        if (tween != null && mounted) setState(() => _angle = tween.value);
      });
  }

  @override
  void dispose() {
    _spin.dispose();
    _settle.dispose();
    super.dispose();
  }

  double get _currentAngle =>
      _spin.isAnimating ? _angle + _spin.value * 2 * pi : _angle;

  void _startSpin() {
    if (_players.length < 2) return;
    HapticFeedback.selectionClick();
    setState(() {
      _spinning = true;
      _landedId = null;
    });
    _settle.stop();
    _spin.repeat();
  }

  /// Picks the seat and decelerates onto its slice — never the seat that spun,
  /// which is what makes the game feel fair.
  void _stopSpin() {
    if (!_spinning) return;
    final spinner = _players[_spinnerIndex];
    final candidates = [
      for (var i = 0; i < _players.length; i++)
        if (_players[i].id != spinner.id) i,
    ];
    final landedIndex = candidates[_random.nextInt(candidates.length)];
    _spinnerIndex = (_spinnerIndex + 1) % _players.length;
    final seatAngle = landedIndex * (2 * pi / _players.length);

    HapticFeedback.mediumImpact();
    _spin.stop();
    setState(() {
      _spinning = false;
      _targetAngle = seatAngle;
    });

    // Land forward: keep turning clockwise, add three showy turns, settle
    // exactly on the winning slice's middle.
    final from = _currentAngle;
    final base = from - (from % (2 * pi));
    var to = base + seatAngle + 3 * 2 * pi;
    while (to <= from) {
      to += 2 * pi;
    }
    _settleTween = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic),
    );
    _settle.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _angle = _targetAngle % (2 * pi);
        _landedId = _players[landedIndex].id;
      });
    });
  }

  /// Whose turn it is to spin: rotates on every throw, so the same host is not
  /// holding the phone all night.
  int _spinnerIndex = 0;

  Future<void> _persistIfAny() async {
    if (_landedId == null) return;
    // The bottle is not scored; the history entry records who spun and who it
    // landed on, so a night of draws is not lost.
    final summary = LocalMatchSummary(
      id: 'bottle-${DateTime.now().microsecondsSinceEpoch}',
      gameType: MinigameType.drunkBottle,
      playerNames: [for (final p in _players) p.name],
      scores: {
        for (final p in _players) p.name: p.id == _landedId ? 1 : 0,
      },
      rounds: 1,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = minigameGameNameLower(l10n, widget.gameType.value);
    final landed = _landedId == null
        ? null
        : _players.where((p) => p.id == _landedId).firstOrNull;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        titleWidget: MinigameHeaderTitle(
          word: landed == null
              ? (_spinning ? l10n.minigamesLocalSpinning : title)
              : l10n.minigamesLocalLandedOn(landed.name),
          secondary: landed == null ? null : title,
        ),
        child: _players.length < 2
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.minigamesLobbyNeedPlayers,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final side = min(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return SizedBox(
                            width: side,
                            height: side,
                            child: BottleBoard(
                              seated: [
                                for (final p in _players)
                                  BottleBoardPlayer(
                                    id: p.id,
                                    name: p.name,
                                    isMe: p.id == _players.first.id,
                                  ),
                              ],
                              selectedId: _spinning ? null : _landedId,
                              angle: _currentAngle,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (landed != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Text(
                        l10n.minigamesLocalLandedOn(landed.name),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: VButton.emphasized(
                      label: _spinning
                          ? l10n.minigamesBottleStop
                          : l10n.minigamesLocalSpin,
                      onPressed: _spinning ? _stopSpin : _startSpin,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: TextButton(
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        _persistIfAny().whenComplete(navigator.maybePop);
                      },
                      child: Text(
                        l10n.minigamesLocalPlayAgain,
                        style: TextStyle(
                          color: context.palette.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
