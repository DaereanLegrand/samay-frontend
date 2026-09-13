import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Botella (drunk bottle) play screen (208_minigame_drunk_bottle).
///
/// MVP scope: the roster renders in a circle, a bottle spins in the middle
/// and any participant can stop it (host-only gating is a follow-up) — the
/// spin/stop result rides `minigame_game_state.state` (`bottle_spinning`,
/// `bottle_selected_id`, `bottle_seq`) and streams to the whole lobby over
/// the same realtime channel the ready-toggle uses, so every viewer sees the
/// same stop result live.
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

    return Scaffold(
      body: VHeaderBar(
        title: l10n.minigamesGameDrunkBottle,
        child: gameState.when(
          loading: () => const VLoadingView(),
          error: (e, _) => Center(child: Text(e.toAppError().message)),
          data: (_) => participants.isEmpty
              ? const VLoadingView()
              : _BottleBoard(sessionId: sessionId, participants: participants),
        ),
      ),
    );
  }
}

class _BottleBoard extends ConsumerStatefulWidget {
  const _BottleBoard({required this.sessionId, required this.participants});

  final String sessionId;
  final List<MinigameParticipant> participants;

  @override
  ConsumerState<_BottleBoard> createState() => _BottleBoardState();
}

class _BottleBoardState extends ConsumerState<_BottleBoard>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late AnimationController _settleController;
  Animation<double>? _settleAnimation;

  int _lastSeq = -1;
  bool _wasSpinning = false;
  double _heldAngle = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _settleController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _settleController.dispose();
    super.dispose();
  }

  double _angleFor(int index, int count) => index * (2 * pi / count);

  void _syncFromState(MinigameGameState state) {
    final seq = state.skeleton.bottleSeq;
    final spinning = state.skeleton.bottleSpinning;
    if (seq == _lastSeq && spinning == _wasSpinning) return;
    _lastSeq = seq;
    _wasSpinning = spinning;

    if (spinning) {
      _settleController.stop();
      _spinController.repeat();
      return;
    }

    // Just stopped: settle from wherever the spin currently is onto the
    // selected participant's angle, with a couple of extra turns so the
    // stop reads as a deceleration rather than a snap.
    final selectedId = state.skeleton.bottleSelectedId;
    final index = selectedId == null
        ? -1
        : widget.participants.indexWhere((p) => p.id == selectedId);
    final target = index < 0
        ? _heldAngle
        : _angleFor(index, widget.participants.length);
    final current = _spinController.isAnimating
        ? _heldAngle + _spinController.value * 2 * pi
        : _heldAngle;
    _spinController.stop();
    final normalizedCurrent = current % (2 * pi);
    final end = normalizedCurrent - (normalizedCurrent % (2 * pi)) +
        target +
        2 * 2 * pi;
    _settleController.dispose();
    _settleController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _settleAnimation = Tween<double>(begin: current, end: end).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOut),
    )..addListener(() {
        setState(() => _heldAngle = _settleAnimation!.value);
      });
    _settleController.forward(from: 0);
  }

  Future<void> _spin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .setBottleSpin(spinning: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final rng = Random();
      final winner = widget.participants[rng.nextInt(widget.participants.length)];
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .setBottleSpin(spinning: false, selectedId: winner.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final gameState = ref.watch(minigameGameStateProvider(widget.sessionId));

    ref.listen<AsyncValue<MinigameGameState>>(
      minigameGameStateProvider(widget.sessionId),
      (previous, next) {
        final state = next.valueOrNull;
        if (state != null) _syncFromState(state);
      },
    );
    final initial = gameState.valueOrNull;
    if (initial != null && _lastSeq == -1) {
      // First build: adopt the current server state without animating.
      _wasSpinning = initial.skeleton.bottleSpinning;
      _lastSeq = initial.skeleton.bottleSeq;
      if (_wasSpinning) _spinController.repeat();
      final selectedId = initial.skeleton.bottleSelectedId;
      final index = selectedId == null
          ? -1
          : widget.participants.indexWhere((p) => p.id == selectedId);
      if (index >= 0) _heldAngle = _angleFor(index, widget.participants.length);
    }

    final spinning = gameState.valueOrNull?.skeleton.bottleSpinning ?? false;
    final selectedId = gameState.valueOrNull?.skeleton.bottleSelectedId;
    final count = widget.participants.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight) - 32;
        final radius = side / 2 - 44;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  _PlayerBadge(
                    participant: widget.participants[i],
                    isMe: widget.participants[i].id == myId,
                    isSelected:
                        !spinning && widget.participants[i].id == selectedId,
                    angle: _angleFor(i, count) - pi / 2,
                    radius: radius,
                  ),
                AnimatedBuilder(
                  animation: _spinController,
                  builder: (context, _) {
                    final angle = spinning
                        ? _heldAngle + _spinController.value * 2 * pi
                        : _heldAngle;
                    return Transform.rotate(
                      angle: angle,
                      child: const Icon(
                        Icons.sports_bar,
                        size: 72,
                        color: AppColors.white,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    ).let((board) {
      return Column(
        children: [
          Expanded(child: board),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: spinning
                      ? VButton.emphasized(
                          label: l10n.minigamesBottleStop,
                          loading: _busy,
                          onPressed: _stop,
                        )
                      : VButton.emphasized(
                          label: l10n.minigamesBottleSpin,
                          loading: _busy,
                          onPressed: count < 2 ? null : _spin,
                        ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.participant,
    required this.isMe,
    required this.isSelected,
    required this.angle,
    required this.radius,
  });

  final MinigameParticipant participant;
  final bool isMe;
  final bool isSelected;
  final double angle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final offset = Offset(cos(angle), sin(angle)) * radius;
    final initials = participant.username.isEmpty ? '?' : participant.username[0];
    return Transform.translate(
      offset: offset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.white : Colors.transparent,
                width: 3,
              ),
            ),
            child: ProfileAvatar(
              size: isMe ? 52 : 44,
              initials: initials,
              imageUrl: participant.avatarUrl,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            participant.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
