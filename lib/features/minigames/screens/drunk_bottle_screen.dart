import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/bottle_board.dart';
import 'package:samay/features/minigames/widgets/minigame_play_header.dart';
import 'package:samay/features/minigames/widgets/minigame_session_surface.dart';
import 'package:samay/features/minigames/widgets/minigame_rules_sheet.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// The minimum roster the bottle needs — with fewer than three slices the
/// pizza stops being a game (209: lowered from 6 on product feedback).
const int kDrunkBottleMinPlayers = 3;

/// Botella play screen (208 + 209_minigame_bottle_pizza).
///
/// The roster is dealt onto a pizza: n equal slices, slice k owned by
/// `bottle_seats[k]`, so wherever the bottle stops it ALWAYS stops inside
/// exactly one player's slice. The server owns the whole draw (seat shuffle,
/// resting angle, winner, reto) and every device renders the same numbers —
/// the animation and the announced winner cannot disagree.
///
/// Any participant may spin or stop. Each spin reseats everyone, so the same
/// two people are not neighbours all night.
class DrunkBottleScreen extends ConsumerStatefulWidget {
  const DrunkBottleScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<DrunkBottleScreen> createState() => _DrunkBottleScreenState();
}

class _DrunkBottleScreenState extends ConsumerState<DrunkBottleScreen> {
  /// Whether the round's result may be shown yet.
  ///
  /// The server resolves the winner the instant someone taps Parar, but
  /// announcing it right then spoils the throw: the name lights up while the
  /// bottle is still visibly turning. The table holds the result back until
  /// the deceleration lands, and only then does the slice glow, the reto
  /// appear and the header name the player.
  bool _revealed = true;

  String get sessionId => widget.sessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final participants =
        ref.watch(minigameParticipantsProvider(sessionId)).valueOrNull ??
        const <MinigameParticipant>[];
    final gameState = ref.watch(minigameGameStateProvider(sessionId));
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final gameNameLower = minigameGameNameLower(
      l10n,
      MinigameType.drunkBottle.value,
    );
    final headerTitle = gameState.when(
      loading: () => minigameStatusTitle(
        word: l10n.minigamesBarWaiting,
        secondary: gameNameLower,
        l10n: l10n,
      ),
      error: (_, _) => minigameStatusTitle(
        word: l10n.minigamesBarError,
        secondary: gameNameLower,
        l10n: l10n,
      ),
      data: (state) {
        final s = state.skeleton;
        final enoughPlayers = participants.length >= kDrunkBottleMinPlayers;
        if (!enoughPlayers) return null;
        if (s.bottleSpinning) {
          return minigameStatusTitle(
            word: l10n.minigamesBottleSpinning,
            secondary: gameNameLower,
            l10n: l10n,
          );
        }
        final winner = (s.bottleSelectedId == null || !_revealed)
            ? null
            : participants.where((p) => p.id == s.bottleSelectedId).firstOrNull;
        if (winner != null) {
          return minigameStatusTitle(
            word: winner.id == myId
                ? l10n.minigamesBottleYourTurn
                : l10n.minigamesBottleLandedOn(winner.username),
            secondary: gameNameLower,
            l10n: l10n,
          );
        }
        return minigameStatusTitle(
          word: l10n.minigamesBottleTapToSpin,
          secondary: gameNameLower,
          l10n: l10n,
        );
      },
    );

    final inks = MinigameInks.of(context);
    return MinigameSessionSurface(
      sessionId: sessionId,
      child: Scaffold(
        backgroundColor: inks.themed ? inks.surface : context.palette.background,
        body: VHeaderBar(
          titleWidget: headerTitle,
          title: headerTitle == null ? gameNameLower : null,
          // "Cómo se juega": the same rules sheet on every game.
          actions: const [MinigameRulesButton(type: MinigameType.drunkBottle)],
          child: gameState.when(
            loading: () => const VLoadingView(),
            error: (e, _) => Center(child: Text(e.toAppError().message)),
            data: (state) => participants.isEmpty
                ? const VLoadingView()
                : _BottleTable(
                    sessionId: sessionId,
                    participants: participants,
                    state: state,
                    revealed: _revealed,
                    onRevealChanged: (value) {
                      if (_revealed == value || !mounted) return;
                      setState(() => _revealed = value);
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _BottleTable extends ConsumerStatefulWidget {
  const _BottleTable({
    required this.sessionId,
    required this.participants,
    required this.state,
    required this.revealed,
    required this.onRevealChanged,
  });

  final String sessionId;
  final List<MinigameParticipant> participants;
  final MinigameGameState state;

  /// Whether the result may be shown (false while the bottle decelerates).
  final bool revealed;
  final ValueChanged<bool> onRevealChanged;

  @override
  ConsumerState<_BottleTable> createState() => _BottleTableState();
}

class _BottleTableState extends ConsumerState<_BottleTable>
    with TickerProviderStateMixin {
  /// Free-running spin while `bottle_spinning` is true.
  late final AnimationController _spin;

  /// One-shot deceleration onto the server's resting angle.
  late final AnimationController _settle;
  Animation<double>? _settleTween;

  /// Current bottle rotation in radians (0 = pointing at game angle 0 = up).
  double _angle = 0;

  int _seenSeq = -1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
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
    );
    _adopt(widget.state, animate: false);
  }

  @override
  void didUpdateWidget(covariant _BottleTable old) {
    super.didUpdateWidget(old);
    _adopt(widget.state, animate: true);
  }

  @override
  void dispose() {
    _spin.dispose();
    _settle.dispose();
    super.dispose();
  }

  /// Tells the screen whether the result may be shown.
  ///
  /// [_adopt] runs from `initState` and `didUpdateWidget` — both inside the
  /// build phase — and the listener rebuilds our ANCESTOR, which Flutter
  /// forbids mid-build ("setState() called during build"). Left unguarded it
  /// corrupted the frame: the table and its button were laid out twice, the
  /// Parar button kept the Girar label and the throw could not be stopped.
  ///
  /// So a mid-build call is deferred to the end of the frame. The reveal that
  /// ends the throw arrives the other way round — from the settle animation's
  /// completion, with no frame in flight — and `addPostFrameCallback` does
  /// NOT schedule one, so deferring it there would leave the callback queued
  /// forever and the winner would never light up. Outside the build phase we
  /// therefore notify straight away.
  void _notifyReveal(bool value) {
    if (widget.revealed == value) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final midBuild =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!midBuild) {
      if (mounted) widget.onRevealChanged(value);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRevealChanged(value);
    });
  }

  /// Applies a server state: start the free spin, or decelerate onto the
  /// drawn angle. Guarded by `bottle_seq` so a re-delivery of the same row
  /// never restarts the animation.
  void _adopt(MinigameGameState state, {required bool animate}) {
    final skeleton = state.skeleton;
    if (skeleton.bottleSeq == _seenSeq) return;
    _seenSeq = skeleton.bottleSeq;

    if (skeleton.bottleSpinning) {
      _settle.stop();
      _notifyReveal(false);
      if (!_spin.isAnimating) _spin.repeat();
      return;
    }

    _spin.stop();
    final degrees = skeleton.bottleAngle;
    if (degrees == null) return;
    final target = degrees * pi / 180.0;

    if (!animate) {
      // Re-entering a round that already resolved: no throw to watch, so the
      // result is shown straight away. This path only runs from `initState`,
      // before the first build — assigning the field is enough, and calling
      // setState there would be an error.
      _notifyReveal(true);
      _angle = target;
      return;
    }

    // The throw is about to play out — keep the result hidden until it lands.
    _notifyReveal(false);

    // Land forward: keep turning clockwise from wherever we are, then add
    // three showy turns before settling exactly on the server's angle.
    final from = _currentAngle;
    final base = from - (from % (2 * pi));
    var to = base + target + 3 * 2 * pi;
    while (to <= from) {
      to += 2 * pi;
    }
    _settleTween =
        Tween<double>(begin: from, end: to).animate(
          CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic),
        )..addListener(() {
          if (mounted) setState(() => _angle = _settleTween!.value);
        });
    _settle.forward(from: 0).then((_) {
      _notifyReveal(true);
    });
  }

  double get _currentAngle =>
      _spin.isAnimating ? _angle + _spin.value * 2 * pi : _angle;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The seating order to render: the server's dealt seats, filtered to the
  /// players we can actually resolve, falling back to the roster order before
  /// the first spin.
  List<MinigameParticipant> get _seated {
    final byId = {for (final p in widget.participants) p.id: p};
    final seats = widget.state.skeleton.bottleSeats;
    if (seats.isEmpty) return widget.participants;
    final ordered = [
      for (final id in seats)
        if (byId[id] != null) byId[id]!,
    ];
    // A player who joined mid-match is not in the dealt seats yet — show them
    // anyway so nobody disappears from the table.
    for (final p in widget.participants) {
      if (!seats.contains(p.id)) ordered.add(p);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final skeleton = widget.state.skeleton;
    final seated = _seated;
    final spinning = skeleton.bottleSpinning;
    final selectedId = skeleton.bottleSelectedId;
    final revealed = widget.revealed;
    final winner = (selectedId == null || !revealed)
        ? null
        : seated.where((p) => p.id == selectedId).firstOrNull;
    final enoughPlayers = seated.length >= kDrunkBottleMinPlayers;

    return Column(
      children: [
        if (!enoughPlayers)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.minigamesBottleMinPlayers(
                kDrunkBottleMinPlayers,
                seated.length,
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MinigameInks.of(context).muted,
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = min(constraints.maxWidth, constraints.maxHeight);
                return SizedBox(
                  width: side,
                  height: side,
                  child: BottleBoard(
                    seated: [
                      for (final p in seated)
                        BottleBoardPlayer(
                          id: p.id,
                          name: p.username,
                          avatarUrl: p.avatarUrl,
                          isMe: p.id == myId,
                        ),
                    ],
                    selectedId: (spinning || !revealed) ? null : selectedId,
                    angle: _currentAngle,
                  ),
                );
              },
            ),
          ),
        ),
        if (winner != null && !spinning && skeleton.bottleDare != null)
          _DareCard(
            winner: winner,
            dare: skeleton.bottleDare!,
            category: skeleton.bottleDareCategory,
            isMine: winner.id == myId,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: spinning
                ? VButton.emphasized(
                    label: l10n.minigamesBottleStop,
                    loading: _busy,
                    onPressed: () => _run(
                      ref
                          .read(
                            minigameGameStateProvider(
                              widget.sessionId,
                            ).notifier,
                          )
                          .stopBottle,
                    ),
                  )
                : VButton.emphasized(
                    label: l10n.minigamesBottleSpin,
                    loading: _busy,
                    onPressed: !enoughPlayers
                        ? null
                        : () => _run(
                            ref
                                .read(
                                  minigameGameStateProvider(
                                    widget.sessionId,
                                  ).notifier,
                                )
                                .spinBottle,
                          ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The reto the bottle handed out, tagged with its category.
class _DareCard extends StatelessWidget {
  const _DareCard({
    required this.winner,
    required this.dare,
    required this.category,
    required this.isMine,
  });

  final MinigameParticipant winner;
  final String dare;
  final String? category;
  final bool isMine;

  Color get _categoryColor => switch (category) {
    'picante' => AppColors.glowPink,
    'castigo' => AppColors.discoGold,
    'medio' => AppColors.discoViolet,
    _ => AppColors.mint,
  };

  String _categoryLabel(AppLocalizations l10n) => switch (category) {
    'picante' => l10n.minigamesBottleCategoryPicante,
    'castigo' => l10n.minigamesBottleCategoryCastigo,
    'medio' => l10n.minigamesBottleCategoryMedio,
    _ => l10n.minigamesBottleCategorySuave,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MinigameInks.of(context).surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMine
              ? _categoryColor.withValues(alpha: 0.9)
              : MinigameInks.of(context).border,
          width: isMine ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isMine ? l10n.minigamesBottleDareTitle : winner.username,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: MinigameInks.of(context).muted,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _categoryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _categoryColor.withValues(alpha: 0.7),
                  ),
                ),
                child: Text(
                  _categoryLabel(l10n),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _categoryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            dare,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: MinigameInks.of(context).primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
