import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/logic/two_lies_one_truth.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/minigame_play_header.dart';
import 'package:samay/features/minigames/widgets/minigame_session_surface.dart';
import 'package:samay/features/minigames/widgets/minigame_rules_sheet.dart';
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
    final gameNameLower = session.valueOrNull == null
        ? l10n.minigamesGameTwoLiesOneTruth.toLowerCase()
        : minigameGameNameLower(
            l10n,
            session.valueOrNull!['game_type'] as String?,
          );

    // The finished match is rendered full-bleed: the leaderboard centers on the
    // WHOLE viewport and the floating back arrow is the only header, so nothing
    // eats into the vertical centering. The creator's "complete" action is
    // pointless once the match is already settled, so it is dropped here.
    if (game.valueOrNull?.isFinished ?? false) {
      return MinigameSessionSurface(
        sessionId: sessionId,
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              _TwoLiesFinishedBody(sessionId: sessionId),
              Align(
                alignment: Alignment.topLeft,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top:
                          VHeaderMetrics.headerOuterPad +
                          VHeaderMetrics.heroTopPad(
                            MediaQuery.paddingOf(context).top,
                          ),
                      left: AppSpacing.screenHorizontal,
                    ),
                    child: const SizedBox(
                      height: VHeaderMetrics.titleRowHeight,
                      width: double.infinity,
                      child: VHeaderTitleRow(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final headerTitle = game.when(
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
        final secondary = minigameHeaderSecondary(s, gameNameLower, l10n);
        if (state.isFinished) {
          return minigameStatusTitle(
            word: l10n.minigamesBarLeaderboard,
            secondary: secondary,
            l10n: l10n,
          );
        }
        if (s.phase != MinigamePhase.playing) return null;
        final name = minigameResolveDisplayName(
          s.subjectId,
          roster,
          aliases,
          s,
          l10n,
        );
        return minigameTurnTitle(
          isMine: s.subjectId != null && s.subjectId == myId,
          displayName: name,
          secondary: secondary,
          l10n: l10n,
        );
      },
    );

    return MinigameSessionSurface(
      sessionId: sessionId,
      child: Scaffold(
        body: VHeaderBar(
          titleWidget: headerTitle,
          title: headerTitle == null ? gameNameLower : null,
          actions: [
            const MinigameRulesButton(type: MinigameType.twoLiesOneTruth),
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
              onRetry: () =>
                  ref.invalidate(minigameGameStateProvider(sessionId)),
            ),
            data: (state) {
              final skeleton = state.skeleton;
              final subjectId = skeleton.subjectId;
              final isMyTurn = subjectId != null && subjectId == myId;

              if (isMyTurn) {
                return skeleton.answer == null
                    ? _SubjectEditorCard(
                        sessionId: sessionId,
                        state: state,
                        l10n: l10n,
                      )
                    : _SubjectWaitingVotesCard(
                        sessionId: sessionId,
                        state: state,
                        l10n: l10n,
                      );
              }
              return skeleton.answer == null
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
                    );
            },
          ),
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

/// The subject's statement editor: 3 minimal rounded cards, each an input.
/// Long-pressing a card marks it as the truth (white border + soft glow).
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

  /// Per-card focus + anchor: the card being written in is always scrolled
  /// into view (keyboard up, or a long statement) — the writing card must
  /// never hide under the keyboard or off-screen.
  final _focusNodes = [FocusNode(), FocusNode(), FocusNode()];
  final _cardKeys = [GlobalKey(), GlobalKey(), GlobalKey()];

  /// The statement the subject marked as their single truth (long-press a
  /// card). Null until marked — the card's white glow is the only signal; no
  /// radio, number, arrow or "truth" label.
  int? _truthIndex;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final node in _focusNodes) {
      node.addListener(_ensureActiveCardVisible);
    }
  }

  /// Keeps the focused card on screen: after focus (and the keyboard's own
  /// show-on-screen pass) the active card is scrolled to roughly a third from
  /// the top of the viewport, so its label, text and cursor all stay visible.
  void _ensureActiveCardVisible() {
    for (var i = 0; i < _focusNodes.length; i++) {
      if (!_focusNodes[i].hasFocus) continue;
      final ctx = _cardKeys[i].currentContext;
      if (ctx == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusNodes[i].hasFocus) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.35,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    _controller0.dispose();
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keyboard-aware: the Scaffold already shrinks this body above
              // the keyboard, so the centered form stays reachable and the
              // focused card auto-scrolls into view — centered while it fits,
              // scrollable the moment it does not.
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.md * 2,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.l10n.minigamesTwoLiesHoldHint,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: MinigameInks.of(context).muted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildStatementField(0, _controller0),
                          const SizedBox(height: AppSpacing.md),
                          _buildStatementField(1, _controller1),
                          const SizedBox(height: AppSpacing.md),
                          _buildStatementField(2, _controller2),
                          if (widget.state.skeleton.anonymous) ...[
                            const SizedBox(height: AppSpacing.lg),
                            MinigameAliasEditor(
                              sessionId: widget.sessionId,
                              state: widget.state,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildActionBar(),
      ],
    );
  }

  /// The pinned answer/pass bar — identical geometry to the truth/dare
  /// subject editor's action bar.
  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: VButton.dark(
                label: widget.l10n.minigamesAnswerSubmit,
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
      ),
    );
  }

  Widget _buildStatementField(int index, TextEditingController controller) {
    // A held press marks this card as the truth. The recognizer uses a shorter
    // deadline than the 500ms default so it WINS the gesture arena against the
    // inner TextField's own long-press recognizer (which Flutter registers even
    // with selection disabled). With the default deadline the field would
    // silently swallow the hold over the text area — only the card's chrome
    // would mark it — so long-pressing where the user actually taps did nothing.
    return RawGestureDetector(
      key: _cardKeys[index],
      behavior: HitTestBehavior.opaque,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 350),
              ),
              (instance) =>
                  instance.onLongPress = () =>
                      setState(() => _truthIndex = index),
            ),
      },
      child: _TwoLiesCardShell(
        highlighted: _truthIndex == index,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Small top-left label — the only text on the card (no placeholder
            // hint; the typed statement is centered in the field).
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Text(
                widget.l10n.minigamesTwoLiesStatementNumber(index + 1),
                style: AppTypography.labelMedium.copyWith(
                  color: MinigameInks.of(context).muted,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            VInput(
              label: '',
              hint: '',
              controller: controller,
              focusNode: _focusNodes[index],
              minLines: 2,
              maxLines: 4,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
            ),
          ],
        ),
      ),
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

    final truthIndex = _truthIndex;
    if (truthIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.l10n.minigamesTwoLiesMarkTruthPrompt),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final round = widget.state.skeleton.round;
      final payload = TwoLiesPayload(
        statements: [
          TwoLiesStatement(index: 0, text: t0, isTruth: truthIndex == 0),
          TwoLiesStatement(index: 1, text: t1, isTruth: truthIndex == 1),
          TwoLiesStatement(index: 2, text: t2, isTruth: truthIndex == 2),
        ],
        truthIndex: truthIndex,
      );

      final cipher = ref.read(minigameCipherProvider(widget.sessionId));
      final textCipher = await cipher.encryptAnswerText(
        payload.encode(),
        round,
      );

      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .submitAnswer(answerCiphertext: textCipher);
    } catch (e, st) {
      AppLogger.instance.warn(
        'TwoLiesScreen: error submitting statements: $e',
        '$st',
      );
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
      AppLogger.instance.warn(
        'TwoLiesScreen: error decrypting own statements: $e',
        '$st',
      );
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
        (ref
                    .watch(sessionStatusProvider(widget.sessionId))
                    .valueOrNull?['participants']
                as List?)
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
              widget.l10n.minigamesTwoLiesWaitingVotes(
                totalReacted,
                requiredVotes,
              ),
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
                        ? MinigameInks.of(context).surfaceAlt
                        : MinigameInks.of(context).surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: s.isTruth
                          ? MinigameInks.of(context).primary
                          : MinigameInks.of(context).border,
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

  /// The order the 3 statements are DISPLAYED in for this device + round —
  /// shuffled deterministically so no two devices (and no two rounds) present
  /// the authored order the same way, defeating position-pattern guessing.
  /// Each entry is an ORIGINAL statement index.
  List<int> _displayOrder = const [0, 1, 2];

  @override
  void initState() {
    super.initState();
    _displayOrder = _shuffledOrder();
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
        _displayOrder = _shuffledOrder();
      });
      _decrypt();
    }
  }

  /// A deterministic per-device/round seed folded from the session id, the
  /// round and the caller id (simple 31-multiplier hash).
  static int _stableSeed(String sessionId, int round, String? myId) {
    final input = '$sessionId|$round|${myId ?? ''}';
    var h = 0;
    for (final unit in input.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return h;
  }

  List<int> _shuffledOrder() {
    final order = [0, 1, 2];
    order.shuffle(
      math.Random(
        _stableSeed(widget.sessionId, widget.state.skeleton.round, widget.myId),
      ),
    );
    return order;
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
      AppLogger.instance.warn(
        'TwoLiesScreen: error decrypting statements: $e',
        '$st',
      );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.l10n.minigamesTwoLiesGuessPrompt,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0; i < _displayOrder.length; i++) ...[
                        _buildStatementOption(i, _displayOrder[i], hasVoted),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (hasVoted)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: MinigameInks.of(context).surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            widget.l10n.minigamesTwoLiesVoteConfirmed,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!hasVoted) _buildActionBar(),
      ],
    );
  }

  /// The pinned vote/pass bar — identical geometry to the subject editor's.
  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: VButton.dark(
                label: widget.l10n.minigamesTwoLiesVoteConfirm,
                loading: _submitting,
                onPressed: _selectedVoteIndex == null || _submitting
                    ? null
                    : _submitVote,
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
      ),
    );
  }

  /// One statement card, rendered at display [position] and holding ORIGINAL
  /// statement [originalIndex]. Voters never see the truth highlight.
  Widget _buildStatementOption(int position, int originalIndex, bool hasVoted) {
    if (originalIndex >= _payload!.statements.length) {
      return const SizedBox.shrink();
    }
    final isSelected = _selectedVoteIndex == position;
    final isMyVote = _votedIndex == originalIndex;
    return GestureDetector(
      onTap: hasVoted
          ? null
          : () => setState(() => _selectedVoteIndex = position),
      child: _TwoLiesCardShell(
        highlighted: isSelected || isMyVote,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            _payload!.statements[originalIndex].text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  Future<void> _submitVote() async {
    if (_selectedVoteIndex == null) return;
    setState(() => _submitting = true);
    // Map the DISPLAYED selection back to the authored statement index: the
    // server counts votes by original index; the display order is only a
    // per-device shuffle.
    final original = _displayOrder[_selectedVoteIndex!];
    final kind = switch (original) {
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
          _votedIndex = original;
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

/// The rounded, minimal card shell shared by the subject editor, the voter
/// ballot and the finished-screen statement rows. A white border + soft white
/// glow marks the highlighted (truth / selected) card — no icon, no arrow,
/// no text.
class _TwoLiesCardShell extends StatelessWidget {
  const _TwoLiesCardShell({required this.highlighted, required this.child});

  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: MinigameInks.of(context).surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: highlighted
              ? MinigameInks.of(context).primary
              : MinigameInks.of(context).border,
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: MinigameInks.of(
                    context,
                  ).primary.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// The finished "2 mentiras, 1 verdad" board: the settled ranking with each
/// player's authored statements, the true one revealed (white border/glow +
/// chip). Rendered full-bleed under the floating back arrow.
class _TwoLiesFinishedBody extends ConsumerWidget {
  const _TwoLiesFinishedBody({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(minigameResultProvider(sessionId));
    final contentAsync = ref.watch(minigamePlayerContentProvider(sessionId));
    final roster =
        ref.watch(minigameParticipantsProvider(sessionId)).valueOrNull ??
        const <MinigameParticipant>[];

    return result.when(
      loading: () => const VLoadingView(),
      error: (e, _) => ErrorView(message: e.toAppError().message),
      data: (settled) {
        if (settled == null || settled.rows.isEmpty) {
          return Center(
            child: VDisplayText(text: l10n.minigamesFinished, size: 28),
          );
        }
        final rows = [...settled.rows]
          ..sort((a, b) => a.rank.compareTo(b.rank));
        final content =
            contentAsync.valueOrNull ?? const MinigamePlayerContent();
        final statusTop = MediaQuery.paddingOf(context).top;
        return ListView(
          padding: EdgeInsets.only(
            top: statusTop + VHeaderMetrics.barOuterHeight(statusTop),
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.xl,
          ),
          children: [
            for (final row in rows) ...[
              _buildRow(context, row, content, roster, l10n),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    MinigameResultRow row,
    MinigamePlayerContent content,
    List<MinigameParticipant> roster,
    AppLocalizations l10n,
  ) {
    final answers = content
        .answersFor(row.participantId)
        .where((a) => !a.passed)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '#${row.rank}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _usernameFor(row.participantId, roster, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              row.prize > 0
                  ? l10n.minigamesPrizeAmount(row.prize)
                  : '${row.score}',
              style: TextStyle(color: MinigameInks.of(context).muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final answer in answers) ...[
          _buildAnswer(context, answer, l10n),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  /// One round's decrypted 3 statements, in authored order, with the truth
  /// revealed. A payload that cannot be decoded (lost round key) renders
  /// nothing rather than a broken card.
  Widget _buildAnswer(
    BuildContext context,
    MinigamePlayerAnswer answer,
    AppLocalizations l10n,
  ) {
    final payload = TwoLiesPayload.tryDecode(answer.text);
    if (payload == null || payload.statements.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (final statement in payload.statements) ...[
          _TwoLiesCardShell(
            highlighted: statement.isTruth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  VChip(
                    label: statement.isTruth
                        ? l10n.minigamesTwoLiesTruthBadge
                        : l10n.minigamesTwoLiesLieBadge,
                    selected: statement.isTruth,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      statement.text,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  static String _usernameFor(
    String userId,
    List<MinigameParticipant> roster,
    AppLocalizations l10n,
  ) {
    for (final p in roster) {
      if (p.id == userId) {
        final name = p.username.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return l10n.minigamesAnonymousPlayer;
  }
}
