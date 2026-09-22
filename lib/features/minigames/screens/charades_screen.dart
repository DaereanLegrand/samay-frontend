import 'dart:async';

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
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The word categories a turn can be drawn from — wire value (as seeded in
/// `minigame_prompts.category`) plus its localized label. A null wire value
/// means "every category".
const List<({String? wire, String labelKey})> kCharadesCategories = [
  (wire: null, labelKey: 'todas'),
  (wire: 'peliculas', labelKey: 'peliculas'),
  (wire: 'animales', labelKey: 'animales'),
  (wire: 'acciones', labelKey: 'acciones'),
  (wire: 'objetos', labelKey: 'objetos'),
  (wire: 'famosos', labelKey: 'famosos'),
  (wire: 'fiesta', labelKey: 'fiesta'),
];

/// Turn lengths offered by the starter.
const List<int> kCharadesDurations = [30, 60, 90];

String _categoryLabel(AppLocalizations l10n, String key) => switch (key) {
      'peliculas' => l10n.charadesCategoryPeliculas,
      'animales' => l10n.charadesCategoryAnimales,
      'acciones' => l10n.charadesCategoryAcciones,
      'objetos' => l10n.charadesCategoryObjetos,
      'famosos' => l10n.charadesCategoryFamosos,
      'fiesta' => l10n.charadesCategoryFiesta,
      _ => l10n.charadesCategoryAll,
    };

/// Charadas play screen (211_minigame_charades).
///
/// One player holds the phone on their forehead with the screen facing the
/// room; the room acts the word out and they guess. The turn runs against a
/// SERVER-anchored deadline so every device shows the same clock, and the
/// word/score/timer stream to the whole table over the game-state realtime
/// channel — spectators see exactly what the player is holding up.
class CharadesScreen extends ConsumerWidget {
  const CharadesScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final gameState = ref.watch(minigameGameStateProvider(sessionId));
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'] as String?;
    final roster =
        ref.watch(minigameParticipantsProvider(sessionId)).valueOrNull ??
        const <MinigameParticipant>[];
    final gameNameLower = minigameGameNameLower(
      l10n,
      MinigameType.charades.value,
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
        if (s.charadesIsPlaying) {
          final displayName =
              roster
                  .where((p) => p.id == s.charadesTurnId)
                  .map((p) => p.username)
                  .firstOrNull ??
              '';
          return minigameTurnTitle(
            isMine: s.charadesIsMyTurn(myId),
            displayName: displayName,
            secondary: gameNameLower,
            l10n: l10n,
          );
        }
        if (s.charadesPhase == 'summary') {
          return minigameStatusTitle(
            word: l10n.charadesTimeUp,
            secondary: gameNameLower,
            l10n: l10n,
          );
        }
        return null;
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
          data: (state) => _CharadesBody(sessionId: sessionId, state: state),
        ),
      ),
    );
  }
}

class _CharadesBody extends ConsumerStatefulWidget {
  const _CharadesBody({required this.sessionId, required this.state});

  final String sessionId;
  final MinigameGameState state;

  @override
  ConsumerState<_CharadesBody> createState() => _CharadesBodyState();
}

class _CharadesBodyState extends ConsumerState<_CharadesBody> {
  Timer? _tick;
  bool _busy = false;
  bool _closing = false;

  /// Set from the summary's "que juegue otro" so the starter comes back
  /// without waiting for a server round trip.
  bool _forceStarter = false;

  String? _category;
  int _seconds = 60;

  @override
  void initState() {
    super.initState();
    // One repaint a second drives the countdown; the deadline itself comes
    // from the server.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _autoCloseIfExpired();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final endsAt = widget.state.skeleton.charadesEndsAt;
    if (endsAt == null) return Duration.zero;
    final left = endsAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// When the clock runs out the turn has to close so the score lands and the
  /// table moves on. The player holding the phone closes their own turn;
  /// anyone else only steps in once the deadline has clearly passed (the RPC
  /// enforces the same rule).
  void _autoCloseIfExpired() {
    final skeleton = widget.state.skeleton;
    if (!skeleton.charadesIsPlaying || _closing || _busy) return;
    if (_remaining > Duration.zero) return;
    final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (!skeleton.charadesIsMyTurn(myId as String?)) return;
    _closing = true;
    unawaited(
      _run(
        ref
            .read(minigameGameStateProvider(widget.sessionId).notifier)
            .endCharadesTurn,
      ).whenComplete(() => _closing = false),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'] as String?;
    final roster =
        ref.watch(minigameParticipantsProvider(widget.sessionId)).valueOrNull ??
        const <MinigameParticipant>[];
    final skeleton = widget.state.skeleton;

    if (skeleton.charadesIsPlaying && !_forceStarter) {
      return _PlayingView(
        skeleton: skeleton,
        roster: roster,
        isMine: skeleton.charadesIsMyTurn(myId),
        remaining: _remaining,
        busy: _busy,
        onHit: () => _run(
          () => ref
              .read(minigameGameStateProvider(widget.sessionId).notifier)
              .charadesAnswer(correct: true),
        ),
        onPass: () => _run(
          () => ref
              .read(minigameGameStateProvider(widget.sessionId).notifier)
              .charadesAnswer(correct: false),
        ),
        onFinish: () => _run(
          ref
              .read(minigameGameStateProvider(widget.sessionId).notifier)
              .endCharadesTurn,
        ),
      );
    }

    if (skeleton.charadesPhase == 'summary' && !_forceStarter) {
      return _SummaryView(
        skeleton: skeleton,
        roster: roster,
        onNext: () => setState(() => _forceStarter = true),
      );
    }

    return _StarterView(
      l10n: l10n,
      roster: roster,
      skeleton: skeleton,
      category: _category,
      seconds: _seconds,
      busy: _busy,
      onCategory: (value) => setState(() => _category = value),
      onSeconds: (value) => setState(() => _seconds = value),
      onStart: () {
        setState(() => _forceStarter = false);
        _run(
          () => ref
              .read(minigameGameStateProvider(widget.sessionId).notifier)
              .startCharadesTurn(category: _category, seconds: _seconds),
        );
      },
    );
  }
}

/// Rules + category + duration + start. What a player sees before taking the
/// phone, and what the table falls back to between turns.
class _StarterView extends StatelessWidget {
  const _StarterView({
    required this.l10n,
    required this.roster,
    required this.skeleton,
    required this.category,
    required this.seconds,
    required this.busy,
    required this.onCategory,
    required this.onSeconds,
    required this.onStart,
  });

  final AppLocalizations l10n;
  final List<MinigameParticipant> roster;
  final GameTurnSkeleton skeleton;
  final String? category;
  final int seconds;
  final bool busy;
  final ValueChanged<String?> onCategory;
  final ValueChanged<int> onSeconds;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.theater_comedy,
                    size: 18,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.charadesRulesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Rule(number: 1, text: l10n.charadesRule1),
              _Rule(number: 2, text: l10n.charadesRule2),
              _Rule(number: 3, text: l10n.charadesRule3),
              _Rule(number: 4, text: l10n.charadesRule4),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.charadesPickCategory.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final c in kCharadesCategories)
              // VChip is a FilterChip: it owns its tap, so the selection has
              // to ride onSelected (an outer GestureDetector never sees it).
              VChip(
                label: _categoryLabel(l10n, c.labelKey),
                selected: category == c.wire,
                onSelected: () => onCategory(c.wire),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.charadesDuration.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final d in kCharadesDurations)
              VChip(
                label: l10n.charadesSeconds(d),
                selected: seconds == d,
                onSelected: () => onSeconds(d),
              ),
          ],
        ),
        if (skeleton.charadesScores.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Scoreboard(scores: skeleton.charadesScores, roster: roster),
        ],
        const SizedBox(height: AppSpacing.xl),
        VButton.emphasized(
          label: l10n.charadesStartTurn,
          loading: busy,
          onPressed: onStart,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceAlt,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.softGray,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The running turn: the word big enough for the room to read across a table,
/// the countdown, and the two calls the guesser makes.
class _PlayingView extends StatelessWidget {
  const _PlayingView({
    required this.skeleton,
    required this.roster,
    required this.isMine,
    required this.remaining,
    required this.busy,
    required this.onHit,
    required this.onPass,
    required this.onFinish,
  });

  final GameTurnSkeleton skeleton;
  final List<MinigameParticipant> roster;
  final bool isMine;
  final Duration remaining;
  final bool busy;
  final VoidCallback onHit;
  final VoidCallback onPass;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = remaining.inSeconds;
    final total = skeleton.charadesSeconds;
    final fraction = total <= 0 ? 0.0 : (seconds / total).clamp(0.0, 1.0);
    final urgent = seconds <= 10;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              // Countdown: the number plus a bar that drains with it.
              Text(
                '$seconds',
                style: TextStyle(
                  color: urgent ? AppColors.glowPink : AppColors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 5,
                  backgroundColor: AppColors.hairline,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    urgent ? AppColors.glowPink : AppColors.white,
                  ),
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
                  skeleton.charadesWord ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Tally(
                label: l10n.charadesHit,
                value: skeleton.charadesHits,
                color: AppColors.mint,
              ),
              const SizedBox(width: AppSpacing.xl),
              _Tally(
                label: l10n.charadesPass,
                value: skeleton.charadesMisses,
                color: AppColors.mutedStrong,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (isMine)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 64,
                        child: VButton.outlined(
                          label: l10n.charadesPass,
                          onPressed: busy ? null : onPass,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SizedBox(
                        height: 64,
                        child: VButton.emphasized(
                          label: l10n.charadesHit,
                          onPressed: busy ? null : onHit,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: busy ? null : onFinish,
                  child: Text(
                    l10n.charadesFinish,
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedStrong, fontSize: 11),
        ),
      ],
    );
  }
}

/// What the turn produced: the score, every word it went through, and the
/// running scoreboard.
class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.skeleton,
    required this.roster,
    required this.onNext,
  });

  final GameTurnSkeleton skeleton;
  final List<MinigameParticipant> roster;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.charadesTimeUp,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.charadesTurnScore(skeleton.charadesHits),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedStrong, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (skeleton.charadesLog.isNotEmpty)
          VCard(
            child: Column(
              children: [
                for (final entry in skeleton.charadesLog)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          entry.correct ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: entry.correct
                              ? AppColors.mint
                              : AppColors.muted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            entry.word,
                            style: TextStyle(
                              color: entry.correct
                                  ? AppColors.white
                                  : AppColors.mutedStrong,
                              fontSize: 14,
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
        if (skeleton.charadesScores.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Scoreboard(scores: skeleton.charadesScores, roster: roster),
        ],
        const SizedBox(height: AppSpacing.xl),
        VButton.emphasized(label: l10n.charadesNextPlayer, onPressed: onNext),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Session scoreboard, best first.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.scores, required this.roster});

  final Map<String, int> scores;
  final List<MinigameParticipant> roster;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.charadesScoreboard.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        VCard(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: AppColors.mutedStrong,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          roster
                                  .where((p) => p.id == rows[i].key)
                                  .map((p) => p.username)
                                  .firstOrNull ??
                              '—',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '${rows[i].value}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
