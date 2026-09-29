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
import 'package:samay/features/minigames/widgets/minigame_play_header.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

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
            : participants
                  .where((p) => p.id == s.bottleSelectedId)
                  .firstOrNull;
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

    return Scaffold(
      backgroundColor: AppColors.discoBlack,
      body: VHeaderBar(
        titleWidget: headerTitle,
        title: headerTitle == null ? gameNameLower : null,
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
    _spin = AnimationController(
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
    final midBuild = phase == SchedulerPhase.persistentCallbacks ||
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
    _settleTween = Tween<double>(begin: from, end: to).animate(
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
                    color: AppColors.mutedStrong,
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
                  child: _Pizza(
                    seated: seated,
                    myId: myId,
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
                            minigameGameStateProvider(widget.sessionId).notifier,
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
                                    minigameGameStateProvider(widget.sessionId)
                                        .notifier,
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

/// The table seen at an angle: the pizza is drawn as an ELLIPSE (the circle
/// foreshortened by cos(tilt)) sitting on a solid rim, so the board reads as
/// a real table instead of a flat wheel. Only the board is tilted — names and
/// avatars stay upright so they remain readable.
class _Pizza extends StatelessWidget {
  const _Pizza({
    required this.seated,
    required this.myId,
    required this.selectedId,
    required this.angle,
  });

  final List<MinigameParticipant> seated;
  final String? myId;
  final String? selectedId;
  final double angle;

  /// How far the table is tilted away from the viewer. Enough to read as
  /// perspective, shallow enough that the slices near the horizon do not
  /// collapse into slivers.
  static const double kTilt = 0.62;

  /// Vertical foreshortening of the board.
  static double get squash => cos(kTilt);

  /// Slice palette — the app's pastel set, cycled so neighbours differ.
  static const _slice = <Color>[
    AppColors.pastelRose,
    AppColors.pastelViolet,
    AppColors.pastelCyan,
    AppColors.pastelGold,
    AppColors.pastelMint,
    AppColors.pastelPeach,
  ];

  @override
  Widget build(BuildContext context) {
    final n = seated.length;
    if (n == 0) return const SizedBox.shrink();
    final step = 2 * pi / n;
    final selectedIndex = selectedId == null
        ? -1
        : seated.indexWhere((p) => p.id == selectedId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final radius =
            min(constraints.maxWidth, constraints.maxHeight / squash) / 2 * 0.94;
        final avatarRadius = radius * 0.74;
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(radius * 2, radius * 2 * squash + _PizzaPainter.kRim),
              painter: _PizzaPainter(
                count: n,
                colors: _slice,
                selectedIndex: selectedIndex,
                squash: squash,
              ),
            ),
            // One avatar per slice, seated on the ellipse at the slice's
            // middle. Kept upright on purpose: tilted text is unreadable.
            for (var i = 0; i < n; i++)
              Transform.translate(
                offset: Offset(
                  cos(i * step + step / 2 - pi / 2) * avatarRadius,
                  sin(i * step + step / 2 - pi / 2) * avatarRadius * squash,
                ),
                child: _Seat(
                  participant: seated[i],
                  isMe: seated[i].id == myId,
                  isWinner: i == selectedIndex,
                  maxLabelWidth: radius * 0.62,
                ),
              ),
            // The bottle lying on the table: squashed with the board, then
            // rotated to the server's angle.
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scaleByDouble(1.0, squash, 1.0, 1.0),
              child: Transform.rotate(
                angle: angle,
                child: CustomPaint(
                  size: Size(radius * 0.32, radius * 0.98),
                  painter: _BottlePainter(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PizzaPainter extends CustomPainter {
  _PizzaPainter({
    required this.count,
    required this.colors,
    required this.selectedIndex,
    required this.squash,
  });

  final int count;
  final List<Color> colors;
  final int selectedIndex;
  final double squash;

  /// Thickness of the table edge, in pixels.
  static const double kRim = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final centre = Offset(radius, (size.height - kRim) / 2);
    final board = Rect.fromCenter(
      center: centre,
      width: radius * 2,
      height: radius * 2 * squash,
    );
    final step = 2 * pi / count;

    // 1. The edge: the same ellipse pushed down in darker tones, so the board
    //    has a visible thickness instead of floating flat.
    canvas.drawOval(
      board.shift(const Offset(0, kRim)),
      Paint()..color = const Color(0xFF15131C),
    );
    canvas.drawOval(
      board.shift(const Offset(0, kRim * 0.5)),
      Paint()..color = const Color(0xFF241F30),
    );

    // 2. The slices.
    for (var i = 0; i < count; i++) {
      // Canvas angles start at 3 o'clock; the game's 0 is 12 o'clock.
      final start = i * step - pi / 2;
      final isWinner = i == selectedIndex;
      final base = colors[i % colors.length];
      if (isWinner) {
        // A soft bloom under the winning slice so the reveal reads from
        // across a table.
        canvas.drawArc(
          board,
          start,
          step,
          true,
          Paint()
            ..color = base.withValues(alpha: 0.40)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
        );
      }
      canvas.drawArc(
        board,
        start,
        step,
        true,
        Paint()
          ..style = PaintingStyle.fill
          ..color = isWinner
              ? base.withValues(alpha: 0.92)
              : base.withValues(alpha: 0.20),
      );
    }

    // 3. Slice dividers.
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.discoBlack.withValues(alpha: 0.55);
    for (var i = 0; i < count; i++) {
      final a = i * step - pi / 2;
      canvas.drawLine(
        centre,
        centre + Offset(cos(a) * radius, sin(a) * radius * squash),
        divider,
      );
    }

    // 4. Rim light around the board.
    canvas.drawOval(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.white.withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(_PizzaPainter old) =>
      old.count != count ||
      old.selectedIndex != selectedIndex ||
      old.squash != squash;
}

/// A bottle silhouette pointing up, shaded so it reads as a solid object
/// resting on the table rather than a flat cut-out. The cap end is the
/// pointer the sector maths uses.
class _BottlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Contact shadow: the bottle sits ON the board.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.02, h * 0.34, w * 1.06, h * 0.68),
      Paint()
        ..color = AppColors.discoBlack.withValues(alpha: 0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Glass: a left-to-right gradient gives the cylinder its roundness.
    final glass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFFB3BAC2),
          Color(0xFFFFFFFF),
          Color(0xFFF2F4F6),
          Color(0xFF9AA3AC),
        ],
        stops: [0.0, 0.30, 0.58, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final body = Path()
      ..moveTo(w * 0.16, h * 0.46)
      ..quadraticBezierTo(w * 0.16, h * 0.99, w * 0.50, h * 0.99)
      ..quadraticBezierTo(w * 0.84, h * 0.99, w * 0.84, h * 0.46)
      // Shoulders taper into the neck.
      ..quadraticBezierTo(w * 0.81, h * 0.25, w * 0.63, h * 0.19)
      ..lineTo(w * 0.37, h * 0.19)
      ..quadraticBezierTo(w * 0.19, h * 0.25, w * 0.16, h * 0.46)
      ..close();
    canvas.drawPath(body, glass);

    // Neck + cap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.08, w * 0.24, h * 0.14),
        Radius.circular(w * 0.06),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, 0, w * 0.36, h * 0.10),
        Radius.circular(w * 0.09),
      ),
      Paint()..color = AppColors.discoSilver,
    );

    // Specular highlight down the left side.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.32, w * 0.07, h * 0.54),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = AppColors.white.withValues(alpha: 0.80),
    );

    // Label band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.64, w * 0.68, h * 0.17),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = const Color(0xFF6B6776),
    );
  }

  @override
  bool shouldRepaint(_BottlePainter old) => false;
}

/// One player seated on their slice.
class _Seat extends StatelessWidget {
  const _Seat({
    required this.participant,
    required this.isMe,
    required this.isWinner,
    required this.maxLabelWidth,
  });

  final MinigameParticipant participant;
  final bool isMe;
  final bool isWinner;

  /// Cap for the name tag, so a long username stays on the board instead of
  /// running off the table (and, near the edges, off the screen).
  final double maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    final initials =
        participant.username.isEmpty ? '?' : participant.username[0];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.discoBlack,
            border: Border.all(
              color: isWinner
                  ? AppColors.white
                  : isMe
                      ? AppColors.white.withValues(alpha: 0.45)
                      : Colors.transparent,
              width: isWinner ? 3 : 2,
            ),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: AppColors.white.withValues(alpha: 0.5),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: ProfileAvatar(
            size: isWinner ? 50 : 42,
            initials: initials,
            imageUrl: participant.avatarUrl,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          constraints: BoxConstraints(maxWidth: maxLabelWidth),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.discoBlack.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            participant.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isWinner ? AppColors.white : AppColors.softGray,
                  fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
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
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMine
              ? _categoryColor.withValues(alpha: 0.9)
              : AppColors.border,
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
                      color: AppColors.mutedStrong,
                      letterSpacing: 0.6,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
