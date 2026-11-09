import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/features/minigames/widgets/minigame_session_surface.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/minigame_answer_text.dart';
import 'package:samay/features/minigames/widgets/minigame_bleed_image.dart';
import 'package:samay/features/minigames/widgets/reaction_rise.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/full_screen_image.dart';
import 'package:samay/shared/widgets/report_sheet.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';
import 'package:samay/shared/widgets/v_spinner.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// The finished-game leaderboard (201/202) — a 3D "coverflow" carousel of rank
/// cards, centered on the WHOLE viewport (the floating back arrow is the only
/// header, mirroring the attendance QR screen).
///
/// Every ranked participant gets a card (winners and non-winners alike),
/// ordered by rank; each page spans the WHOLE viewport (so an answer picture is
/// edge-to-edge full-bleed) while the horizontal swipe's perspective transform
/// blurs the passing page into and out of mist. Every card fills the same
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
  /// (tapping a player in the finished session detail lands here).
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
  /// resets everyone to their first answer.
  final Map<String, int> _answerIndexByParticipant = {};

  /// The first-run swipe hint is shown until the player changes rank page or
  /// taps it away.
  late bool _swipeHintVisible;

  @override
  void initState() {
    super.initState();
    _index = _firstIndexOf(widget.initialParticipantId);
    _controller = PageController(
      initialPage: _index,
      // Each page spans the WHOLE viewport so a picture answer is truly
      // full-bleed edge-to-edge. Rank navigation is the horizontal swipe plus
      // the on-card rank pager — no resting neighbour peek.
    );
    _swipeHintVisible = widget.rows.length > 1;
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
        // Every page spans the WHOLE viewport; a picture answer fills it
        // edge-to-edge. The height falls back to a sane value only for a
        // transient degenerate layout pass.
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
              onPageChanged: (i) => setState(() {
                _index = i;
                _swipeHintVisible = false;
              }),
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
                    // element-tree shape constant is load-bearing: inserting
                    // the wrapper mid-drag would reparent the RepaintBoundary/
                    // _RankCard, destroy `_RankCardState`, and snap its vertical
                    // pager back to the first answer mid-swipe.
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
                      onSelectRank: _select,
                      showSwipeHint: _swipeHintVisible && _index == i,
                      onDismissSwipeHint: () =>
                          setState(() => _swipeHintVisible = false),
                      rankIndex: i,
                      rankCount: rows.length,
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
    required this.onSelectRank,
    required this.showSwipeHint,
    required this.onDismissSwipeHint,
    required this.rankIndex,
    required this.rankCount,
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

  /// Jumps the carousel to a rank page (the pager chevrons).
  final ValueChanged<int> onSelectRank;

  /// Whether the first-run swipe hint is visible on this card.
  final bool showSwipeHint;

  /// Dismisses the first-run swipe hint.
  final VoidCallback onDismissSwipeHint;

  /// This card's position in the horizontal ranking (0-based) and the total
  /// number of ranked participants — drives the rank page indicator.
  final int rankIndex;
  final int rankCount;

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

  int _clampIndex(int index) =>
      widget.answers.isEmpty ? 0 : index.clamp(0, widget.answers.length - 1);

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
    _ => context.palette.foreground,
  };

  /// Arms the celebration once the CURRENT answer's picture has loaded.
  void _armOnImageLoaded() {
    if (mounted && !_imageReady) setState(() => _imageReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final insets = EdgeInsets.fromLTRB(
      AppSpacing.cardPadding,
      VHeaderMetrics.heroTopPad(MediaQuery.paddingOf(context).top) +
          VHeaderMetrics.titleRowHeight +
          VHeaderMetrics.headerOuterPad * 2,
      AppSpacing.cardPadding,
      AppSpacing.cardPadding,
    );
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        // Full-bleed, frameless page: no margin, radius or border.
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: MinigameInks.of(context).themed
              ? MinigameInks.of(context).surface
              : context.palette.background,
        ),
        child: _LeaderboardEmojiRise(
          active: widget.selected && _imageReady,
          trigger: '$_answerIndex:${widget.replayToken}',
          kinds: _currentReactions,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The answers, paged full-card so a picture is full-bleed
              // (behind the pinned prompt AND footer) and translates with the
              // finger via the stock PageView physics.
              if (widget.answers.isNotEmpty) _buildPager(l10n),

              // Decorative-only layer: a gradient `DecoratedBox` hit-tests TRUE
              // over its whole rectangle (`BoxDecoration.hitTest`), so the
              // scrims must be ignored or they swallow the vertical drag.
              IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_currentHasImage) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.transparent,
                              AppColors.transparent,
                              context.palette.background,
                            ],
                            stops: [0, 0.55, 1],
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              context.palette.background.withValues(alpha: 0.8),
                              AppColors.transparent,
                            ],
                            stops: const [0, 0.3],
                          ),
                        ),
                      ),
                    ],
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

              // Pinned chrome: the prompt/reactions/footer are decorative and
              // ignored so vertical drags reach the pager; the swipe hint and
              // the rank pager stay interactive.
              SafeArea(
                child: Padding(
                  padding: insets,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_current != null)
                        IgnorePointer(
                          child: _PromptHeader(answer: _current!, l10n: l10n),
                        ),
                      const Spacer(),
                      if (_current?.reactions.isNotEmpty ?? false)
                        IgnorePointer(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ReactionTally(reactions: _current!.reactions),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          ),
                        ),
                      IgnorePointer(
                        child: _CardFooter(
                          rank: widget.row.rank,
                          rankColor: _rankColor,
                          name: widget.name,
                          score: widget.row.score,
                          prize: widget.row.prize,
                          l10n: l10n,
                        ),
                      ),
                      if (widget.showSwipeHint) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _SwipeHint(onDismiss: widget.onDismissSwipeHint),
                      ],
                      if (widget.rankCount > 1) ...[
                        const SizedBox(height: AppSpacing.md),
                        _RankPager(
                          index: widget.rankIndex,
                          count: widget.rankCount,
                          onPrevious: widget.rankIndex > 0
                              ? () => widget.onSelectRank(widget.rankIndex - 1)
                              : null,
                          onNext: widget.rankIndex < widget.rankCount - 1
                              ? () => widget.onSelectRank(widget.rankIndex + 1)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Content state (loading / error / empty) stays interactive, so
              // it is NOT inside the IgnorePointer layer — the retry button
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
      final answer = widget.answers.first;
      return _AnswerPage(
        answer: answer,
        l10n: l10n,
        onImageLoaded: _armOnImageLoaded,
        onImageTap: _imageTapFor(answer),
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
        onImageTap: _imageTapFor(
          widget.answers[i],
          currentPage: i == _answerIndex,
        ),
      ),
    );
  }

  /// Tap-to-expand for an answer picture: only the SELECTED card's CURRENT
  /// page opens the full-screen viewer, so an unselected (or off-screen) card
  /// still gets the carousel's own tap.
  VoidCallback? _imageTapFor(
    MinigamePlayerAnswer answer, {
    bool currentPage = true,
  }) {
    final bytes = answer.imageBytes;
    if (!widget.selected || !currentPage || !answer.hasImage || bytes == null) {
      return null;
    }
    return () => showFullScreenImage(context, bytes: bytes);
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
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: MinigameInks.of(context).muted),
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
    final metaStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: MinigameInks.of(context).muted);
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '$rank',
                style: AppTypography.displayLarge.copyWith(
                  // Playfair's ascender/descender padding makes the glyph read
                  // smaller; a tight line height lets the numeral's cap
                  // dominate.
                  fontSize: 58,
                  height: 0.9,
                  color: rankColor,
                ),
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
                      style: metaStyle,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text('·', style: metaStyle),
                  ),
                  const VShardIcon(size: 13),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      l10n.minigamesPrizeAmount(prize),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: metaStyle,
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

/// Horizontal rank indicator pinned to the card floor: the current position
/// over the total, flanked by tappable chevrons that step to the previous/next
/// rank page, over a hairline track filled to the current position. This is the
/// axis-correct affordance for the horizontally-paged carousel — the vertical
/// [PageView] is signalled separately by [_AnswerRail]. Hidden when there is a
/// single rank.
class _RankPager extends StatelessWidget {
  const _RankPager({
    required this.index,
    required this.count,
    required this.onPrevious,
    required this.onNext,
  });

  final int index;
  final int count;

  /// Steps to the previous/next rank page; null at either end.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final hasPrev = index > 0;
    final hasNext = index < count - 1;
    return Semantics(
      label: '${index + 1} / $count',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RankChevron(icon: Icons.chevron_left, onTap: onPrevious),
              const SizedBox(width: AppSpacing.sm),
              IgnorePointer(
                child: Text(
                  '${index + 1} / $count',
                  style: AppTypography.labelMedium.copyWith(
                    color: hasPrev || hasNext
                        ? MinigameInks.of(context).muted
                        : context.palette.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RankChevron(icon: Icons.chevron_right, onTap: onNext),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          IgnorePointer(
            child: SizedBox(
              width: 96,
              height: 2,
              child: ColoredBox(
                color: MinigameInks.of(context).hairline,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (index + 1) / count,
                    heightFactor: 1,
                    child: ColoredBox(color: MinigameInks.of(context).primary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single pager chevron: a >=44pt tap target that steps one rank page.
/// Dimmed and inert at either end of the ranking.
class _RankChevron extends StatelessWidget {
  const _RankChevron({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final l10n = MaterialLocalizations.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: icon == Icons.chevron_left
            ? l10n.previousPageTooltip
            : l10n.nextPageTooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? MinigameInks.of(context).primary : context.palette.mutedForeground,
          ),
        ),
      ),
    );
  }
}

/// First-run affordance for the horizontally-paged rank carousel: a one-line
/// hint that swiping reveals more ranks. Dismisses on the first page change or
/// a tap.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final message = AppLocalizations.of(context).minigamesLeaderboardSwipeHint;
    return Semantics(
      button: true,
      label: message,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swipe,
                size: 16,
                color: MinigameInks.of(context).muted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: MinigameInks.of(context).muted,
                ),
              ),
            ],
          ),
        ),
      ),
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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.badgeRed,
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
            style: AppTypography.labelSmall.copyWith(
              color: context.palette.foreground,
              shadows: AppTypography.legibilityShadows,
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
            color: context.palette.foreground,
            height: 1.25,
            shadows: AppTypography.legibilityShadows,
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
class _AnswerPage extends ConsumerWidget {
  const _AnswerPage({
    required this.answer,
    required this.l10n,
    this.onImageLoaded,
    this.onImageTap,
  });

  final MinigamePlayerAnswer answer;
  final AppLocalizations l10n;
  final VoidCallback? onImageLoaded;

  /// Opens the shared full-screen viewer. Only wired on the selected card's
  /// picture, so an unselected card still receives the carousel's own tap.
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = answer.hasImage
        ? MinigameBleedImage(
            image: MemoryImage(answer.imageBytes!),
            onImageLoaded: onImageLoaded,
          )
        : null;
    final body = Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          if (onImageTap != null)
            GestureDetector(onTap: onImageTap, child: image)
          else
            image,
        // The answer TEXT is a full-page overlay anchored to the picture's
        // displayed rect — the same image-aligned placement as the play
        // reaction window. Clipped to the page.
        if (answer.hasText)
          Positioned.fill(
            child: IgnorePointer(
              child: MinigameAnswerText(
                text: answer.text!,
                layout: answer.layout,
                image: answer.hasImage ? MemoryImage(answer.imageBytes!) : null,
              ),
            ),
          )
        // Non-text states (passed / empty) keep the centered body in the space
        // the pinned prompt/footer leave open (the picture stays full-bleed
        // behind them).
        else
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                VHeaderMetrics.heroTopPad(MediaQuery.paddingOf(context).top) +
                    VHeaderMetrics.titleRowHeight +
                    VHeaderMetrics.headerOuterPad * 2,
                AppSpacing.cardPadding,
                AppSpacing.cardPadding,
              ),
              child: Center(child: _buildBody(context)),
            ),
          ),
      ],
    );

    final answerId = answer.id;
    if (answerId == null || answerId.isEmpty) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => showReportSheet(
        context,
        ref,
        targetType: answer.hasImage ? 'minigame_image' : 'minigame_answer',
        targetId: answerId,
        title: l10n.reportMinigameAnswer,
      ),
      child: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (answer.passed) {
      return Text(
        l10n.minigamesPasarSkipped,
        textAlign: TextAlign.center,
        style: AppTypography.headlineSmall.copyWith(
          fontFamily: AppTypography.quicksand,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
          color: MinigameInks.of(context).muted,
        ),
      );
    }
    return Text(
      '—',
      textAlign: TextAlign.center,
      style: AppTypography.headlineMedium.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: context.palette.mutedForeground,
      ),
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
            color: MinigameInks.of(context).primary,
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MinigameInks.of(context).muted,
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
              color: i == index
                  ? MinigameInks.of(context).primary
                  : MinigameInks.of(context).muted,
              borderRadius: BorderRadius.circular(AppRadius.xs),
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
              ReactionEmoji(
                kind: e.key,
                fontSize: AppTypography.titleLarge.fontSize!,
              ),
              const SizedBox(width: 2),
              Text(
                '${e.value}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MinigameInks.of(context).muted,
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
