import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/reaction_rise.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

/// The finished-game leaderboard (201/202) — a 3D "coverflow" carousel of rank
/// cards, centered on the WHOLE viewport (the floating back arrow is the only
/// header, mirroring the attendance QR screen).
///
/// Every ranked participant gets a card (winners and non-winners alike),
/// ordered by rank; the selected card sits forward and centered while its
/// neighbours recede to the sides with a perspective transform, blurring into
/// and out of mist as the page passes. Every card fills the same
/// viewport-sized box: the prompt rides at the top, the answer body centers,
/// and the identity block (RANK + USERNAME, then POINTS · SHARDS) is pinned to
/// the card floor. A picture answer becomes the card's full-bleed background
/// under a bottom gradient, so an image card and a text card share one
/// container. Rounds page vertically with a discreet rail so the affordance is
/// obvious; in anonymous mode the usernames are revealed HERE — the only place
/// real names appear during the match.
///
/// This widget is the provider seam: it resolves the settled result, the
/// roster and the decrypted player content, then hands plain data to
/// [LeaderboardCarousel] (the pure, screenshot-friendly view).
class FinishedLeaderboard extends ConsumerWidget {
  const FinishedLeaderboard({
    super.key,
    required this.sessionId,
    this.initialParticipantId,
  });

  final String sessionId;

  /// When given, the carousel opens focused on this participant's card
  /// (TODO F: tapping a player in the finished session detail lands here).
  final String? initialParticipantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(minigameResultProvider(sessionId));
    final roster =
        ref.watch(minigameParticipantsProvider(sessionId)).valueOrNull ??
        const <MinigameParticipant>[];
    final contentAsync = ref.watch(minigamePlayerContentProvider(sessionId));

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
        return LeaderboardCarousel(
          rows: rows,
          nameFor: (id) => _usernameFor(id, roster, l10n),
          content: contentAsync.valueOrNull ?? const MinigamePlayerContent(),
          contentLoading: contentAsync.isLoading,
          contentError: contentAsync.hasError,
          onRetryContent: () =>
              ref.invalidate(minigamePlayerContentProvider(sessionId)),
          initialParticipantId: initialParticipantId,
        );
      },
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

/// The pure leaderboard carousel: rank cards laid out in a horizontally
/// paged "coverflow". Holds no provider dependency so it can be previewed
/// with static data.
class LeaderboardCarousel extends StatefulWidget {
  const LeaderboardCarousel({
    super.key,
    required this.rows,
    required this.nameFor,
    required this.content,
    required this.contentLoading,
    required this.contentError,
    required this.onRetryContent,
    this.initialParticipantId,
  });

  final List<MinigameResultRow> rows;
  final String Function(String participantId) nameFor;
  final MinigamePlayerContent content;

  /// The participant whose card opens first (null → rank 1 / first row).
  final String? initialParticipantId;

  /// Whether the decrypted answer content is still resolving.
  final bool contentLoading;

  /// Whether resolving the answer content failed (or timed out).
  final bool contentError;

  /// Retries the answer-content load (the discreet in-card retry action).
  final VoidCallback onRetryContent;

  @override
  State<LeaderboardCarousel> createState() => _LeaderboardCarouselState();
}

class _LeaderboardCarouselState extends State<LeaderboardCarousel> {
  late final PageController _controller;
  late int _index;

  /// Bumped on a re-tap of the already-selected card so the celebration can
  /// replay without a page change.
  int _replayToken = 0;

  /// The vertical answer page each participant was last viewing. Lives only as
  /// long as this carousel (the leaderboard screen): leaving and re-entering
  /// resets everyone to their first answer, per the 2026-09-15 directive.
  final Map<String, int> _answerIndexByParticipant = {};

  @override
  void initState() {
    super.initState();
    _index = _firstIndexOf(widget.initialParticipantId);
    _controller = PageController(initialPage: _index);
  }

  /// The page index of [participantId] (0 / rank 1 when absent or unknown).
  int _firstIndexOf(String? participantId) {
    if (participantId == null || participantId.isEmpty) return 0;
    final i = widget.rows.indexWhere((r) => r.participantId == participantId);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) {
      setState(() => _replayToken++);
      return;
    }
    _controller.animateToPage(
      i,
      duration: SamayDurations.standard,
      curve: SamayDurations.defaultCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        // FULL SCREEN: every page fills the whole viewport (no neighbour peek,
        // no card frame), so a picture answer is edge-to-edge. The height falls
        // back to a sane value only for a transient degenerate layout pass.
        final cardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 620.0;
        return Center(
          child: SizedBox(
            width: double.infinity,
            height: cardHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: rows.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final row = rows[i];
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final page =
                        _controller.hasClients &&
                            _controller.position.haveDimensions
                        ? (_controller.page ?? _index.toDouble())
                        : _index.toDouble();
                    final delta = (page - i).clamp(-1.0, 1.0);
                    final absDelta = delta.abs();
                    final opacity = (1 - absDelta * 0.7).clamp(0.2, 1.0);
                    // Blur the receding neighbours into mist so their text never
                    // reads as sharp half-sentences at the card edges.
                    final blur = (absDelta * 2.5).clamp(0.0, 2.5);
                    final angle = -delta * 0.5;
                    final scale = 1 - absDelta * 0.28;

                    final card = Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..rotateY(angle)
                        ..scaleByDouble(scale, scale, scale, 1.0),
                      child: child,
                    );
                    // ALWAYS wrap in ImageFiltered, even at sigma 0. Keeping the
                    // element-tree shape CONSTANT is load-bearing: the old
                    // `if (blur < 0.05)` branch inserted the wrapper the instant
                    // a horizontal drag began, which reparented the
                    // RepaintBoundary/_RankCard, destroyed `_RankCardState` and
                    // made its vertical pager snap back to the first answer
                    // mid-swipe.
                    return Opacity(
                      opacity: opacity,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: blur,
                          sigmaY: blur,
                        ),
                        child: card,
                      ),
                    );
                  },
                  // RepaintBoundary isolates the card's own scrollable from
                  // the perspective blur compositing — without it the offscreen
                  // filter path could composite the nested viewport before its
                  // sliver was laid out, crashing RenderViewportBase with a null
                  // sliver geometry.
                  child: RepaintBoundary(
                    child: _RankCard(
                      key: ValueKey(row.participantId),
                      row: row,
                      name: widget.nameFor(row.participantId),
                      answers: widget.content.answersFor(row.participantId),
                      contentLoading: widget.contentLoading,
                      contentError: widget.contentError,
                      onRetryContent: widget.onRetryContent,
                      selected: _index == i,
                      replayToken: _replayToken,
                      onTap: () => _select(i),
                      initialAnswerIndex:
                          _answerIndexByParticipant[row.participantId] ?? 0,
                      onAnswerChanged: (i) =>
                          _answerIndexByParticipant[row.participantId] = i,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// One player's carousel card: the current round's prompt on top, its answer
/// in the middle (a picture answer is the full-bleed backdrop instead), the
/// round's reactions, then the identity block pinned to the floor. The card is
/// the celebration stage — the current answer's reactions rise once its image
/// has loaded (immediately when there is no image). Tapping the
/// already-selected card replays via [replayToken].
class _RankCard extends StatefulWidget {
  const _RankCard({
    super.key,
    required this.row,
    required this.name,
    required this.answers,
    required this.contentLoading,
    required this.contentError,
    required this.onRetryContent,
    required this.selected,
    required this.replayToken,
    required this.onTap,
    required this.initialAnswerIndex,
    required this.onAnswerChanged,
  });

  final MinigameResultRow row;
  final String name;
  final List<MinigamePlayerAnswer> answers;
  final bool contentLoading;
  final bool contentError;
  final VoidCallback onRetryContent;
  final bool selected;
  final int replayToken;
  final VoidCallback onTap;

  /// The vertical answer page to open on (remembered by the carousel for the
  /// lifetime of the leaderboard screen).
  final int initialAnswerIndex;

  /// Reports the page the player scrolls to so the carousel can remember it.
  final ValueChanged<int> onAnswerChanged;

  @override
  State<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends State<_RankCard> {
  late final PageController _pager;
  late int _answerIndex;

  /// Whether the CURRENT answer's image is ready (true when it has no image).
  bool _imageReady = true;

  @override
  void initState() {
    super.initState();
    _answerIndex = _clampIndex(widget.initialAnswerIndex);
    _pager = PageController(initialPage: _answerIndex);
    _imageReady = !_currentHasImage;
  }

  @override
  void didUpdateWidget(covariant _RankCard old) {
    super.didUpdateWidget(old);
    // Reset ONLY when the answer SET genuinely changes (async content arriving
    // — empty → populated). Never by list identity: the provider may hand back
    // an equal-but-new list on a plain rebuild, and resetting then would throw
    // away the answer the player is on.
    if (_signature(widget) != _signature(old)) {
      _answerIndex = _clampIndex(_answerIndex);
      _imageReady = !_currentHasImage;
      if (_pager.hasClients) _pager.jumpToPage(_answerIndex);
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  int _clampIndex(int index) => widget.answers.isEmpty
      ? 0
      : index.clamp(0, widget.answers.length - 1);

  /// A stable identity of a card's answer set (participant + per-answer round
  /// and content flags) used to decide whether a rebuild is a real content
  /// change.
  static String _signature(_RankCard w) =>
      '${w.row.participantId}|${w.answers.length}|'
      '${w.answers.map((a) => '${a.round}${a.passed ? 'p' : ''}'
          '${a.hasText ? 't' : ''}${a.hasImage ? 'i' : ''}').join(',')}';

  MinigamePlayerAnswer? get _current => widget.answers.isEmpty
      ? null
      : widget.answers[_answerIndex.clamp(0, widget.answers.length - 1)];

  bool get _currentHasImage => _current?.hasImage ?? false;

  /// The current answer's received reactions, expanded one kind per count.
  List<ReactionKind> get _currentReactions {
    final answer = _current;
    if (answer == null) return const [];
    final out = <ReactionKind>[];
    answer.reactions.forEach((kind, count) {
      for (var i = 0; i < count; i++) {
        out.add(kind);
      }
    });
    return out;
  }

  Color get _rankColor => switch (widget.row.rank) {
    1 => AppColors.discoGold,
    2 => AppColors.discoSilver,
    3 => AppColors.discoBronze,
    _ => AppColors.white,
  };

  /// Arms the celebration once the CURRENT answer's picture has loaded.
  void _armOnImageLoaded() {
    if (mounted && !_imageReady) setState(() => _imageReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const insets = EdgeInsets.fromLTRB(
      AppSpacing.cardPadding,
      VHeaderMetrics.heroTopPad + VHeaderMetrics.titleRowHeight,
      AppSpacing.cardPadding,
      AppSpacing.cardPadding,
    );
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        // Full-bleed, frameless page: no margin, radius or border.
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: AppColors.discoBlack),
        child: _LeaderboardEmojiRise(
          active: widget.selected && _imageReady,
          trigger: '$_answerIndex:${widget.replayToken}',
          kinds: _currentReactions,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // LAYER 1 — the answers. Full-card pages, so a picture is
              // full-bleed (behind the pinned prompt AND footer) and translates
              // WITH the finger via the stock PageView physics.
              if (widget.answers.isNotEmpty) _buildPager(l10n),

              // LAYER 2 — everything decorative, under ONE IgnorePointer. This
              // is load-bearing: a gradient `DecoratedBox` hit-tests TRUE over
              // its whole rectangle (`BoxDecoration.hitTest`), so an unignored
              // scrim would swallow the vertical drag and the pager would never
              // move.
              IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_currentHasImage) ...[
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Color(0xFF000000),
                            ],
                            stops: [0, 0.55, 1],
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xCC000000), Colors.transparent],
                            stops: [0, 0.3],
                          ),
                        ),
                      ),
                    ],
                    SafeArea(
                      child: Padding(
                        padding: insets,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_current != null)
                              _PromptHeader(answer: _current!, l10n: l10n),
                            const Spacer(),
                            if (_current?.reactions.isNotEmpty ?? false) ...[
                              _ReactionTally(reactions: _current!.reactions),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            _CardFooter(
                              rank: widget.row.rank,
                              rankColor: _rankColor,
                              name: widget.name,
                              score: widget.row.score,
                              prize: widget.row.prize,
                              l10n: l10n,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.answers.length > 1)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: AppSpacing.sm,
                        child: _AnswerRail(
                          count: widget.answers.length,
                          index: _answerIndex,
                        ),
                      ),
                  ],
                ),
              ),

              // LAYER 3 — content state (loading / error / empty). Interactive,
              // so it is NOT inside the IgnorePointer layer — the retry button
              // must stay tappable.
              if (widget.answers.isEmpty)
                Padding(padding: insets, child: _buildStatePanel(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  /// The answers as full-card pages: one static page for a single answer, or a
  /// vertical `PageView` for several (its own physics — the page follows the
  /// finger naturally). Each page owns its picture, so an image answer moves
  /// with the finger exactly like a text answer.
  Widget _buildPager(AppLocalizations l10n) {
    if (widget.answers.length == 1) {
      return _AnswerPage(
        answer: widget.answers.first,
        l10n: l10n,
        onImageLoaded: _armOnImageLoaded,
      );
    }
    return PageView.builder(
      controller: _pager,
      scrollDirection: Axis.vertical,
      itemCount: widget.answers.length,
      onPageChanged: (i) {
        widget.onAnswerChanged(i);
        setState(() {
          _answerIndex = i;
          _imageReady = !widget.answers[i].hasImage;
        });
      },
      itemBuilder: (context, i) => _AnswerPage(
        answer: widget.answers[i],
        l10n: l10n,
        // Only the CURRENT page's image may arm the celebration.
        onImageLoaded: i == _answerIndex ? _armOnImageLoaded : null,
      ),
    );
  }

  /// The centered state panel for a card with no answers yet.
  Widget _buildStatePanel(AppLocalizations l10n) {
    if (widget.contentLoading) {
      return const Center(child: VSpinner(size: 24));
    }
    if (widget.contentError) {
      return Center(
        child: _AnswersRetry(
          message: l10n.minigamesAnswersLoadError,
          onRetry: widget.onRetryContent,
        ),
      );
    }
    return Center(
      child: Text(
        l10n.minigamesNoAnswers,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.mutedStrong, fontSize: 13),
      ),
    );
  }
}

/// The card's bottom block: the RANK and USERNAME on one line, with the
/// POINTS and SHARDS line tucked directly beneath the username. Pinned to the
/// card floor so the identity reads the same on every card regardless of what
/// the answer region holds.
class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.rank,
    required this.rankColor,
    required this.name,
    required this.score,
    required this.prize,
    required this.l10n,
  });

  final int rank;
  final Color rankColor;
  final String name;
  final int score;
  final int prize;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Fixed-width rank column: the glyph is enlarged and right-aligned so
        // every card's username starts on the SAME x (a real leaderboard grid,
        // not a ragged left edge) and 1–2 digit ranks stay aligned.
        SizedBox(
          width: 64,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: AppTypography.playfair,
                fontSize: 58,
                fontWeight: FontWeight.w700,
                // Playfair's ascender/descender padding makes the glyph read
                // smaller; a tight line height lets the numeral's cap dominate.
                height: 0.9,
                color: rankColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      l10n.minigamesPointsAmount(score),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedStrong,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(
                      '·',
                      style: TextStyle(
                        color: AppColors.mutedStrong,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const VShardIcon(size: 13),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      l10n.minigamesPrizeAmount(prize),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedStrong,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The prompt header for the current answer: the type label (RETO / VERDAD)
/// and the question body, centered at the top of the card. A question that
/// cannot be resolved (deactivated/removed prompt) renders
/// [AppLocalizations.minigamesPromptLoadError] instead.
class _PromptHeader extends StatelessWidget {
  const _PromptHeader({required this.answer, required this.l10n});

  final MinigamePlayerAnswer answer;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (!answer.hasPrompt) {
      return Text(
        l10n.minigamesPromptLoadError,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.badgeRed,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
    }
    final kind = truthDareKindFromWire(answer.promptType);
    final label = kind == null ? null : truthDareKindLabel(l10n, kind);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.mutedStrong,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          answer.promptBody!,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: AppTypography.quicksand,
            color: AppColors.mutedStrong,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// One answer page: the picture (with an opaque blurred, vertically-mirrored
/// copy filling its letterbox bands and the complete image drawn `contain` on
/// top) or a plain black ground, plus the centered body (text / "pasó" / "—").
/// It lives inside the vertical [PageView], so the picture moves with the
/// finger exactly like a text answer. [onImageLoaded] fires when the picture's
/// first frame is ready (null for non-current pages).
class _AnswerPage extends StatelessWidget {
  const _AnswerPage({
    required this.answer,
    required this.l10n,
    this.onImageLoaded,
  });

  final MinigamePlayerAnswer answer;
  final AppLocalizations l10n;
  final VoidCallback? onImageLoaded;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (answer.hasImage) ...[
          // Opaque blurred, vertically-mirrored copy so the letterbox bands it
          // leaves read as one full-bleed surface. Over-scaled to hide the
          // blur's transparent edge fringe.
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Transform.scale(
              scale: 1.3,
              child: Transform.flip(
                flipY: true,
                child: Image.memory(
                  answer.imageBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          // The complete picture (BoxFit.contain — never cropped, so a
          // landscape photo stays landscape).
          Image.memory(
            answer.imageBytes!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, syncLoaded) {
              if ((frame != null || syncLoaded) && onImageLoaded != null) {
                final cb = onImageLoaded!;
                WidgetsBinding.instance.addPostFrameCallback((_) => cb());
              }
              return child;
            },
          ),
        ],
        // The body centers in the space the pinned prompt/footer leave open (the
        // picture itself stays full-bleed behind them).
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              VHeaderMetrics.heroTopPad + VHeaderMetrics.titleRowHeight,
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
            ),
            child: Center(child: _buildBody()),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (answer.passed) {
      return Text(
        l10n.minigamesPasarSkipped,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppTypography.quicksand,
          fontSize: 22,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
          color: AppColors.mutedStrong,
        ),
      );
    }
    if (answer.hasText) {
      return Text(
        answer.text!,
        textAlign: TextAlign.center,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppTypography.quicksand,
          fontSize: 20,
          height: 1.4,
          letterSpacing: 1.1,
          color: AppColors.white,
        ),
      );
    }
    return const Text(
      '—',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.muted, fontSize: 24),
    );
  }
}

/// Discreet reload prompt shown inside a rank card when the answer content
/// failed to resolve within its window: a refresh affordance plus a calm
/// one-line apology. No alarm styling — this is a retry, not a failure.
class _AnswersRetry extends StatelessWidget {
  const _AnswersRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onRetry,
            iconSize: 22,
            color: AppColors.white,
            tooltip: AppLocalizations.of(context).commonRetry,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.mutedStrong,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The answer page control: a slim VERTICAL rail on the trailing edge of the
/// answer region (one segment per answer). The active segment elongates into
/// a white pill while the rest stay visible `muted #666666` dots. Vertical
/// segments are the axis-correct affordance for a vertically-paged card
/// (unlike a horizontal dot row, which reads as a horizontal page control and
/// competes with the coverflow's left/right gesture) — Apple HIG's guidance
/// is that a page control must agree with the axis the content actually
/// pages on. Hidden when there is a single answer.
class _AnswerRail extends StatelessWidget {
  const _AnswerRail({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: SamayDurations.fast,
            curve: SamayDurations.defaultCurve,
            width: 4,
            height: i == index ? 20 : 6,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: i == index ? AppColors.white : const Color(0xFFB0B0B0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// The reactions ONE answer received, as emoji + count chips (most received
/// first). Rendered under the answer pager.
class _ReactionTally extends StatelessWidget {
  const _ReactionTally({required this.reactions});

  final Map<ReactionKind, int> reactions;

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReactionEmoji(kind: e.key, fontSize: 18),
              const SizedBox(width: 2),
              Text(
                '${e.value}',
                style: const TextStyle(
                  color: AppColors.mutedStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Wraps a rank card as the celebration stage: when [active] turns on (or a
/// new [trigger] arrives while active) the current answer's [kinds] spawn at
/// once. Each particle keeps its own random lane, wobble and 0–320 ms start
/// offset (see [RisingReactionParticle]), so the burst reads as lively rather
/// than a rigid column. Reduced motion spawns nothing; no kinds → nothing.
class _LeaderboardEmojiRise extends StatefulWidget {
  const _LeaderboardEmojiRise({
    required this.active,
    required this.trigger,
    required this.kinds,
    required this.child,
  });

  final bool active;
  final String trigger;
  final List<ReactionKind> kinds;
  final Widget child;

  @override
  State<_LeaderboardEmojiRise> createState() => _LeaderboardEmojiRiseState();
}

class _LeaderboardEmojiRiseState extends State<_LeaderboardEmojiRise> {
  final List<RiseSpec> _active = [];
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _burst();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _LeaderboardEmojiRise old) {
    super.didUpdateWidget(old);
    if (widget.active && (!old.active || widget.trigger != old.trigger)) {
      _burst();
    }
  }

  void _burst() {
    if (widget.kinds.isEmpty) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    setState(() {
      for (final kind in widget.kinds) {
        _active.add(RiseSpec(id: _nextId++, kind: kind));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // StackFit.passthrough is REQUIRED: the default StackFit.loose loosens the
    // tight height the outer PageView hands the card, leaving the card's
    // `Expanded` answer pager with unbounded height — a flex layout exception
    // that aborts the viewport layout and surfaces as a null `geometry!` crash
    // in RenderViewportBase. Passthrough preserves the incoming constraints so
    // the child lays out exactly as it would without the celebration overlay.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_active.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    return Stack(
                      children: [
                        for (final spec in List.of(_active))
                          RisingReactionParticle(
                            key: ValueKey('leaderboard-rise-${spec.id}'),
                            spec: spec,
                            width: size.width,
                            height: size.height,
                            onDone: () {
                              _active.remove(spec);
                              if (mounted) setState(() {});
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
