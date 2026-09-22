import 'dart:math';

import 'package:flutter/material.dart';
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
class DrunkBottleScreen extends ConsumerWidget {
  const DrunkBottleScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        final winner = s.bottleSelectedId == null
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
  });

  final String sessionId;
  final List<MinigameParticipant> participants;
  final MinigameGameState state;

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

  /// Applies a server state: start the free spin, or decelerate onto the
  /// drawn angle. Guarded by `bottle_seq` so a re-delivery of the same row
  /// never restarts the animation.
  void _adopt(MinigameGameState state, {required bool animate}) {
    final skeleton = state.skeleton;
    if (skeleton.bottleSeq == _seenSeq) return;
    _seenSeq = skeleton.bottleSeq;

    if (skeleton.bottleSpinning) {
      _settle.stop();
      if (!_spin.isAnimating) _spin.repeat();
      return;
    }

    _spin.stop();
    final degrees = skeleton.bottleAngle;
    if (degrees == null) return;
    final target = degrees * pi / 180.0;

    if (!animate) {
      setState(() => _angle = target);
      return;
    }

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
    _settle.forward(from: 0);
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
    final winner = selectedId == null
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
              style: const TextStyle(
                color: AppColors.mutedStrong,
                fontSize: 14,
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
                    selectedId: spinning ? null : selectedId,
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

/// The pizza: one slice per player plus the bottle at the centre.
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
        final radius = min(constraints.maxWidth, constraints.maxHeight) / 2;
        final avatarRadius = radius * 0.66;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Slices.
            CustomPaint(
              size: Size.square(radius * 2),
              painter: _PizzaPainter(
                count: n,
                colors: _slice,
                selectedIndex: selectedIndex,
              ),
            ),
            // One avatar per slice, seated at the slice's middle.
            for (var i = 0; i < n; i++)
              Transform.translate(
                offset: Offset(
                  cos(i * step + step / 2 - pi / 2) * avatarRadius,
                  sin(i * step + step / 2 - pi / 2) * avatarRadius,
                ),
                child: _Seat(
                  participant: seated[i],
                  isMe: seated[i].id == myId,
                  isWinner: i == selectedIndex,
                ),
              ),
            // The bottle. Rotation 0 points at game angle 0 (straight up),
            // matching the server's sector maths.
            Transform.rotate(
              angle: angle,
              child: CustomPaint(
                size: Size(radius * 0.32, radius * 0.9),
                painter: _BottlePainter(),
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
  });

  final int count;
  final List<Color> colors;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = size.width / 2;
    final step = 2 * pi / count;

    for (var i = 0; i < count; i++) {
      // Canvas angles start at 3 o'clock; the game's 0 is 12 o'clock.
      final start = i * step - pi / 2;
      final isWinner = i == selectedIndex;
      final base = colors[i % colors.length];
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = isWinner
            ? base.withValues(alpha: 0.85)
            : base.withValues(alpha: 0.22);
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        start,
        step,
        true,
        paint,
      );
    }

    // Slice dividers.
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.discoBlack.withValues(alpha: 0.65);
    for (var i = 0; i < count; i++) {
      final a = i * step - pi / 2;
      canvas.drawLine(
        centre,
        centre + Offset(cos(a), sin(a)) * radius,
        divider,
      );
    }

    // Rim.
    canvas.drawCircle(
      centre,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_PizzaPainter old) =>
      old.count != count || old.selectedIndex != selectedIndex;
}

/// A simple bottle silhouette pointing up (cap at the top = the pointer).
class _BottlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Paint()..color = AppColors.white;
    final shade = Paint()..color = AppColors.discoSilver;

    // Body: a rounded rectangle over the bottom two thirds.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.34, w * 0.68, h * 0.62),
      Radius.circular(w * 0.24),
    );
    canvas.drawRRect(bodyRect, body);

    // Shoulders: taper from the body up to the neck.
    final shoulders = Path()
      ..moveTo(w * 0.16, h * 0.40)
      ..quadraticBezierTo(w * 0.5, h * 0.14, w * 0.84, h * 0.40)
      ..close();
    canvas.drawPath(shoulders, body);

    // Neck + cap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.10, w * 0.24, h * 0.18),
        Radius.circular(w * 0.06),
      ),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.34, h * 0.0, w * 0.32, h * 0.12),
        Radius.circular(w * 0.08),
      ),
      shade,
    );

    // Label band for a bit of depth.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.60, w * 0.68, h * 0.16),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = AppColors.muted.withValues(alpha: 0.55),
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
  });

  final MinigameParticipant participant;
  final bool isMe;
  final bool isWinner;

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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.discoBlack.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            participant.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isWinner ? AppColors.white : AppColors.softGray,
              fontSize: 11,
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
                style: const TextStyle(
                  color: AppColors.mutedStrong,
                  fontSize: 12,
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
                  style: TextStyle(
                    color: _categoryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            dare,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
