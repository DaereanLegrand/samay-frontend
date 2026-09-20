import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/utils/image_processor.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/finished_leaderboard.dart';
import 'package:samay/features/minigames/widgets/minigame_answer_text.dart';
import 'package:samay/features/minigames/widgets/minigame_bleed_image.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/features/minigames/widgets/reaction_rise.dart';
import 'package:samay/features/minigames/widgets/truth_dare_choice_button.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/full_screen_image.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

/// The subject's currently-picked reto picture for one session, before submit.
/// Lifted to the screen level so the picture can render as a full-viewport
/// background BEHIND the (transparent) header, exactly like the finished
/// leaderboard's full-bleed image. The answer editor is the only writer; the
/// value is cleared on submit/pass, and `autoDispose` tears it down when the
/// play screen unmounts (never touched from `dispose`, which cannot use `ref`).
final _pickedAnswerImageProvider = StateProvider.autoDispose
    .family<XFile?, String>((ref, sessionId) => null);

/// The CURRENT by_turns round's answer picture, already downloaded + decrypted
/// locally by [_AnswerPreview]. Lifted to the screen so the reaction window can
/// render it as a full-viewport background — the SAME full-bleed presentation
/// as the editor's picked picture and the leaderboard answer pages
/// (2026-09-17 directive). Keyed by `sessionId/round`, so a round flip drops the
/// previous picture automatically.
final _answerImageProvider = StateProvider.autoDispose
    .family<Uint8List?, String>((ref, key) => null);

/// The CURRENT by_turns answer's decrypted payload (text + on-canvas layout),
/// lifted by [_AnswerPreview] so the reaction window can render the answer text
/// as a full-viewport overlay anchored to the answer picture — the same
/// image-aligned placement the author arranged (2026-09-17). Keyed by
/// `sessionId/round`.
final _answerPayloadProvider = StateProvider.autoDispose
    .family<MinigameAnswerPayload?, String>((ref, key) => null);

/// Clips a full-viewport overlay so nothing paints inside the header band
/// (`y < headerBottom`) — the header must always stay visually on top of the
/// picture overlays, without the overlay having to change its own coordinate
/// space (2026-09-17).
class _BelowHeaderClipper extends CustomClipper<Rect> {
  const _BelowHeaderClipper(this.headerBottom);

  final double headerBottom;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, headerBottom, size.width, size.height);

  @override
  bool shouldReclip(_BelowHeaderClipper oldClipper) =>
      oldClipper.headerBottom != headerBottom;
}

/// The shared full-bleed picture backdrop used by the editor's picked picture
/// and the reaction window's answer picture (2026-09-17 standardization): the
/// blurred-mirror [MinigameBleedImage] plus two gradient scrims — dark under the
/// header, dark behind the bottom controls, clear in the middle so the picture
/// keeps full presence (leaderboard voice).
class _BleedImageBackdrop extends StatelessWidget {
  const _BleedImageBackdrop({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MinigameBleedImage(image: image),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent],
              stops: [0, 0.32],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xE6000000)],
              stops: [0.6, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// The subject's picked reto picture as the screen background: an opaque
/// blurred-mirror fill with the complete picture `contain` on top
/// ([MinigameBleedImage]), a legibility scrim, and a remove (×) control
/// anchored INSIDE the picture's own rendered rect — never in the letterbox
/// bands.
class _PickedImageBackground extends StatefulWidget {
  const _PickedImageBackground({
    required this.path,
    required this.onRemove,
    required this.removeTooltip,
  });

  final String path;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  State<_PickedImageBackground> createState() => _PickedImageBackgroundState();
}

class _PickedImageBackgroundState extends State<_PickedImageBackground> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  /// Resolves the picture's intrinsic size so the × can be placed on the
  /// DISPLAYED rect (the `contain` fit centers the image inside the viewport).
  void _resolve() {
    final stream = FileImage(
      File(widget.path),
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (mounted) setState(() => _imageSize = size);
    });
    stream.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final imageSize = _imageSize;
        Rect? rect;
        if (imageSize != null &&
            imageSize.width > 0 &&
            imageSize.height > 0 &&
            box.width > 0 &&
            box.height > 0) {
          final fitted = applyBoxFit(BoxFit.contain, imageSize, box);
          rect = Alignment.center.inscribe(
            fitted.destination,
            Offset.zero & box,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _BleedImageBackdrop(image: FileImage(File(widget.path))),
              ),
            ),
            if (rect != null)
              Positioned(
                top: rect.top + AppSpacing.xs,
                right: (box.width - rect.right) + AppSpacing.xs,
                child: IconButton(
                  onPressed: widget.onRemove,
                  tooltip: widget.removeTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  icon: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 15,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Verdad o Reto play screen (150/190/201 + 202_minigame_play_v2).
///
/// 202 answer-first flow: the server randomly selects the subject, any
/// participant taps Verdad or Reto (the reveal RPC draws a random prompt),
/// the SUBJECT submits their E2EE answer (text; image for reto) or taps
/// Pasar — and ONLY then do the other participants react (one emoji each).
/// By-turns rounds advance once every non-subject participant has reacted.
///
/// 202 mode + anonymous support: async mode renders the caller's per-player
/// progress + the reactable-rounds list; anonymous mode shows temp nicknames
/// (default `anónimoXXX`) instead of usernames until the leaderboard.
class TruthDareScreen extends ConsumerWidget {
  const TruthDareScreen({super.key, required this.sessionId});

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
    // The subject's picked reto picture, lifted to the screen so it can render
    // as a full-viewport background behind the transparent header (2026-09-15
    // directive). Only the by-turns subject editor, before the answer lands.
    final pickedImage = ref.watch(_pickedAnswerImageProvider(sessionId));
    final playingState = game.valueOrNull;
    final showImageBackground =
        pickedImage != null &&
        playingState != null &&
        !playingState.isFinished &&
        playingState.skeleton.playMode == MinigamePlayMode.byTurns &&
        playingState.skeleton.subjectId == myId &&
        playingState.skeleton.answer == null;
    // The reaction window's answer picture, lifted by [_AnswerPreview] once it
    // has downloaded + decrypted it. Same full-viewport backdrop as the editor's
    // picked picture and the leaderboard pages (2026-09-17 standardization).
    final answerRound = playingState?.skeleton.answer?.round;
    final answerImageBytes = answerRound == null
        ? null
        : ref.watch(_answerImageProvider('$sessionId/$answerRound'));
    final showAnswerBackground =
        answerImageBytes != null && !(playingState?.isFinished ?? false);
    // The reaction window's answer TEXT, lifted by [_AnswerPreview] and rendered
    // as a full-viewport overlay anchored to the answer picture (image-aligned).
    final answerPayload = answerRound == null
        ? null
        : ref.watch(_answerPayloadProvider('$sessionId/$answerRound'));
    final answerText = answerPayload?.text;
    final answerHasImage =
        (playingState?.skeleton.answer?.imageStoragePath?.isNotEmpty ?? false);
    // Wait for the picture before anchoring the text to it (no first-frame
    // jump): a text-only answer needs no picture.
    final showAnswerText =
        (answerText?.isNotEmpty ?? false) &&
        (!answerHasImage || answerImageBytes != null) &&
        !(playingState?.isFinished ?? false);
    // The revealed prompt, rendered by the SCREEN over the picture for EVERY
    // play state (by-turns editor + reaction, and async), never by the cards —
    // and always CLIPPED below the header so neither the pill nor its diffusion
    // can paint over the header (2026-09-17 refactor).
    final promptSkeleton = playingState?.skeleton;
    final screenPrompt =
        promptSkeleton == null || (playingState?.isFinished ?? false)
        ? null
        : truthDarePromptBody(promptSkeleton.prompt);
    final screenStatusTop = MediaQuery.paddingOf(context).top;
    final screenHeaderBottom =
        screenStatusTop + VHeaderMetrics.barHeight(screenStatusTop);
    // The reto picture picker ("Añadir imagen") is rendered by the SCREEN,
    // directly BELOW the prompt banner (2026-09-17) — it must never sit behind
    // the question. Only the by-turns subject editor, before the answer lands,
    // when no picture is picked yet and the prompt is a RETO.
    final showPickImageButton =
        pickedImage == null &&
        screenPrompt != null &&
        playingState != null &&
        !playingState.isFinished &&
        playingState.skeleton.playMode == MinigamePlayMode.byTurns &&
        playingState.skeleton.subjectId == myId &&
        playingState.skeleton.answer == null &&
        truthDareKindFromWire(playingState.skeleton.promptType) ==
            TruthDareKind.dare;
    final roster =
        ref.watch(minigameParticipantsProvider(sessionId)).valueOrNull ??
        const <MinigameParticipant>[];
    final aliases = ref.watch(minigameAliasesProvider(sessionId)).valueOrNull;
    // The lowercase minigame name — the two-line bar's line 2 (and the plain
    // single-line fallback for states without a current player).
    final gameNameLower = session.valueOrNull == null
        ? l10n.minigamesPlayTitle.toLowerCase()
        : minigameGameNameLower(
            l10n,
            session.valueOrNull!['game_type'] as String?,
          );
    final headerTitle = _headerTitle(
      game: game,
      gameNameLower: gameNameLower,
      roster: roster,
      aliases: aliases,
      myId: myId,
      l10n: l10n,
    );

    // The finished match is rendered full-bleed: the carousel centers on the
    // WHOLE viewport and the floating back arrow is the only header (mirroring
    // the attendance QR screen), so nothing eats into the vertical centering.
    // The creator's "complete" action is pointless once the match is already
    // settled, so it is dropped here — the back arrow exits.
    if (game.valueOrNull?.isFinished ?? false) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            FinishedLeaderboard(sessionId: sessionId),
            Align(
              alignment: Alignment.topLeft,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: VHeaderMetrics.heroTopPad(
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
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The subject's picked picture as a full-viewport background BEHIND
          // the transparent header (2026-09-15) — edge to edge, blurred fill
          // fully under the bar, with the remove (×) riding ON the image's own
          // rect (never the letterbox).
          if (showImageBackground)
            Positioned.fill(
              child: _PickedImageBackground(
                path: pickedImage.path,
                removeTooltip: l10n.minigamesAnswerRemoveImage,
                onRemove: () {
                  final notifier = ref.read(
                    _pickedAnswerImageProvider(sessionId).notifier,
                  );
                  notifier.state = null;
                },
              ),
            ),
          // The reaction window's answer picture, full-viewport behind the
          // transparent header — the same backdrop as the editor/leaderboard.
          if (showAnswerBackground)
            Positioned.fill(
              child: IgnorePointer(
                child: _BleedImageBackdrop(
                  image: MemoryImage(answerImageBytes),
                ),
              ),
            ),
          // The answer TEXT, full-viewport over the picture and anchored to its
          // displayed rect, so the author's placement is identical on every
          // device (2026-09-17). Clipped BELOW the header (the header must stay
          // on top) and to the viewport.
          if (showAnswerText)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRect(
                  clipper: _BelowHeaderClipper(screenHeaderBottom),
                  child: MinigameAnswerText(
                    text: answerText!,
                    layout: answerPayload!.layout,
                    image: answerHasImage
                        ? MemoryImage(answerImageBytes!)
                        : null,
                  ),
                ),
              ),
            ),
          VHeaderBar(
            titleWidget: headerTitle,
            title: headerTitle == null ? gameNameLower : null,
            actions: [
              if (isCreator)
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    shadows: AppTypography.legibilityShadows,
                  ),
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

                // The async deadline caption, fully capitalized at a smaller size
                // than the body copy, centered above the async panel. (The
                // by-turns round counter lives in the header's second line.)
                const captionStyle = TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedStrong,
                  shadows: AppTypography.legibilityShadows,
                );
                final isByTurns = skeleton.playMode == MinigamePlayMode.byTurns;
                final showAsyncDeadline =
                    !isByTurns && skeleton.asyncEndsAt != null;

                Widget buildAnswerCard({bool fillHeight = false}) {
                  final body = isMyTurn
                      ? (skeleton.answer == null
                            ? _AnswerCard(
                                sessionId: sessionId,
                                state: state,
                                l10n: l10n,
                              )
                            // The subject answered: their device must NOT stay
                            // stuck on the editor (defect B) — show the read-only
                            // waiting card instead.
                            : _SubjectWaitingCard(
                                sessionId: sessionId,
                                state: state,
                                l10n: l10n,
                                roster: roster,
                                aliases: aliases,
                              ))
                      : _WaitingCard(
                          sessionId: sessionId,
                          state: state,
                          l10n: l10n,
                          roster: roster,
                          aliases: aliases,
                        );

                  // Full-height (the by-turns SUBJECT editor): the body fills the
                  // card so its answer/pass bar can pin to the screen floor,
                  // keyboard-aware via the Scaffold's resize inset. Same card
                  // chrome (surface + horizontal hairlines).
                  if (fillHeight) {
                    // Transparent over a picked full-bleed picture (the image
                    // IS the backdrop) AND while choosing Verdad/Reto — no
                    // surface chrome behind the two CTAs (2026-09-15
                    // directive). Opaque surface chrome only for the editor.
                    final choosingTruthDare =
                        truthDarePromptBody(skeleton.prompt) == null;

                    // While choosing Verdad/Reto the CTA container spans the
                    // FULL region between the header's bottom edge and the
                    // device bottom, so the pair centers on that whole area.
                    if (choosingTruthDare) {
                      return Stack(fit: StackFit.expand, children: [body]);
                    }

                    // The SUBJECT editor is chrome-less too (2026-09-15
                    // directive): transparent surface, no hairlines — matching
                    // the choice state and the full-bleed leaderboard voice.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: body,
                          ),
                        ),
                      ],
                    );
                  }

                  // The by-turns answer/waiting card is transparent AND fills
                  // the whole region between the header and the pinned bottom
                  // line/row, with the answer body CENTERED (2026-09-15
                  // uniformity directive). The revealed QUESTION is rendered by
                  // the SCREEN, behind the header and over the picture — never
                  // by the card, so it can never paint in front of the header
                  // (2026-09-17).
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.cardPadding,
                            ),
                            child: body,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // The by-turns SUBJECT editor fills the body so its answer/pass bar
                // stays pinned to the screen floor (keyboard-aware).
                if (isByTurns && isMyTurn && skeleton.answer == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: buildAnswerCard(fillHeight: true),
                  );
                }

                // Async mode keeps its scrollable panel stack. The reactable
                // tiles are FULL-WIDTH (edge to edge) so their answer pictures
                // bleed like the rest (2026-09-17 standardization); the proxy
                // card / captions pad themselves.
                if (skeleton.playMode == MinigamePlayMode.async) {
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (showAsyncDeadline) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: Text(
                            l10n
                                .minigamesAsyncTimerEnds(
                                  _formatDate(skeleton.asyncEndsAt!),
                                )
                                .toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: captionStyle,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      _AsyncPanel(sessionId: sessionId, state: state),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  );
                }

                // by_turns: the answer card fills the body and the reaction
                // deck is pinned to the floor exactly like the subject's
                // Responder/Pasar bar. The "esperando X/Y reacciones…" line
                // rides at the bottom, directly ABOVE the reaction row
                // (2026-09-15 uniformity directive).
                final canReact = canReactToCurrentRound(
                  skeleton,
                  callerId: myId,
                );
                final answer = skeleton.answer;
                final showWaitingLine = answer != null && !answer.passed;
                // Tap-to-expand (2026-09-17 directive: reacting + leaderboard):
                // while the answer picture is up, tapping the content region
                // opens the shared full-screen viewer. The reaction deck below
                // is a SIBLING, so its buttons keep their own taps.
                return Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: answerImageBytes == null
                            ? null
                            : () => _showFullAnswerImage(
                                context,
                                answerImageBytes,
                              ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: _ReactionRiseCanvas(
                            sessionId: sessionId,
                            child: buildAnswerCard(),
                          ),
                        ),
                      ),
                    ),
                    if (showWaitingLine)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: _ReactionsWaitingLine(
                          skeleton: skeleton,
                          roster: roster,
                          l10n: l10n,
                        ),
                      ),
                    if (canReact) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _ReactionRow(sessionId: sessionId),
                    ] else
                      // No reaction row (subject's own post-answer view): keep
                      // the waiting line clear of the home indicator.
                      const SafeArea(top: false, child: SizedBox.shrink()),
                  ],
                );
              },
            ),
          ),
          // The revealed prompt: rendered by the SCREEN directly below the
          // header, with the reto picture picker ("Añadir imagen") DIRECTLY
          // BELOW it (2026-09-17). Painted LAST so the picker stays tappable
          // above the editor canvas (whose full-canvas gesture surface would
          // otherwise swallow the tap).
          if (screenPrompt != null)
            Positioned(
              top: screenHeaderBottom,
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                // Column gives the pill an unbounded height, so it sits at the
                // TOP of the region instead of centering in it.
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: IgnorePointer(
                        child: _PromptBanner(text: screenPrompt),
                      ),
                    ),
                    if (showPickImageButton)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          0,
                        ),
                        child: VButton.outlined(
                          onPressed: () => _pickAnswerImage(context, ref),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image_outlined, size: 18),
                              const SizedBox(width: AppSpacing.sm),
                              Text(l10n.minigamesAnswerImageLabel),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Picks the reto answer picture from the gallery and lifts it to the
  /// screen-level provider (the full-bleed background + the remove ×). The
  /// picker button is rendered by the SCREEN, below the prompt banner.
  Future<void> _pickAnswerImage(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        ref.read(_pickedAnswerImageProvider(sessionId).notifier).state = picked;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  /// The rich two-line [VHeaderBar] title for the play screen, per state:
  ///
  ///   * by_turns playing → "turno de {subject}" with the outlined name
  ///     (small muted prefix + the user's name) + the lowercase minigame name;
  ///     when the subject IS the caller → "tu turno…".
  ///   * async playing, caller still owes rounds → "respondiendo".
  ///   * async playing, caller has a reactable round → "respuesta de {author}".
  ///   * finished → the leaderboard word; loading → "waiting…"; error →
  ///     "error" — each with the lowercase minigame name under it.
  ///   * not-yet-playing (setup skeleton via a direct route / cancelled
  ///     countdown) and async-done-with-nothing-to-react → null, so the bar
  ///     falls back to the plain lowercase minigame-name [VHeaderBar.title].
  Widget? _headerTitle({
    required AsyncValue<MinigameGameState> game,
    required String gameNameLower,
    required List<MinigameParticipant> roster,
    required Map<String, String>? aliases,
    required String? myId,
    required AppLocalizations l10n,
  }) {
    return game.when(
      loading: () => MinigameHeaderTitle(
        word: l10n.minigamesBarWaiting,
        secondary: gameNameLower,
      ),
      error: (_, _) => MinigameHeaderTitle(
        word: l10n.minigamesBarError,
        secondary: gameNameLower,
      ),
      data: (state) {
        final skeleton = state.skeleton;
        // Line 2 carries the by-turns round counter in place of the game name
        // (2026-09-17 directive); every other state keeps the game name.
        final roundTarget = skeleton.roundTarget;
        final headerSecondary =
            skeleton.playMode == MinigamePlayMode.byTurns && roundTarget != null
            ? l10n.minigamesRoundCounter(skeleton.round + 1, roundTarget)
            : gameNameLower;
        if (state.isFinished) {
          return MinigameHeaderTitle(
            word: l10n.minigamesBarLeaderboard,
            secondary: headerSecondary,
          );
        }
        if (skeleton.phase != MinigamePhase.playing) {
          // Setup/countdown: no current player — the plain minigame-name bar
          // title is the fallback (the lobby owns the pre-play UI).
          return null;
        }
        if (skeleton.playMode == MinigamePlayMode.async) {
          // The caller still owes rounds → they answer next.
          final progress = skeleton.roundMap[myId] ?? 0;
          if (progress < skeleton.asyncRoundsPerPlayer) {
            return MinigameHeaderTitle(
              word: l10n.minigamesBarResponding,
              secondary: headerSecondary,
            );
          }
          // Caller is done answering — is there someone's answer to react to?
          final reactable = reactableAsyncRounds(skeleton, callerId: myId);
          if (reactable.isNotEmpty) {
            final authorName = _displayNameFor(
              reactable.first.subjectId,
              roster,
              aliases,
              skeleton,
              l10n,
            );
            if (authorName.isNotEmpty) {
              return MinigameHeaderTitle(
                prefix: l10n.minigamesResponseBarPrefix,
                name: authorName,
                suffix: l10n.minigamesResponseBarSuffix,
                secondary: headerSecondary,
              );
            }
            return MinigameHeaderTitle(
              word: l10n.minigamesBarResponding,
              secondary: headerSecondary,
            );
          }
          // Nothing owed, nothing to react to — the plain name fallback.
          return null;
        }
        // by_turns playing: the subject is server-guaranteed (never null once
        // playing). The name resolution is defensive — a subject that cannot
        // be resolved renders the generic turn line, never a raw UUID.
        // The caller's OWN turn reads "Tu turno…" (mirror of the async
        // own-action header) instead of "turno de <my name>".
        if (myId != null && skeleton.subjectId == myId) {
          return MinigameHeaderTitle(
            word: l10n.minigamesYourTurn,
            secondary: headerSecondary,
          );
        }
        final subjectName = _displayNameFor(
          skeleton.subjectId,
          roster,
          aliases,
          skeleton,
          l10n,
        );
        if (subjectName.isEmpty) {
          return MinigameHeaderTitle(
            word: l10n.minigamesTurnGeneric.toLowerCase(),
            secondary: headerSecondary,
          );
        }
        return MinigameHeaderTitle(
          prefix: l10n.minigamesTurnBarPrefix,
          name: subjectName,
          suffix: l10n.minigamesTurnBarSuffix,
          secondary: headerSecondary,
        );
      },
    );
  }

  /// The display name of a participant: the temp nickname in anonymous mode
  /// (falling back to the localized default), else the username. A raw UUID
  /// is NEVER shown (2026-08-30 directive).
  String _displayNameFor(
    String? userId,
    List<MinigameParticipant> roster,
    Map<String, String>? aliases,
    GameTurnSkeleton skeleton,
    AppLocalizations l10n,
  ) {
    if (userId == null) return '';
    if (skeleton.anonymous) {
      final alias = aliases?[userId];
      if (alias != null && alias.isNotEmpty) return alias;
      return defaultAnonAlias(l10n, seed: userId);
    }
    for (final participant in roster) {
      if (participant.id == userId) {
        final name = participant.username.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return '';
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$mi';
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

/// Opens [bytes] in a full-viewport, full-bleed viewer (opaque disco-black
/// backdrop): the image scales with [BoxFit.contain] so it is never cropped.
/// An X at the top-right dismisses it; tapping the image, the backdrop, or
/// the system back gesture also closes it.
void _showFullAnswerImage(BuildContext context, Uint8List bytes) {
  // Shared full-screen viewer (zoomable) — see `showFullScreenImage`.
  showFullScreenImage(context, bytes: bytes);
}

/// A tiny BuildContext holder used by the anonymous default-alias resolver.

/// The current-turn subject's body (202 answer-first): reveals the prompt
/// (Verdad / Reto) when none is shown; once revealed, the subject types
/// their E2EE answer (text; image optional for reto) or taps Pasar. The
/// answer is encrypted client-side with [minigameCipherProvider] before the
/// RPC — the server only sees ciphertext.
class _AnswerCard extends ConsumerStatefulWidget {
  const _AnswerCard({
    required this.sessionId,
    required this.state,
    required this.l10n,
  });

  final String sessionId;
  final MinigameGameState state;
  final AppLocalizations l10n;

  @override
  ConsumerState<_AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends ConsumerState<_AnswerCard> {
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();
  bool _submitting = false;

  /// The answer canvas's on-screen origin + the picked picture's intrinsic
  /// size, so the label can be positioned in PICTURE space (image-aligned)
  /// rather than in whatever widget canvas the device happens to lay out
  /// (2026-09-17). [Offset.zero] until the first post-frame measurement.
  final _canvasKey = GlobalKey();
  Offset? _canvasOrigin;
  ImageStream? _pickedStream;
  ImageStreamListener? _pickedListener;
  Size? _pickedImageSize;

  /// True while the answer label is in its temporary editing state: it moves to
  /// the canvas center, drops rotation/scale, and shows the text cursor.
  bool _editing = false;

  /// The author's on-canvas placement of the typed answer (2026-09-15): the
  /// two-finger gesture writes it, and it rides the E2EE payload on submit.
  MinigameAnswerLayout _layout = MinigameAnswerLayout.center;

  /// The picked reto picture (screen-lifted so it can back the whole
  /// viewport); null when none.
  XFile? get _image => ref.read(_pickedAnswerImageProvider(widget.sessionId));

  @override
  void initState() {
    super.initState();
    // The floating answer label mirrors the typed text live.
    _answerController.addListener(_onAnswerChanged);
    _answerFocus.addListener(_onAnswerFocusChanged);
  }

  @override
  void dispose() {
    if (_pickedListener != null) {
      _pickedStream?.removeListener(_pickedListener!);
    }
    _answerController.removeListener(_onAnswerChanged);
    _answerFocus.removeListener(_onAnswerFocusChanged);
    _answerFocus.dispose();
    _answerController.dispose();
    // The lifted picture provider is autoDispose and the play screen always
    // watches it: leaving the screen tears it down. Never touch `ref` here —
    // Riverpod has already disposed this element (mutation is a crash).
    super.dispose();
  }

  /// Measures the canvas's global origin (post-frame) so viewport-space
  /// reference coordinates can be mapped into it.
  void _measureCanvas() {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    if (mounted && _canvasOrigin != origin) {
      setState(() => _canvasOrigin = origin);
    }
  }

  /// Resolves the picked picture's intrinsic size (drives the reference rect).
  void _resolvePickedImage() {
    final image = _image;
    final provider = image == null ? null : FileImage(File(image.path));
    final stream = provider?.resolve(createLocalImageConfiguration(context));
    if (stream?.key == _pickedStream?.key) return;
    if (_pickedListener != null) {
      _pickedStream?.removeListener(_pickedListener!);
    }
    _pickedStream = stream;
    _pickedListener = null;
    if (stream == null) {
      if (_pickedImageSize != null) setState(() => _pickedImageSize = null);
      return;
    }
    _pickedListener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (mounted && size != _pickedImageSize) {
        setState(() => _pickedImageSize = size);
      }
    });
    stream.addListener(_pickedListener!);
  }

  void _onAnswerChanged() {
    if (mounted) setState(() {});
  }

  /// Mirrors the answer field's focus into [_editing] so the label can animate
  /// between its placed transform and the centered edit presentation.
  void _onAnswerFocusChanged() {
    if (mounted && _editing != _answerFocus.hasFocus) {
      setState(() => _editing = _answerFocus.hasFocus);
    }
  }

  /// Opens the centered editor (the field's `autofocus` then claims focus).
  void _beginAnswerEditing() {
    if (!_editing) setState(() => _editing = true);
  }

  @override
  Widget build(BuildContext context) {
    final prompt = truthDarePromptBody(widget.state.skeleton.prompt);
    if (prompt == null) {
      // Choosing Verdad/Reto (2026-09-15 directive): two borderless dark CTAs
      // stacked one per row, the pair centered horizontally AND vertically in
      // the (now transparent) answer container. Inset from the screen's
      // rounded corners; never pinned into the home-indicator zone.
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TruthDareChoiceButton(
                  label: widget.l10n.minigamesTruth.toLowerCase(),
                  onPressed: () => _reveal(TruthDareKind.truth),
                ),
                const SizedBox(height: AppSpacing.md),
                TruthDareChoiceButton(
                  label: widget.l10n.minigamesDare.toLowerCase(),
                  onPressed: () => _reveal(TruthDareKind.dare),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The answer lives ONLY as the floating on-canvas label below (no
        // duplicate field near the question). Tapping it opens the centered
        // editor; the answer/pass bar stays pinned to the floor and rides the
        // keyboard (Scaffold resize inset).
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvas = Size(constraints.maxWidth, constraints.maxHeight);
              final typed = _answerController.text.trim();
              // Resolve the picked picture + re-measure the canvas POST-FRAME
              // (both may call setState) so the reference rect is
              // picture-aligned without rebuilding during build.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _measureCanvas();
                _resolvePickedImage();
              });
              // Picture-anchored reference rect, in VIEWPORT space (the picture
              // backs the whole viewport) mapped into this canvas.
              final refViewport = minigameImageRect(
                _pickedImageSize,
                MediaQuery.sizeOf(context),
              );
              final origin = _canvasOrigin ?? Offset.zero;
              final ref = refViewport.shift(-origin);
              final anchorX = _editing
                  ? canvas.width / 2
                  : ref.left + _layout.x * ref.width;
              final anchorY = _editing
                  ? canvas.height / 2
                  : ref.top + _layout.y * ref.height;
              return Stack(
                key: _canvasKey,
                fit: StackFit.expand,
                children: [
                  // Tapping empty canvas settles the editor back to its place.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _answerFocus.unfocus,
                  ),
                  AnimatedPositioned(
                    duration: SamayDurations.standard,
                    curve: SamayDurations.defaultCurve,
                    left: anchorX,
                    top: anchorY,
                    child: _FloatingAnswerLabel(
                      text: typed,
                      placeholder: widget.l10n.minigamesAnswerPlaceholder,
                      refRect: ref,
                      layout: _layout,
                      editing: _editing,
                      controller: _answerController,
                      focusNode: _answerFocus,
                      onChanged: (next) => setState(() => _layout = next),
                      onEdit: _beginAnswerEditing,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
          ),
          child: Text(
            widget.l10n.minigamesAnswerPasarLine,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedStrong, fontSize: 12),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          // Bottom action bar: inset from the display's rounded corners
          // (`screenHorizontal`, Apple HIG) and lifted above the home-indicator
          // / gesture-pill strip by the SafeArea inset.
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
                    onPressed: _submitting ? null : _submitAnswer,
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
        ),
      ],
    );
  }

  Future<void> _reveal(TruthDareKind kind) async {
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .reveal(kind);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  Future<void> _submitAnswer() async {
    final image = _image;
    final text = _answerController.text.trim();
    if (text.isEmpty && image == null) return;
    setState(() => _submitting = true);
    try {
      final cipher = ref.read(minigameCipherProvider(widget.sessionId));
      final round = widget.state.skeleton.round;
      AppLogger.instance.debug(
        'minigame submitAnswer start session=${widget.sessionId} round=$round '
        'hasText=${text.isNotEmpty} hasImage=${image != null} '
        'subject=${widget.state.skeleton.subjectId?.substring(0, 8)}…',
      );
      final textCipher = await cipher.encryptAnswerPayload(
        text: text,
        layout: _layout,
        round: round,
      );
      AppLogger.instance.debug(
        'minigame submitAnswer encrypted text session=${widget.sessionId} '
        'round=$round cipherLen=${textCipher.length}',
      );
      String? imagePath;
      if (image != null) {
        // Downscale + JPEG-encode BEFORE the E2EE encrypt (PERF-03/M-36): the
        // smaller JPEG plaintext becomes a smaller ciphertext, cutting storage
        // and per-viewer download+decrypt+decode time. Raw picked bytes never
        // leave the device — only the compressed JPEG is encrypted.
        final bytes = await ImageProcessor.compressBytes(
          Uint8List.fromList(await image.readAsBytes()),
        );
        final cipherBytes = await cipher.encryptAnswerImage(bytes, round);
        // The image NEVER rides the RPC payload as base64: upload the RAW
        // ciphertext bytes to the private `minigame_images` bucket and pass
        // the returned OBJECT PATH (defect B image half).
        imagePath = await ref
            .read(minigameServiceProvider)
            .uploadMinigameImage(widget.sessionId, round, cipherBytes);
        AppLogger.instance.debug(
          'minigame submitAnswer uploaded image session=${widget.sessionId} '
          'round=$round path=$imagePath',
        );
      }
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .submitAnswer(
            answerCiphertext: textCipher,
            imageStoragePath: imagePath,
          );
      AppLogger.instance.debug(
        'minigame submitAnswer RPC ok session=${widget.sessionId} round=$round',
      );
      // Drop the full-bleed background as the answer leaves the editor.
      ref.read(_pickedAnswerImageProvider(widget.sessionId).notifier).state =
          null;
    } catch (e, st) {
      AppLogger.instance.error(
        'minigame submitAnswer FAILED session=${widget.sessionId} '
            'round=${widget.state.skeleton.round} type=${e.runtimeType}: $e',
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
      // Drop the full-bleed background as the editor closes on a pass.
      ref.read(_pickedAnswerImageProvider(widget.sessionId).notifier).state =
          null;
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

/// The author's answer text as a single free-floating label (2026-09-15;
/// deduped 2026-09-15):
///
///   * resting — shows the placed [layout] (two-finger pan moves it, pinch
///     scales, twist rotates) and a one-finger TAP opens the editor;
///   * editing — the label temporarily eases to the canvas center, unrotated
///     and unscaled, and becomes a bare text field (cursor + keyboard). It
///     eases back to its placed transform when focus is lost.
///
/// The gesture math follows the industry-standard approach — the same one
/// `InteractiveViewer` uses: baseline the transform on the first two-finger
/// update, then apply the cumulative focal-point / scale / rotation deltas
/// relative to that baseline (so a one-finger drag that becomes a pinch never
/// jumps). [ScaleUpdateDetails.pointerCount] gates it to two fingers.
class _FloatingAnswerLabel extends StatefulWidget {
  const _FloatingAnswerLabel({
    required this.text,
    required this.placeholder,
    required this.refRect,
    required this.layout,
    required this.editing,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onEdit,
  });

  final String text;
  final String placeholder;

  /// The picture-anchored reference rect IN CANVAS COORDINATES: the layout's
  /// normalized x/y map onto it, so a placement stays on the same part of the
  /// picture on every device (2026-09-17).
  final Rect refRect;
  final MinigameAnswerLayout layout;
  final bool editing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<MinigameAnswerLayout> onChanged;
  final VoidCallback onEdit;

  @override
  State<_FloatingAnswerLabel> createState() => _FloatingAnswerLabelState();
}

class _FloatingAnswerLabelState extends State<_FloatingAnswerLabel> {
  /// The gesture baseline captured on the first TWO-finger update.
  Offset? _baseFocal;
  MinigameAnswerLayout? _baseLayout;
  double _baseScale = 1;
  double _baseRotation = 0;

  /// The base editor font size [MinigameAnswerLayout.scale] multiplies.
  static const double _baseFontSize = 24;

  static const TextStyle _baseStyle = TextStyle(
    fontFamily: AppTypography.quicksand,
    fontSize: _baseFontSize,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    shadows: AppTypography.legibilityShadows,
  );

  void _baseline(ScaleUpdateDetails details) {
    _baseFocal = details.focalPoint;
    _baseLayout = widget.layout;
    _baseScale = details.scale;
    _baseRotation = details.rotation;
  }

  void _onUpdate(ScaleUpdateDetails details) {
    // Two fingers only (explicit directive).
    if (details.pointerCount < 2) return;
    if (_baseLayout == null) {
      _baseline(details);
      return;
    }
    final base = _baseLayout!;
    final baseFocal = _baseFocal!;
    final ref = widget.refRect;
    if (ref.width <= 0 || ref.height <= 0) return;
    final cursorX = base.x * ref.width + (details.focalPoint.dx - baseFocal.dx);
    final cursorY =
        base.y * ref.height + (details.focalPoint.dy - baseFocal.dy);
    final scaleFactor = _baseScale == 0 ? 1.0 : details.scale / _baseScale;
    widget.onChanged(
      MinigameAnswerLayout(
        x: (cursorX / ref.width).clamp(0.0, 1.0),
        y: (cursorY / ref.height).clamp(0.0, 1.0),
        rotation: base.rotation + (details.rotation - _baseRotation),
        scale: (base.scale * scaleFactor).clamp(
          MinigameAnswerLayout.minScale,
          MinigameAnswerLayout.maxScale,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final editing = widget.editing;

    final Widget content;
    if (editing) {
      // Editing presentation: bare centered field (cursor + keyboard). The
      // wrapper animates to the canvas center / no rotation / scale 1.
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.refRect.width * 0.9),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: true,
          textAlign: TextAlign.center,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          cursorColor: AppColors.white,
          style: _baseStyle,
          onTapOutside: (_) => widget.focusNode.unfocus(),
          decoration: InputDecoration.collapsed(
            hintText: widget.placeholder,
            hintStyle: _baseStyle.copyWith(color: AppColors.mutedStrong),
          ),
        ),
      );
    } else {
      final hasText = widget.text.isNotEmpty;
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        // One-finger tap opens the centered editor; two-finger pan/pinch/twist
        // arrange the placed label.
        onTap: widget.onEdit,
        onScaleStart: (_) => _baseLayout = null,
        onScaleUpdate: _onUpdate,
        onScaleEnd: (_) => _baseLayout = null,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.refRect.width * 0.9),
          child: Text(
            hasText ? widget.text : widget.placeholder,
            textAlign: TextAlign.center,
            style: hasText
                ? _baseStyle
                : _baseStyle.copyWith(color: AppColors.mutedStrong),
          ),
        ),
      );
    }

    return FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: AnimatedRotation(
        turns: editing ? 0 : layout.rotation / (2 * math.pi),
        duration: SamayDurations.standard,
        curve: SamayDurations.defaultCurve,
        child: AnimatedScale(
          scale: editing ? 1 : layout.scale,
          duration: SamayDurations.standard,
          curve: SamayDurations.defaultCurve,
          child: content,
        ),
      ),
    );
  }
}

/// The prompt banner's display size (slightly above the 20px `headlineSmall`
/// base) and its `5em` corner radius — larger than the banner's own height, so
/// the hug-to-text panel renders as a pill.
const double _promptBannerFontSize = 22;
const double _promptBannerRadius = 5 * _promptBannerFontSize;

/// The prompt's soft backdrop: three stacked blurs of the SAME pill, each wider
/// and fainter than the last — `(sigma, alpha)` — so the darkness is strong
/// right behind the text and diffuses progressively into the picture with no
/// boundary (2026-09-17).
///
/// Why blurs of the shape and not `BoxShadow`: a shadow is cast by an opaque
/// silhouette, so it always keeps a visible edge no matter how large the blur
/// or spread. Feathering the shape ITSELF (each layer is a blurred pill) melts
/// the edge; the successive sigmas give the eased "strong at the start,
/// diffusing more and more" falloff.
///
/// The outer alphas are deliberately HIGH (darker tint) so the pill keeps the
/// prompt legible even over a LIGHT picked picture (2026-09-17 directive).
const List<(double sigma, double alpha)> _promptBannerLayers = [
  (8, 1.0),
  (36, 0.85),
  (92, 0.62),
];

/// The current prompt — a Verdad question or a Reto challenge — on a soft black
/// pill so it stays legible over the full-bleed picked-image background
/// (2026-09-17 directive). Hugs the text (centered); the pill melts into the
/// picture via [_promptBannerLayers]. Playfair Display w700 at
/// [_promptBannerFontSize].
class _PromptBanner extends StatelessWidget {
  const _PromptBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        // The blurs bleed past the pill — never clip them.
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (final (sigma, alpha) in _promptBannerLayers)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.discoBlack.withValues(alpha: alpha),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(_promptBannerRadius),
                    ),
                  ),
                ),
              ),
            ),
          // The label sizes the stack; the blurred layers fill its padded box.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: AppTypography.playfair,
                fontSize: _promptBannerFontSize,
                fontWeight: FontWeight.w700,
                // Lighter-tinted glyph shadow (a soft light halo) so the prompt
                // glows against the darker pill (2026-09-17 directive).
                shadows: [
                  Shadow(
                    color: AppColors.white.withValues(alpha: 0.45),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: AppColors.white.withValues(alpha: 0.22),
                    blurRadius: 48,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// The non-subject's view of the current by_turns round (202 answer-first):
/// the subject's submitted answer ciphertext (decrypted locally) once it
/// exists — with NO choice buttons. Before the answer the waiting line shows.
/// The revealed prompt is rendered by the SCREEN (behind the header).
class _WaitingCard extends ConsumerStatefulWidget {
  const _WaitingCard({
    required this.sessionId,
    required this.state,
    required this.l10n,
    required this.roster,
    required this.aliases,
  });

  final String sessionId;
  final MinigameGameState state;
  final AppLocalizations l10n;
  final List<MinigameParticipant> roster;
  final Map<String, String>? aliases;

  @override
  ConsumerState<_WaitingCard> createState() => _WaitingCardState();
}

class _WaitingCardState extends ConsumerState<_WaitingCard> {
  MinigameAnswerPayload? _decrypted;

  @override
  Widget build(BuildContext context) {
    final prompt = truthDarePromptBody(widget.state.skeleton.prompt);
    if (prompt == null) {
      return Text(
        widget.l10n.minigamesWaitingChoiceGeneric,
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      );
    }
    final answer = widget.state.skeleton.answer;
    final subjectName = _displayName(widget.state.skeleton.subjectId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (answer == null)
          Text(
            widget.l10n.minigamesAnswerWaiting,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          )
        else if (answer.passed)
          Text(
            widget.l10n.minigamesPasarSkipped,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedStrong),
          )
        else
          // The live "esperando X/Y reacciones…" tally now lives at the BOTTOM
          // of the by-turns screen (above the reaction row), rendered by the
          // screen — not inside the answer card (2026-09-15 directive).
          _AnswerPreview(
            sessionId: widget.sessionId,
            answer: answer,
            subjectName: subjectName,
            onDecrypted: (payload) => setState(() => _decrypted = payload),
            decrypted: _decrypted,
          ),
      ],
    );
  }

  String _displayName(String? userId) {
    if (userId == null) return '';
    if (widget.state.skeleton.anonymous) {
      final alias = widget.aliases?[userId];
      if (alias != null && alias.isNotEmpty) return alias;
      return defaultAnonAlias(widget.l10n, seed: userId);
    }
    for (final p in widget.roster) {
      if (p.id == userId) {
        final name = p.username.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return '';
  }
}

/// The "esperando X/Y reacciones…" progress line for the CURRENT by_turns
/// round's open reaction window (202 answer-first). Shows the live
/// distinct-voter reaction tally (emoji OR reactor-Pasar, matching the
/// server's auto-advance gate) against the roster minus the round's subject.
///
/// Rendered for EVERY participant — the subject and every reactor — so the
/// whole table watches the same countdown while the round stays open.
class _ReactionsWaitingLine extends StatelessWidget {
  const _ReactionsWaitingLine({
    required this.skeleton,
    required this.roster,
    required this.l10n,
  });

  final GameTurnSkeleton skeleton;
  final List<MinigameParticipant> roster;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final subjectId = skeleton.subjectId;
    final required = subjectId == null
        ? 0
        : (roster.length - 1).clamp(0, 1 << 31);
    final reacted = subjectId == null
        ? 0
        : (skeleton.reactionCount(subjectId) ?? 0);
    return Text(
      l10n.minigamesAnswerWaitingReactions(reacted, required),
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.mutedStrong, fontSize: 12),
    );
  }
}

/// The SUBJECT's post-submit view (defect B fix, 202_minigame_play_v2): once
/// the subject answered, `skeleton.answer` is set but `isMyTurn` stays true —
/// the input surface must be replaced by a READ-ONLY card: the subject's OWN
/// answer (decrypted locally). NO input, NO Responder, NO Pasar. A passed round
/// shows the Pasar-skipped suffix. The prompt is rendered by the SCREEN (behind
/// the header) and the "esperando X/Y reacciones…" line lives at the bottom.
class _SubjectWaitingCard extends ConsumerStatefulWidget {
  const _SubjectWaitingCard({
    required this.sessionId,
    required this.state,
    required this.l10n,
    required this.roster,
    required this.aliases,
  });

  final String sessionId;
  final MinigameGameState state;
  final AppLocalizations l10n;
  final List<MinigameParticipant> roster;
  final Map<String, String>? aliases;

  @override
  ConsumerState<_SubjectWaitingCard> createState() =>
      _SubjectWaitingCardState();
}

class _SubjectWaitingCardState extends ConsumerState<_SubjectWaitingCard> {
  MinigameAnswerPayload? _decrypted;

  @override
  Widget build(BuildContext context) {
    final prompt = truthDarePromptBody(widget.state.skeleton.prompt);
    final answer = widget.state.skeleton.answer;
    if (prompt == null || answer == null) {
      // Never reached in practice (the card renders only after an answer) —
      // a defensive fallback so a transient state never shows an empty card.
      return Text(
        widget.l10n.minigamesAnswerWaiting,
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      );
    }
    final subjectId = widget.state.skeleton.subjectId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (answer.passed)
          Text(
            widget.l10n.minigamesPasarSkipped,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedStrong),
          )
        else
          _AnswerPreview(
            sessionId: widget.sessionId,
            answer: answer,
            subjectName: _displayName(subjectId),
            onDecrypted: (payload) => setState(() => _decrypted = payload),
            decrypted: _decrypted,
          ),
        // The "esperando X/Y reacciones…" line is now rendered at the BOTTOM
        // of the by-turns screen (2026-09-15 directive), not inside the card.
      ],
    );
  }

  String _displayName(String? userId) {
    if (userId == null) return '';
    if (widget.state.skeleton.anonymous) {
      final alias = widget.aliases?[userId];
      if (alias != null && alias.isNotEmpty) return alias;
      return defaultAnonAlias(widget.l10n, seed: userId);
    }
    for (final p in widget.roster) {
      if (p.id == userId) {
        final name = p.username.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return '';
  }
}

/// Decrypts the subject's submitted E2EE answer (text payload + optional
/// picture) locally via [minigameCipherProvider] and LIFTS both to the screen
/// providers ([_answerPayloadProvider] / [_answerImageProvider]) for the
/// full-viewport, image-anchored overlays (2026-09-17). The card itself only
/// keeps the key-recovery / loading states. The server never held the
/// plaintext — this is the only place it appears.
///
/// Reinstall recovery (206_minigame_key_request, 2026-09-03): when the round
/// key is genuinely GONE from this device (a reinstall regenerated the E2EE
/// identity, so the pairwise self-heal can never decrypt the host's old-
/// identity bundles), the card enters a friendly recovery state instead of a
/// silent blank: a "requesting the key from another participant…" spinner
/// while the key ring works, then — if no holder is online — an explanatory
/// message with a Reintentar action.
class _AnswerPreview extends ConsumerStatefulWidget {
  const _AnswerPreview({
    required this.sessionId,
    required this.answer,
    required this.subjectName,
    required this.onDecrypted,
    required this.decrypted,
  });

  final String sessionId;
  final MinigameAnswer answer;
  final String subjectName;
  final ValueChanged<MinigameAnswerPayload> onDecrypted;
  final MinigameAnswerPayload? decrypted;

  @override
  ConsumerState<_AnswerPreview> createState() => _AnswerPreviewState();
}

class _AnswerPreviewState extends ConsumerState<_AnswerPreview> {
  bool _imageLoading = false;
  bool _started = false;

  /// Whether the round key was missing and a recovery pass is in flight or
  /// failed. `_KeyRecovery.none` = key present / decrypt path only.
  _KeyRecovery _recovery = _KeyRecovery.none;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _start();
    }
  }

  Future<void> _start() async {
    // Distinguish a GENUINELY missing key (reinstall — needs the key ring)
    // from a present-but-undecryptable blob (tamper — show nothing, as today).
    final cipher = ref.read(minigameCipherProvider(widget.sessionId));
    final round = widget.answer.round;
    final hasContent =
        (widget.answer.answerCiphertext?.isNotEmpty ?? false) ||
        (widget.answer.imageStoragePath?.isNotEmpty ?? false);
    if (hasContent && !await cipher.hasRoundKey(round)) {
      await _recoverKey();
      return;
    }
    await _decrypt();
  }

  /// The requester side of the key ring: flag this device on the server and
  /// wait (with a friendly spinner) for any participant who still holds the
  /// round keys to re-wrap them to this device's CURRENT identity. On success
  /// the decrypt runs; on timeout the card surfaces the recoverable state.
  Future<void> _recoverKey() async {
    if (!mounted) return;
    setState(() => _recovery = _KeyRecovery.waiting);
    final cipher = ref.read(minigameCipherProvider(widget.sessionId));
    final round = widget.answer.round;
    final recovered = await cipher.requestRoundKeyShare(round);
    if (!mounted) return;
    if (recovered) {
      setState(() => _recovery = _KeyRecovery.none);
      await _decrypt();
    } else {
      setState(() => _recovery = _KeyRecovery.missing);
    }
  }

  Future<void> _decrypt() async {
    final cipher = ref.read(minigameCipherProvider(widget.sessionId));
    final round = widget.answer.round;
    final text = widget.answer.answerCiphertext;
    if (text != null && text.isNotEmpty) {
      final payload = await cipher.decryptAnswerPayload(text, round);
      if (payload != null && mounted) {
        widget.onDecrypted(payload);
        // Lift the payload so the screen can render the answer text as a
        // full-viewport, image-anchored overlay (2026-09-17).
        final notifier = ref.read(
          _answerPayloadProvider('${widget.sessionId}/$round').notifier,
        );
        notifier.state = payload;
      }
    }
    // The image is NOT inline: it lives in the private `minigame_images`
    // bucket (defect B). Resolve the object path via the storage download and
    // decrypt the RAW ciphertext bytes locally, then LIFT them to the screen
    // provider so the reaction window renders the picture as its full-viewport
    // background (2026-09-17 standardization) instead of a card thumbnail.
    final path = widget.answer.imageStoragePath;
    if (path != null && path.isNotEmpty) {
      _imageLoading = true;
      final bytes = await ref
          .read(minigameServiceProvider)
          .downloadMinigameImageBytes(path);
      final clear = bytes == null
          ? null
          : await cipher.decryptAnswerImageBytes(bytes, round);
      if (!mounted) return;
      final notifier = ref.read(
        _answerImageProvider('${widget.sessionId}/$round').notifier,
      );
      notifier.state = clear;
      setState(() => _imageLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_recovery == _KeyRecovery.waiting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: VSpinner(size: 18)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.minigamesKeyRequesting,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedStrong, fontSize: 12),
          ),
        ],
      );
    }
    if (_recovery == _KeyRecovery.missing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.minigamesKeyMissing,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: VButton.outlined(
              label: l10n.commonRetry,
              onPressed: _recoverKey,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Neither the picture NOR the text renders here: both live in the
        // screen-level overlays ([_answerImageProvider] / [_answerPayloadProvider]
        // → full-viewport, image-anchored). Only the download/decrypt spinner
        // remains in the card.
        if (_imageLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: VSpinner(size: 18)),
          ),
      ],
    );
  }
}

/// The _AnswerPreview key-recovery lifecycle (206_minigame_key_request).
enum _KeyRecovery {
  /// The round key is present — normal decrypt only.
  none,

  /// The key is missing and a holder re-share was requested — show a spinner.
  waiting,

  /// No holder was online to re-share within the window — show Reintentar.
  missing,
}

/// The async mode panel (202): the caller's per-player progress + the
/// "available to react" list of completed rounds (only those the caller can
/// react to appear — gated availability).
class _AsyncPanel extends ConsumerWidget {
  const _AsyncPanel({required this.sessionId, required this.state});

  final String sessionId;
  final MinigameGameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final skeleton = state.skeleton;
    final reactable = reactableAsyncRounds(skeleton, callerId: myId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: VCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.minigamesAsyncProgress(
                      skeleton.roundMap[myId] ?? 0,
                      skeleton.asyncRoundsPerPlayer,
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: VButton.dark(
                          label: l10n.minigamesTruth,
                          onPressed: () =>
                              _completeRound(context, ref, TruthDareKind.truth),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: VButton.outlined(
                          label: l10n.minigamesDare,
                          onPressed: () =>
                              _completeRound(context, ref, TruthDareKind.dare),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (reactable.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              l10n.minigamesAsyncAvailable,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Full-width tiles: the picture bleeds edge to edge.
          for (final answer in reactable)
            _AsyncReactableTile(sessionId: sessionId, answer: answer),
        ],
      ],
    );
  }

  Future<void> _completeRound(
    BuildContext context,
    WidgetRef ref,
    TruthDareKind kind,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final image = await _pickOptionalImage();
    if (!context.mounted) {
      controller.dispose();
      return;
    }
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.minigamesAnswerTitle),
        content: VInput(
          label: l10n.minigamesAnswerPlaceholder,
          controller: controller,
          maxLines: 3,
          minLines: 2,
          fontFamily: AppTypography.quicksand,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.minigamesAnswerSubmit),
          ),
        ],
      ),
    );
    if (submitted != true) return;
    final text = controller.text.trim();
    if (text.isEmpty && image == null) return;
    try {
      final cipher = ref.read(minigameCipherProvider(sessionId));
      final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
      final round = state.skeleton.roundMap[myId] ?? 0;
      final textCipher = await cipher.encryptAnswerText(text, round);
      String? imagePath;
      if (image != null) {
        // Downscale + JPEG-encode BEFORE the E2EE encrypt (PERF-03/M-36) — see
        // _AnswerCardState._submitAnswer for the rationale.
        final bytes = await ImageProcessor.compressBytes(
          Uint8List.fromList(await image.readAsBytes()),
        );
        final cipherBytes = await cipher.encryptAnswerImage(bytes, round);
        // Async images follow the SAME storage contract as by_turns (defect B
        // image half): upload the RAW ciphertext bytes to the private bucket
        // and pass the object path. The server assigns `max(a.round)+1` for
        // async rounds, so the client cannot know the exact number — the path
        // round is the caller's current progress + 1 (unique + resolvable; the
        // DB stores whatever path the server receives).
        imagePath = await ref
            .read(minigameServiceProvider)
            .uploadMinigameImage(sessionId, round + 1, cipherBytes);
      }
      await ref
          .read(minigameGameStateProvider(sessionId).notifier)
          .submitAsyncAnswer(
            kind: kind,
            answerCiphertext: textCipher,
            imageStoragePath: imagePath,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  Future<XFile?> _pickOptionalImage() async {
    final picker = ImagePicker();
    try {
      return await picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      return null;
    }
  }
}

/// The emoji glyph for a [ReactionKind] reaction tile (deck + bursts + the
/// reaction-rise particles).
///
/// The heart (`❤️`, U+2764 U+FE0F) is special-cased: the app's Inter font
/// ships a MONOCHROME U+2764 glyph, so Flutter paints the character with the
/// text color instead of falling back to the platform color-emoji font —
/// on every device the heart rendered WHITE. Tinting it with [AppColors.badgeRed]
/// makes the glyph red regardless of which font draws it (the other five
/// emoji are not covered by Inter, so they render as color emoji naturally).
/// A single request to float [kind] up the answer card INSTANTLY: emitted by
/// the by_turns reaction deck (rendered BELOW the card) and consumed by the
/// rise canvas (wrapping the card ABOVE). [token] increments on every accepted
/// tap so a consumer sees a NEW request even when the same emoji is tapped
/// twice in a row.
class _LocalRiseRequest {
  const _LocalRiseRequest({required this.token, required this.kind});

  final int token;
  final ReactionKind kind;
}

/// Per-session local-rise bus + per-device SIGNAL gate.
///
/// * [reserveTap] — the signal cooldown: true when a tap may be sent to the
///   server now (a tap inside [SamayDurations.reactionTapCooldown] of the
///   previous accepted send is not signalled yet; the deck holds the latest
///   tap and flushes it when the window opens). The timestamp lives in the
///   notifier so rapid taps across deck/async rebuilds share ONE per-session
///   clock.
/// * [emit] — fires an instant local rise request for the tapped emoji (the
///   deck writes it, the canvas reads it). Called on EVERY emoji tap, BEFORE
///   the signal gate, so the tapper's own device always animates — controlled
///   spam: many local rises, at most one server signal per window.
class _LocalRiseNotifier extends FamilyNotifier<_LocalRiseRequest?, String> {
  int _token = 0;
  DateTime? _lastTapAt;

  @override
  _LocalRiseRequest? build(String sessionId) => null;

  bool reserveTap() {
    final now = DateTime.now();
    final last = _lastTapAt;
    if (last != null &&
        now.difference(last) < SamayDurations.reactionTapCooldown) {
      return false;
    }
    _lastTapAt = now;
    return true;
  }

  void emit(ReactionKind kind) {
    state = _LocalRiseRequest(token: ++_token, kind: kind);
  }
}

/// The per-session local-rise bus (deck → answer-card canvas).
final _localRiseProvider =
    NotifierProvider.family<_LocalRiseNotifier, _LocalRiseRequest?, String>(
      _LocalRiseNotifier.new,
    );

/// Wraps the by_turns answer card as the reaction-rise stage: a reaction emoji
/// floats bottom → top ACROSS the card, fully hidden just below its bottom
/// edge to fully hidden just above its top edge, clipped to the card (202
/// answer-first — the round's live window that every participant watches on
/// their own device).
///
/// The rise plays through TWO independent channels:
///
/// * INSTANT (the tapper's own device): tapping an emoji on the reaction deck
///   (below the card) emits a local rise via [_localRiseProvider] on EVERY
///   tap; the canvas consumes it and floats the emoji up the tapper's OWN card
///   immediately, with no realtime round-trip. The per-device cooldown gates
///   only the SIGNAL to other devices (see `_ReactionRowState`), so a burst
///   animates fully here while the server sees at most one write per window.
/// * REALTIME (every device): the server records each accepted tap as a
///   reaction EVENT (`state.reactions_event` {seq, round, reaction, voter_id},
///   207) on the existing game-state UPDATE. When the event's seq is newer than
///   the last applied one AND its round matches the window shown, the tapped
///   emoji rises — INCLUDING a same-emoji re-tap whose tally mirror is
///   byte-identical (the exact case the seq exists to signal). The tapper's OWN
///   echo is deduped (its instant local rise already played); other voters'
///   events always rise. The event that CLOSES a round rides `reactions_event`
///   through the advance, so a device that never applied it (realtime
///   coalesced the reaction UPDATE with the advance) still replays the closing
///   rise when the next round appears.
///
/// Independent of the deck-slot tap burst (a different container + mechanism
/// — they merely coincide in time). Reduced motion never spawns a particle.
/// Async reactable tiles carry no per-round mirror, so they stay out of scope.
class _ReactionRiseCanvas extends ConsumerStatefulWidget {
  const _ReactionRiseCanvas({required this.sessionId, required this.child});

  final String sessionId;
  final Widget child;

  @override
  ConsumerState<_ReactionRiseCanvas> createState() =>
      _ReactionRiseCanvasState();
}

class _ReactionRiseCanvasState extends ConsumerState<_ReactionRiseCanvas> {
  /// The in-flight rising particles (ids grow monotonically so a particle is
  /// never recycled while still animating).
  final List<RiseSpec> _active = [];
  int _nextId = 0;

  /// The highest reaction-event seq this canvas has applied. Baselines from
  /// the row's seq on the FIRST sight of a round (null sentinel) and on every
  /// round change — a late joiner never replays events that landed before its
  /// device opened the window, and events never cross a round boundary.
  int? _lastSeq;

  /// The round the canvas is currently showing.
  int? _lastRound;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(minigameGameStateProvider(widget.sessionId));
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final skeleton = state.valueOrNull?.skeleton;
    final reduced = MediaQuery.disableAnimationsOf(context);

    // Instant local rises: consume deck taps (below the card) as they fire.
    // The cooldown already ran in the deck; every EMITTED request here is an
    // accepted tap that must float immediately.
    ref.listen<_LocalRiseRequest?>(_localRiseProvider(widget.sessionId), (
      prev,
      next,
    ) {
      if (next == null || identical(prev, next)) return;
      if (reduced || !mounted) return;
      setState(() => _spawn(next.kind));
    });

    final round = skeleton?.round;
    final seq = skeleton?.reactionsSeq ?? 0;
    final event = skeleton?.reactionEvent;

    if (round != _lastRound) {
      // A round flip. In-flight particles are NOT cleared — the reaction that
      // CLOSED the previous round is often delivered together with (or just
      // before) the advance, so dropping particles here would erase the
      // closing rise on every non-tapper device. Each particle self-removes
      // via its own onDone (bounded by stagger + reactionFloat).
      //
      // Recover the closing event when this device never applied it for the
      // previous window (realtime coalesced the reaction UPDATE + advance into
      // one row, or the advance arrived first). `reactions_event` survives the
      // advance (only the `reactions` mirror is cleared) and its own `round`
      // says which window it belongs to; `appliedBefore` guards a double rise
      // when the reaction UPDATE was already applied before the flip.
      final prevRound = _lastRound;
      final appliedBefore = _lastSeq;
      _lastRound = round;
      _lastSeq = seq;
      if (!reduced &&
          event != null &&
          event.hasEmoji &&
          event.voterId != myId &&
          event.round == prevRound &&
          seq > (appliedBefore ?? -1)) {
        _spawn(event.kind);
      }
    } else if (event != null && event.hasEmoji && seq > (_lastSeq ?? -1)) {
      // Same window: a fresh event — same-emoji re-taps and emoji changes each
      // animate. The voter's OWN echo is deduped (its instant local rise
      // already played); a stale event from a previous round is ignored via
      // its own round field.
      _lastSeq = seq;
      if (!reduced && event.round == round && event.voterId != myId) {
        _spawn(event.kind);
      }
    }

    return Stack(
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
                        for (final spec in _active)
                          RisingReactionParticle(
                            key: ValueKey(spec.id),
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

  void _spawn(ReactionKind kind) {
    _active.add(RiseSpec(id: _nextId++, kind: kind));
  }
}

/// One tappable reaction slot in a deck: the [kind] emoji, and on tap it both
/// fires [onReact] and plays the LOCAL burst — a duplicate of the emoji that
/// grows in place (its own slot) while its opacity ramps, then fades away.
///
/// Press feedback: while the finger is DOWN the resting emoji shrinks slightly
/// (1.0 → 0.9); on release it springs back to its original size at the same
/// moment the burst plays.
///
/// Emoji ↔ Pasar exclusivity (2026-09-04): when [disabled] the tile is greyed
/// out and inert — no press/burst/rise — because the caller already committed
/// to the OTHER mode (passed, so emoji tiles lock).
///
/// The burst is self-only feedback on the TAPPING device. In the by_turns
/// deck the tap ALSO triggers the answer-card rise (see [_ReactionRiseCanvas]
/// — instant locally, and on every device via the server's per-tap reaction
/// event); those are independent containers that merely coincide in time. The
/// burst honors the standard reduced-motion contract
/// (`MediaQuery.disableAnimationsOf`) — with the app-wide ANIM-OFF override
/// removed, animations run and only OS-level reduced motion suppresses this
/// one.
class _ReactionDeckButton extends StatefulWidget {
  const _ReactionDeckButton({
    required this.kind,
    required this.fontSize,
    required this.onReact,
    this.disabled = false,
  });

  final ReactionKind kind;
  final double fontSize;
  final VoidCallback onReact;

  /// Emoji ↔ Pasar exclusivity (2026-09-04): true when this tile's MODE is
  /// locked for the caller (they already passed, so emoji tiles grey out and
  /// do not respond).
  final bool disabled;

  @override
  State<_ReactionDeckButton> createState() => _ReactionDeckButtonState();
}

class _ReactionDeckButtonState extends State<_ReactionDeckButton>
    with TickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: SamayDurations.reactionBurst,
  );

  /// Press feedback: shrinks the resting emoji slightly (1.0 → 0.9) while the
  /// finger is down, springs it back on release. Duration = the fast token so
  /// the emoji reaches ~original size as the burst begins.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: SamayDurations.fast,
  );

  late final Animation<double> _pressScale = Tween<double>(begin: 1.0, end: 0.9)
      .animate(
        CurvedAnimation(parent: _press, curve: SamayDurations.defaultCurve),
      );

  /// Burst scale: 1.0 → ~1.9. Opacity ramps 0 → 1 over the first ~30% then
  /// fades out, so the duplicate "gets bigger while it becomes more opaque"
  /// and finally disappears (per the user's spec).
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 1.9,
  ).animate(CurvedAnimation(parent: _burst, curve: Curves.easeOutCubic));

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 70,
    ),
  ]).animate(_burst);

  @override
  void dispose() {
    _press.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _press.forward();
  }

  /// Release: the emoji returns to its original size (spring back) at the
  /// same time the tap fires the react + burst — "goes back AND the animation
  /// plays at the same time".
  void _handleTapUp(_) {
    if (_press.isForwardOrCompleted) _press.reverse();
  }

  void _handleTapCancel() {
    if (_press.isForwardOrCompleted) _press.reverse();
  }

  void _handleTap() {
    if (widget.disabled) return;
    widget.onReact();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _burst.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      onTapDown: widget.disabled ? null : _handleTapDown,
      onTapUp: widget.disabled ? null : _handleTapUp,
      onTapCancel: widget.disabled ? null : _handleTapCancel,
      borderRadius: BorderRadius.circular(4),
      child: Opacity(
        // Grey out the locked-away mode so the exclusivity reads at a glance
        // (the caller may still change emojis WITHIN their emoji mode).
        opacity: widget.disabled ? 0.35 : 1,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The resting emoji — scaled down while pressed, springing back
              // on release (underneath the burst duplicate).
              ScaleTransition(
                scale: _pressScale,
                child: ReactionEmoji(
                  kind: widget.kind,
                  fontSize: widget.fontSize,
                ),
              ),
              // The burst duplicate — stacked centered on the resting emoji,
              // so "the emoji in its place duplicates and maintains center".
              AnimatedBuilder(
                animation: _burst,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacity.value,
                    child: Transform.scale(scale: _scale.value, child: child),
                  );
                },
                child: ReactionEmoji(
                  kind: widget.kind,
                  fontSize: widget.fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared reaction deck: the emoji slots plus the final white-X pass slot
/// (2026-09-15 uniformity directive — used by BOTH the pinned by-turns row and
/// the async reactable tiles, so they can never drift).
class _ReactionDeckRow extends StatelessWidget {
  const _ReactionDeckRow({
    required this.onEmoji,
    required this.onPass,
    required this.passSemanticLabel,
    this.emojiDisabled = false,
    this.passDisabled = false,
  });

  final ValueChanged<ReactionKind> onEmoji;
  final VoidCallback onPass;
  final String passSemanticLabel;

  /// Emoji tiles grey out once the caller already passed.
  final bool emojiDisabled;

  /// The pass X greys out once the caller emoji-reacted OR already passed.
  final bool passDisabled;

  /// The shared reaction-emoji size.
  static const double _emojiFontSize = 32;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final kind in reactionEmojiKinds)
          _ReactionDeckButton(
            kind: kind,
            fontSize: _emojiFontSize,
            onReact: () => onEmoji(kind),
            disabled: emojiDisabled,
          ),
        _ReactionPassButton(
          semanticLabel: passSemanticLabel,
          onPressed: onPass,
          disabled: passDisabled,
        ),
      ],
    );
  }
}

/// The pass control that now lives as the LAST slot of the pinned reaction row
/// (2026-09-15): a white X with the same press feedback as the emoji tiles. It
/// commits the reactor-side Pasar (204) — the round's subject scores -0.5.
class _ReactionPassButton extends StatefulWidget {
  const _ReactionPassButton({
    required this.semanticLabel,
    required this.onPressed,
    this.disabled = false,
  });

  final String semanticLabel;
  final VoidCallback onPressed;

  /// Locked (greyed, inert) once the caller already emoji-reacted or passed.
  final bool disabled;

  @override
  State<_ReactionPassButton> createState() => _ReactionPassButtonState();
}

class _ReactionPassButtonState extends State<_ReactionPassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: SamayDurations.fast,
  );

  late final Animation<double> _pressScale = Tween<double>(begin: 1.0, end: 0.9)
      .animate(
        CurvedAnimation(parent: _press, curve: SamayDurations.defaultCurve),
      );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _press.forward();
  }

  void _handleRelease() {
    if (_press.isForwardOrCompleted) _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !widget.disabled,
      label: widget.semanticLabel,
      child: InkWell(
        onTap: widget.disabled ? null : widget.onPressed,
        onTapDown: widget.disabled ? null : _handleTapDown,
        onTapUp: widget.disabled ? null : (_) => _handleRelease(),
        onTapCancel: widget.disabled ? null : _handleRelease,
        borderRadius: BorderRadius.circular(4),
        child: Opacity(
          opacity: widget.disabled ? 0.35 : 1,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ScaleTransition(
              scale: _pressScale,
              child: const Icon(Icons.close, size: 34, color: AppColors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// One async reactable round row (202): the round + the subject's submitted
/// E2EE answer (decrypted locally) + a mini reaction picker.
class _AsyncReactableTile extends ConsumerStatefulWidget {
  const _AsyncReactableTile({required this.sessionId, required this.answer});

  final String sessionId;
  final MinigameAnswer answer;

  @override
  ConsumerState<_AsyncReactableTile> createState() =>
      _AsyncReactableTileState();
}

class _AsyncReactableTileState extends ConsumerState<_AsyncReactableTile> {
  String? _decrypted;
  Uint8List? _imageBytes;
  bool _imageLoading = false;

  @override
  void initState() {
    super.initState();
    _decrypt();
  }

  Future<void> _decrypt() async {
    final cipher = ref.read(minigameCipherProvider(widget.sessionId));
    final round = widget.answer.round;
    final text = widget.answer.answerCiphertext;
    if (text != null && text.isNotEmpty) {
      final decrypted = await cipher.decryptAnswerText(text, round);
      if (decrypted != null && mounted) {
        setState(() => _decrypted = decrypted);
      }
    }
    // Async image answers follow the SAME storage contract (defect B image
    // half): the object path resolves through the private bucket download,
    // then the RAW ciphertext bytes decrypt locally. A small spinner fills
    // the image slot meanwhile (2026-09-02).
    final path = widget.answer.imageStoragePath;
    if (path != null && path.isNotEmpty) {
      _imageLoading = true;
      final bytes = await ref
          .read(minigameServiceProvider)
          .downloadMinigameImageBytes(path);
      final clear = bytes == null
          ? null
          : await cipher.decryptAnswerImageBytes(bytes, round);
      if (!mounted) return;
      setState(() {
        _imageLoading = false;
        if (clear != null) _imageBytes = clear;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Full-bleed picture: the SAME [MinigameBleedImage] presentation as the
    // by_turns reaction window and the leaderboard pages (2026-09-17
    // standardization) — the picture bleeds to the tile's edges, with the round
    // header above and the reaction deck below. The card owns no padding so the
    // picture reaches the edges; each section pads itself.
    return VCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.md,
              AppSpacing.cardPadding,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.minigamesRoundCounter(
                    widget.answer.round,
                    widget.answer.round,
                  ),
                  style: const TextStyle(
                    color: AppColors.mutedStrong,
                    fontSize: 12,
                  ),
                ),
                if (_decrypted != null && _decrypted!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _decrypted!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: AppTypography.quicksand,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_imageBytes != null)
            GestureDetector(
              onTap: () => _showFullAnswerImage(context, _imageBytes!),
              child: SizedBox(
                height: 220,
                child: MinigameBleedImage(image: MemoryImage(_imageBytes!)),
              ),
            )
          else if (_imageLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(child: VSpinner(size: 18)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.sm,
              AppSpacing.cardPadding,
              AppSpacing.md,
            ),
            // The same deck as the by-turns row (2026-09-15 uniformity): emoji
            // slots plus the final white-X pass. Exclusivity is enforced
            // SERVER-side here (the async mirror is subject-keyed, so a
            // per-round grey-out would be ambiguous for multi-round subjects);
            // a cross-mode tap surfaces a rejection.
            child: _ReactionDeckRow(
              onEmoji: (kind) => _react(context, ref, kind),
              onPass: () => _react(context, ref, ReactionKind.pass),
              passSemanticLabel: l10n.minigamesPasar,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _react(
    BuildContext context,
    WidgetRef ref,
    ReactionKind kind,
  ) async {
    // Controlled spam: the async reactable tile shares the session's per-device
    // signal window with the by_turns deck. Rapid re-taps keep their local
    // deck-slot burst, but only one reaches the server per window.
    final local = ref.read(_localRiseProvider(widget.sessionId).notifier);
    if (!local.reserveTap()) return;
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .reactToRound(round: widget.answer.round, reaction: kind);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }
}

/// The realtime reaction voting row (201 + 202 answer-first): rendered ONLY
/// when the current round is reactable (the subject answered, caller is not
/// the subject). Every emoji tap floats the emoji up the caller's own card
/// immediately; the live tally streams back. Below the emoji deck sits the
/// reactor-side Pasar (204): passing gives the round's subject -0.5 on the
/// leaderboard.
class _ReactionRow extends ConsumerStatefulWidget {
  const _ReactionRow({required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<_ReactionRow> createState() => _ReactionRowState();
}

class _ReactionRowState extends ConsumerState<_ReactionRow> {
  /// The latest emoji tapped while the per-device signal window was closed.
  /// It is flushed when the window opens so a burst's closing tap (which may
  /// be the one that completes the round) is never lost.
  ReactionKind? _pending;
  Timer? _flushTimer;

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final skeleton = ref
        .watch(minigameGameStateProvider(widget.sessionId))
        .valueOrNull
        ?.skeleton;
    final subjectId = skeleton?.subjectId;
    // Emoji ↔ Pasar exclusivity (2026-09-09): once the caller has acted they
    // can only change WITHIN their chosen mode. If they already emoji-reacted,
    // Pasar is locked and greyed; if they already passed, EVERY option is
    // locked and greyed (emoji tiles AND Pasar).
    final myEmojiReacted = myId != null && subjectId != null && skeleton != null
        ? skeleton.hasVoterEmojiReacted(subjectId, myId)
        : false;
    final myPassed = myId != null && subjectId != null && skeleton != null
        ? skeleton.hasVoterPassed(subjectId, myId)
        : false;
    // Pinned to the floor exactly like the subject's Responder/Pasar bar
    // (2026-09-15 uniformity directive): no title, no card chrome — the emoji
    // deck plus a final white X (pass) span the row.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _ReactionDeckRow(
          onEmoji: _react,
          onPass: () => _react(ReactionKind.pass),
          passSemanticLabel: l10n.minigamesPasar,
          emojiDisabled: myPassed,
          passDisabled: myEmojiReacted || myPassed,
        ),
      ),
    );
  }

  /// Every EMOJI tap floats the emoji up the caller's own card IMMEDIATELY
  /// (controlled spam: the local device always animates). The per-device
  /// timer only throttles the SIGNAL to other devices: taps past the window
  /// send a fresh reaction event right away; taps inside it collapse into one
  /// trailing send of the latest emoji, flushed when the window opens.
  ///
  /// A Pasar is a mode commit (no emoji, no rise): it bypasses the timer and
  /// cancels any pending emoji flush so it can never race the mode switch.
  Future<void> _react(ReactionKind kind) async {
    final local = ref.read(_localRiseProvider(widget.sessionId).notifier);
    if (kind == ReactionKind.pass) {
      _flushTimer?.cancel();
      _pending = null;
      await _send(kind);
      return;
    }
    // INSTANT local feedback: the deck sits BELOW the card; the canvas above
    // it consumes this bus. Every accepted tap animates on this device.
    local.emit(kind);
    if (local.reserveTap()) {
      _flushTimer?.cancel();
      _pending = null;
      await _send(kind);
    } else {
      // Inside the window: remember the latest tap and flush it when the
      // window opens (a burst that ends the round still reaches the server).
      _pending = kind;
      _scheduleFlush();
    }
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(SamayDurations.reactionTapCooldown, () async {
      final pending = _pending;
      if (pending == null || !mounted) return;
      final local = ref.read(_localRiseProvider(widget.sessionId).notifier);
      if (!local.reserveTap()) {
        // Clock edge: retry on the next window rather than dropping the tap.
        _scheduleFlush();
        return;
      }
      _pending = null;
      await _send(pending);
    });
  }

  Future<void> _send(ReactionKind kind) async {
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .react(kind);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }
}
