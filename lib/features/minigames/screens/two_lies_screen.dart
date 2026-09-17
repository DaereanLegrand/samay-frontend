import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/logic/two_lies_one_truth.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/minigame_shared_widgets.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// "2 Mentiras, 1 Verdad" play screen (206_minigame_two_lies_one_truth).
///
/// Flow:
/// 1. The server randomly selects the subject.
/// 2. The SUBJECT writes 3 statements about themselves (2 lies, 1 truth) and
///    marks which one is the truth. The payload is encrypted with the round
///    key via [MinigameCipher] and sent via `submit_minigame_answer`.
/// 3. The OTHER PARTICIPANTS decrypt the statements and vote on which one they
///    believe is the truth (`vote_0`, `vote_1`, `vote_2`) or tap Pasar.
/// 4. Once all participants have voted, the round auto-advances.
class TwoLiesScreen extends ConsumerWidget {
  const TwoLiesScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final game = ref.watch(minigameGameStateProvider(sessionId));
    final session = ref.watch(sessionStatusProvider(sessionId));
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final participantIds =
        (session.valueOrNull?['participants'] as List?)?.cast<String?>() ??
            const [];
    final isCreator = participantIds.isNotEmpty && participantIds.first == myId;
    final roster =
        ref.watch(minigameParticipantsProvider(sessionId)).valueOrNull ??
            const <MinigameParticipant>[];
    final aliases = ref.watch(minigameAliasesProvider(sessionId)).valueOrNull;

    return Scaffold(
      body: VHeaderBar(
        title: session.valueOrNull == null
            ? l10n.minigamesGameTwoLiesOneTruth.toLowerCase()
            : minigameGameNameLower(
                l10n,
                session.valueOrNull!['game_type'] as String?,
              ),
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.minigamesComplete,
              onPressed: () => _confirmComplete(context, ref, l10n),
            ),
        ],
        child: game.when(
          loading: () => const VLoadingView(),
          error: (error, _) => ErrorView(
            message: l10n.minigamesErrorLoadGame,
            onRetry: () => ref.invalidate(minigameGameStateProvider(sessionId)),
          ),
          data: (state) {
            if (state.isFinished) {
              return MinigameFinishedLeaderboard(sessionId: sessionId);
            }

            final skeleton = state.skeleton;
            final subjectId = skeleton.subjectId;
            final isMyTurn = subjectId != null && subjectId == myId;
            final roundTarget = skeleton.roundTarget;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                if (roundTarget != null &&
                    skeleton.playMode == MinigamePlayMode.byTurns) ...[
                  Text(
                    l10n.minigamesRoundCounter(
                      skeleton.round + 1,
                      roundTarget,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                VDisplayText(
                  text: minigameSubjectLabel(
                    l10n,
                    minigameResolveDisplayName(
                      subjectId,
                      roster,
                      aliases,
                      skeleton,
                      l10n,
                    ),
                  ),
                  size: 28,
                ),
                const SizedBox(height: AppSpacing.md),
                isMyTurn
                    ? (skeleton.answer == null
                        ? _SubjectEditorCard(
                            sessionId: sessionId,
                            state: state,
                            l10n: l10n,
                          )
                        : _SubjectWaitingVotesCard(
                            sessionId: sessionId,
                            state: state,
                            l10n: l10n,
                          ))
                    : (skeleton.answer == null
                        ? _WaitingForSubjectCard(
                            sessionId: sessionId,
                            subjectName: minigameResolveDisplayName(
                              subjectId,
                              roster,
                              aliases,
                              skeleton,
                              l10n,
                            ),
                            l10n: l10n,
                          )
                        : _VoterGuessCard(
                            sessionId: sessionId,
                            state: state,
                            l10n: l10n,
                            myId: myId,
                          )),
                const SizedBox(height: AppSpacing.lg),
                if (skeleton.anonymous) ...[
                  MinigameAliasEditor(sessionId: sessionId, state: state),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmComplete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.minigamesCompleteConfirmTitle),
        content: Text(l10n.minigamesCompleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.minigamesComplete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(minigameGameStateProvider(sessionId).notifier).finish();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }
}

/// The subject's statement input card: 3 inputs + a truth index selector.
class _SubjectEditorCard extends ConsumerStatefulWidget {
  const _SubjectEditorCard({
    required this.sessionId,
    required this.state,
    required this.l10n,
  });

  final String sessionId;
  final MinigameGameState state;
  final AppLocalizations l10n;

  @override
  ConsumerState<_SubjectEditorCard> createState() => _SubjectEditorCardState();
}

class _SubjectEditorCardState extends ConsumerState<_SubjectEditorCard> {
  final _controller0 = TextEditingController();
  final _controller1 = TextEditingController();
  final _controller2 = TextEditingController();
  int? _selectedTruthIndex;
  bool _submitting = false;

  @override
  void dispose() {
    _controller0.dispose();
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.l10n.minigamesTwoLiesInstructions,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildStatementField(0, _controller0),
            const SizedBox(height: AppSpacing.md),
            _buildStatementField(1, _controller1),
            const SizedBox(height: AppSpacing.md),
            _buildStatementField(2, _controller2),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: VButton.emphasized(
                    label: widget.l10n.minigamesTwoLiesSubmitStatements,
                    loading: _submitting,
                    onPressed: _submitting ? null : _submit,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: VButton.outlined(
                    label: widget.l10n.minigamesPasar,
                    onPressed: _submitting ? null : _pasar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatementField(int index, TextEditingController controller) {
    final isTruth = _selectedTruthIndex == index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.l10n.minigamesTwoLiesStatementNumber(index + 1),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            InkWell(
              onTap: () => setState(() => _selectedTruthIndex = index),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTruth
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: isTruth ? AppColors.white : AppColors.mutedStrong,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      widget.l10n.minigamesTwoLiesMarkTruth,
                      style: TextStyle(
                        fontSize: 12,
                        color: isTruth ? AppColors.white : AppColors.mutedStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        VInput(
          label: widget.l10n.minigamesTwoLiesStatementPlaceholder,
          controller: controller,
          maxLines: 2,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final t0 = _controller0.text.trim();
    final t1 = _controller1.text.trim();
    final t2 = _controller2.text.trim();

    if (t0.isEmpty || t1.isEmpty || t2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.minigamesTwoLiesFillAllError)),
      );
      return;
    }

    if (_selectedTruthIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.minigamesTwoLiesSelectTruthError)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final round = widget.state.skeleton.round;
      final payload = TwoLiesPayload(
        statements: [
          TwoLiesStatement(index: 0, text: t0, isTruth: _selectedTruthIndex == 0),
          TwoLiesStatement(index: 1, text: t1, isTruth: _selectedTruthIndex == 1),
          TwoLiesStatement(index: 2, text: t2, isTruth: _selectedTruthIndex == 2),
        ],
        truthIndex: _selectedTruthIndex!,
      );

      final cipher = ref.read(minigameCipherProvider(widget.sessionId));
      final textCipher = await cipher.encryptAnswerText(payload.encode(), round);

      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .submitAnswer(answerCiphertext: textCipher);
    } catch (e, st) {
      AppLogger.instance.warn('TwoLiesScreen: error submitting statements: $e', '$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pasar() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .pasar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// Card shown to the subject after submitting, showing their statements and vote tally.
class _SubjectWaitingVotesCard extends ConsumerStatefulWidget {
  const _SubjectWaitingVotesCard({
    required this.sessionId,
    required this.state,
    required this.l10n,
  });

  final String sessionId;
  final MinigameGameState state;
  final AppLocalizations l10n;

  @override
  ConsumerState<_SubjectWaitingVotesCard> createState() =>
      _SubjectWaitingVotesCardState();
}

class _SubjectWaitingVotesCardState
    extends ConsumerState<_SubjectWaitingVotesCard> {
  TwoLiesPayload? _decryptedPayload;

  @override
  void initState() {
    super.initState();
    _decrypt();
  }

  @override
  void didUpdateWidget(covariant _SubjectWaitingVotesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.skeleton.answer?.answerCiphertext !=
        widget.state.skeleton.answer?.answerCiphertext) {
      _decrypt();
    }
  }

  Future<void> _decrypt() async {
    final ciphertext = widget.state.skeleton.answer?.answerCiphertext;
    if (ciphertext == null || ciphertext.isEmpty) return;
    try {
      final cipher = ref.read(minigameCipherProvider(widget.sessionId));
      final raw = await cipher.decryptAnswerText(
        ciphertext,
        widget.state.skeleton.round,
      );
      if (mounted) {
        setState(() => _decryptedPayload = TwoLiesPayload.tryDecode(raw));
      }
    } catch (e, st) {
      AppLogger.instance.warn('TwoLiesScreen: error decrypting own statements: $e', '$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final skeleton = widget.state.skeleton;
    final subjectId = skeleton.subjectId ?? '';
    final voteCount = skeleton.reactionCounts[subjectId] ?? 0;
    final passCount = skeleton.reactionPassCount(subjectId);
    final totalReacted = voteCount + passCount;
    final totalParticipants =
        (ref.watch(sessionStatusProvider(widget.sessionId)).valueOrNull
                    ?['participants'] as List?)
                ?.length ??
            1;
    final requiredVotes = (totalParticipants - 1).clamp(1, 999);

    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.l10n.minigamesTwoLiesWaitingVotes(totalReacted, requiredVotes),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_decryptedPayload != null)
              for (final s in _decryptedPayload!.statements) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: s.isTruth
                        ? AppColors.surfaceAlt
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: s.isTruth ? AppColors.white : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      VChip(
                        label: s.isTruth
                            ? widget.l10n.minigamesTwoLiesTruthBadge
                            : widget.l10n.minigamesTwoLiesLieBadge,
                        selected: s.isTruth,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          s.text,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// Card shown to non-subjects while the subject is writing their 3 statements.
class _WaitingForSubjectCard extends StatelessWidget {
  const _WaitingForSubjectCard({
    required this.sessionId,
    required this.subjectName,
    required this.l10n,
  });

  final String sessionId;
  final String subjectName;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.minigamesTwoLiesWaitingSubject(subjectName),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card shown to voters: decrypts statements and lets them vote for the truth.
class _VoterGuessCard extends ConsumerStatefulWidget {
  const _VoterGuessCard({
    required this.sessionId,
    required this.state,
    required this.l10n,
    required this.myId,
  });

  final String sessionId;
  final MinigameGameState state;
  final AppLocalizations l10n;
  final String? myId;

  @override
  ConsumerState<_VoterGuessCard> createState() => _VoterGuessCardState();
}

class _VoterGuessCardState extends ConsumerState<_VoterGuessCard> {
  TwoLiesPayload? _payload;
  int? _selectedVoteIndex;
  int? _votedIndex;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _decrypt();
  }

  @override
  void didUpdateWidget(covariant _VoterGuessCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.skeleton.answer?.answerCiphertext !=
            widget.state.skeleton.answer?.answerCiphertext ||
        oldWidget.state.skeleton.round != widget.state.skeleton.round) {
      setState(() {
        _votedIndex = null;
        _selectedVoteIndex = null;
      });
      _decrypt();
    }
  }

  Future<void> _decrypt() async {
    final ciphertext = widget.state.skeleton.answer?.answerCiphertext;
    if (ciphertext == null || ciphertext.isEmpty) return;
    try {
      final cipher = ref.read(minigameCipherProvider(widget.sessionId));
      final raw = await cipher.decryptAnswerText(
        ciphertext,
        widget.state.skeleton.round,
      );
      if (mounted) {
        setState(() => _payload = TwoLiesPayload.tryDecode(raw));
      }
    } catch (e, st) {
      AppLogger.instance.warn('TwoLiesScreen: error decrypting statements: $e', '$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_payload == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final hasVoted = _votedIndex != null;

    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.l10n.minigamesTwoLiesGuessPrompt,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < _payload!.statements.length; i++) ...[
              _buildStatementOption(i, _payload!.statements[i], hasVoted),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            if (!hasVoted) ...[
              VButton.emphasized(
                label: widget.l10n.minigamesTwoLiesVoteConfirm,
                loading: _submitting,
                onPressed: _selectedVoteIndex == null || _submitting
                    ? null
                    : _submitVote,
              ),
              const SizedBox(height: AppSpacing.sm),
              VButton.outlined(
                label: widget.l10n.minigamesPasar,
                onPressed: _submitting ? null : _pasar,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  widget.l10n.minigamesTwoLiesVoteConfirmed,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatementOption(
    int index,
    TwoLiesStatement statement,
    bool hasVoted,
  ) {
    final isSelected = _selectedVoteIndex == index;
    final isMyVote = _votedIndex == index;

    return InkWell(
      onTap: hasVoted
          ? null
          : () => setState(() => _selectedVoteIndex = index),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected || isMyVote
              ? AppColors.surfaceAlt
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isMyVote
                ? AppColors.white
                : (isSelected ? AppColors.white : AppColors.border),
            width: isSelected || isMyVote ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isSelected || isMyVote
                  ? AppColors.white
                  : AppColors.mutedStrong,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isSelected || isMyVote
                      ? AppColors.discoBlack
                      : AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                statement.text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitVote() async {
    if (_selectedVoteIndex == null) return;
    setState(() => _submitting = true);
    final index = _selectedVoteIndex!;
    final kind = switch (index) {
      0 => ReactionKind.vote0,
      1 => ReactionKind.vote1,
      _ => ReactionKind.vote2,
    };
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .react(kind);
      if (mounted) {
        setState(() {
          _votedIndex = index;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pasar() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .react(ReactionKind.pass);
      if (mounted) {
        setState(() {
          _votedIndex = -1; // marked as passed
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
