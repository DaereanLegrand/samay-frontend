import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

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

    return Scaffold(
      body: VHeaderBar(
        titleWidget: headerTitle,
        title: headerTitle == null ? gameNameLower : null,
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
              return _FinishedLeaderboard(sessionId: sessionId);
            }

            final skeleton = state.skeleton;
            final subjectId = skeleton.subjectId;
            final isMyTurn = subjectId != null && subjectId == myId;
            final roundTarget = skeleton.roundTarget;

            // The top meta captions, fully capitalized at a smaller size than
            // the body copy. In by_turns the round counter and the next-turn
            // line sit INSIDE the answer card flush to its top-left / top-right
            // corners (bleeding over the card's inner padding). Async shows its
            // deadline caption centered above the async panel.
            const captionStyle = TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedStrong,
            );
            final isByTurns = skeleton.playMode == MinigamePlayMode.byTurns;
            final showRoundCaption = isByTurns && roundTarget != null;
            final showNextCaption = isByTurns && skeleton.nextSubjectId != null;
            final showAsyncDeadline = !isByTurns && skeleton.asyncEndsAt != null;

            Widget buildAnswerCard() {
              final hasCaptions = showRoundCaption || showNextCaption;

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

              if (!hasCaptions) {
                return VCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: body,
                  ),
                );
              }

              // A card body with the caption row at its very top: the round
              // counter hugs the top-left corner and the next-turn line the
              // top-right, ignoring the card's usual inner padding. The card
              // container mirrors VCard (surface + horizontal hairlines).
              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border.symmetric(
                    horizontal: BorderSide(color: AppColors.hairline),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.none,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (showRoundCaption)
                            Flexible(
                              child: Text(
                                l10n
                                    .minigamesRoundCounter(
                                      skeleton.round + 1,
                                      roundTarget,
                                    )
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: captionStyle,
                              ),
                            ),
                          if (showNextCaption)
                            Flexible(
                              child: Text(
                                l10n
                                    .minigamesNextTurn(
                                      _displayNameFor(
                                        skeleton.nextSubjectId,
                                        roster,
                                        aliases,
                                        skeleton,
                                        l10n,
                                      ),
                                    )
                                    .toUpperCase(),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: captionStyle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.cardPadding,
                        AppSpacing.md,
                        AppSpacing.cardPadding,
                        AppSpacing.cardPadding,
                      ),
                      child: body,
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                if (showAsyncDeadline) ...[
                  Text(
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
                  const SizedBox(height: AppSpacing.xs),
                ],
                if (skeleton.playMode == MinigamePlayMode.async)
                  _AsyncPanel(sessionId: sessionId, state: state)
                else
                  // The by_turns answer card doubles as the reaction-rise
                  // stage (the current round's live window, watched by every
                  // participant): incoming reaction emojis float bottom → top
                  // across it, clipped to its edges.
                  _ReactionRiseCanvas(
                    sessionId: sessionId,
                    child: buildAnswerCard(),
                  ),
                // The reaction row renders ONLY when the current round is
                // reactable (202 answer-first): the subject answered, the
                // caller is not the subject, phase is playing. Never a
                // disabled stub.
                if (canReactToCurrentRound(skeleton, callerId: myId)) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ReactionRow(sessionId: sessionId),
                ],
                const SizedBox(height: AppSpacing.lg),
                // Anonymous mode: the temp-nickname editor (default
                // anónimoXXX on accept; realtime update).
                if (skeleton.anonymous) ...[
                  _AliasEditor(sessionId: sessionId, state: state),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The rich two-line [VHeaderBar] title for the play screen, per state:
  ///
  ///   * by_turns playing → "turno de {subject}" with the outlined name
  ///     (small muted prefix + the user's name) + the lowercase minigame name.
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
        if (state.isFinished) {
          return MinigameHeaderTitle(
            word: l10n.minigamesBarLeaderboard,
            secondary: gameNameLower,
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
              secondary: gameNameLower,
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
                secondary: gameNameLower,
              );
            }
            return MinigameHeaderTitle(
              word: l10n.minigamesBarResponding,
              secondary: gameNameLower,
            );
          }
          // Nothing owed, nothing to react to — the plain name fallback.
          return null;
        }
        // by_turns playing: the subject is server-guaranteed (never null once
        // playing). The name resolution is defensive — a subject that cannot
        // be resolved renders the generic turn line, never a raw UUID.
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
            secondary: gameNameLower,
          );
        }
        return MinigameHeaderTitle(
          prefix: l10n.minigamesTurnBarPrefix,
          name: subjectName,
          suffix: l10n.minigamesTurnBarSuffix,
          secondary: gameNameLower,
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
  showDialog<void>(
    context: context,
    barrierColor: AppColors.discoBlack,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.discoBlack,
      insetPadding: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    tooltip: AppLocalizations.of(dialogContext).commonClose,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
  final _picker = ImagePicker();
  XFile? _image;
  bool _submitting = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompt = truthDarePromptBody(widget.state.skeleton.prompt);
    if (prompt == null) {
      return Row(
        children: [
          Expanded(
            child: VButton.dark(
              label: widget.l10n.minigamesTruth,
              onPressed: () => _reveal(TruthDareKind.truth),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: VButton.outlined(
              label: widget.l10n.minigamesDare,
              onPressed: () => _reveal(TruthDareKind.dare),
            ),
          ),
        ],
      );
    }
    final kind = truthDareKindFromWire(widget.state.skeleton.promptType);
    final isDare = kind == TruthDareKind.dare;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontFamily: AppTypography.quicksand),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.l10n.minigamesAnswerTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        VInput(
          label: widget.l10n.minigamesAnswerPlaceholder,
          controller: _answerController,
          maxLines: 3,
          minLines: 2,
          fontFamily: AppTypography.quicksand,
        ),
        if (isDare) ...[
          const SizedBox(height: AppSpacing.md),
          if (_image == null)
            VButton.outlined(
              onPressed: _pickImage,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(widget.l10n.minigamesAnswerImageLabel),
                ],
              ),
            )
          else ...[
            // Preview the picked image (2026-09-01 fix): previously only the
            // filename rendered — the app-wide picked-image convention is the
            // actual image (create_group_screen / create_event_screen), so
            // show Image.file over the XFile path. No filename shown (image
            // metadata stays out of the UI); the remove (×) control overlays
            // the image's top-right corner.
            // Center → Stack hugs the photo: the rounded clip (below) now
            // lands on the photo's own corners, not on a letterboxed frame
            // (the remove (×) overlays the photo's top-right corner).
            Center(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      onTap: _previewPickedImage,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: Image.file(
                          File(_image!.path),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      onPressed: () => setState(() => _image = null),
                      tooltip: widget.l10n.minigamesAnswerRemoveImage,
                      icon: const Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          widget.l10n.minigamesAnswerPasarLine,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedStrong, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
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

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) setState(() => _image = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  Future<void> _previewPickedImage() async {
    try {
      final picked = _image;
      if (picked == null || !mounted) return;
      final bytes = Uint8List.fromList(await picked.readAsBytes());
      if (!mounted) return;
      _showFullAnswerImage(context, bytes);
    } catch (_) {
      // Best-effort: never let a preview failure break the editor.
    }
  }

  Future<void> _submitAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty && _image == null) return;
    setState(() => _submitting = true);
    try {
      final cipher = ref.read(minigameCipherProvider(widget.sessionId));
      final round = widget.state.skeleton.round;
      AppLogger.instance.debug(
        'minigame submitAnswer start session=${widget.sessionId} round=$round '
        'hasText=${text.isNotEmpty} hasImage=${_image != null} '
        'subject=${widget.state.skeleton.subjectId?.substring(0, 8)}…',
      );
      final textCipher = await cipher.encryptAnswerText(text, round);
      AppLogger.instance.debug(
        'minigame submitAnswer encrypted text session=${widget.sessionId} '
        'round=$round cipherLen=${textCipher.length}',
      );
      String? imagePath;
      if (_image != null) {
        // Downscale + JPEG-encode BEFORE the E2EE encrypt (PERF-03/M-36): the
        // smaller JPEG plaintext becomes a smaller ciphertext, cutting storage
        // and per-viewer download+decrypt+decode time. Raw picked bytes never
        // leave the device — only the compressed JPEG is encrypted.
        final bytes = await ImageProcessor.compressBytes(
          Uint8List.fromList(await _image!.readAsBytes()),
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

/// The non-subject's view of the current by_turns round (202 answer-first):
/// the revealed prompt, and the subject's submitted answer ciphertext
/// (decrypted locally) once it exists — with NO choice buttons. Before the
/// answer the waiting line shows.
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
  String? _decrypted;

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
        Text(
          prompt,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontFamily: AppTypography.quicksand),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
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
        else ...[
          _AnswerPreview(
            sessionId: widget.sessionId,
            answer: answer,
            subjectName: subjectName,
            onDecrypted: (text) => setState(() => _decrypted = text),
            decrypted: _decrypted,
          ),
          // The open reaction window's live tally — visible to every
          // non-subject too (the subject's own card shows the same line), so
          // all participants watch the same "esperando X/Y reacciones…" while
          // the round stays open.
          const SizedBox(height: AppSpacing.md),
          _ReactionsWaitingLine(
            skeleton: widget.state.skeleton,
            roster: widget.roster,
            l10n: widget.l10n,
          ),
        ],
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
/// the input surface must be replaced by a READ-ONLY card: the revealed
/// prompt + the subject's OWN answer (decrypted locally) + the "waiting X/Y
/// reactions…" line. NO input, NO Responder, NO Pasar. A passed round shows
/// the Pasar-skipped suffix instead of the reaction line (no reactions on a
/// pass).
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
  String? _decrypted;

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
        Text(
          prompt,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontFamily: AppTypography.quicksand),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
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
            onDecrypted: (text) => setState(() => _decrypted = text),
            decrypted: _decrypted,
          ),
        if (!answer.passed) ...[
          const SizedBox(height: AppSpacing.md),
          _ReactionsWaitingLine(
            skeleton: widget.state.skeleton,
            roster: widget.roster,
            l10n: widget.l10n,
          ),
        ],
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

/// Renders the subject's submitted E2EE answer (text + optional image),
/// decrypting locally via [minigameCipherProvider]. The server never held the
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
  final ValueChanged<String> onDecrypted;
  final String? decrypted;

  @override
  ConsumerState<_AnswerPreview> createState() => _AnswerPreviewState();
}

class _AnswerPreviewState extends ConsumerState<_AnswerPreview> {
  Uint8List? _imageBytes;
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
      final decrypted = await cipher.decryptAnswerText(text, round);
      if (decrypted != null && mounted) {
        widget.onDecrypted(decrypted);
      }
    }
    // The image is NOT inline: it lives in the private `minigame_images`
    // bucket (defect B). Resolve the object path via the storage download and
    // decrypt the RAW ciphertext bytes locally. A small spinner fills the
    // image slot while the download + decrypt run (2026-09-02) so a slow
    // round never reads as a blank card.
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
        if (widget.decrypted != null && widget.decrypted!.isNotEmpty) ...[
          Text(
            widget.decrypted!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: AppTypography.quicksand,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (_imageBytes != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                onTap: () => _showFullAnswerImage(context, _imageBytes!),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Image.memory(
                    _imageBytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          )
        else if (_imageLoading)
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
        VCard(
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
        if (reactable.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.minigamesAsyncAvailable,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
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
class _ReactionEmoji extends StatelessWidget {
  const _ReactionEmoji({required this.kind, required this.fontSize});

  final ReactionKind kind;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      reactionEmoji[kind]!,
      style: TextStyle(
        fontSize: fontSize,
        // Inter's monochrome heart glyph inherits this color; the color-emoji
        // faces of the non-heart reactions are unaffected by it.
        color: kind == ReactionKind.heart ? AppColors.badgeRed : null,
      ),
    );
  }
}

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
  final List<_RiseSpec> _active = [];
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
    ref.listen<_LocalRiseRequest?>(
      _localRiseProvider(widget.sessionId),
      (prev, next) {
        if (next == null || identical(prev, next)) return;
        if (reduced || !mounted) return;
        setState(() => _spawn(next.kind));
      },
    );

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
                          _RisingReactionParticle(
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
    _active.add(_RiseSpec(id: _nextId++, kind: kind));
  }
}

/// The geometry + identity of ONE rising particle (a single reaction event).
class _RiseSpec {
  const _RiseSpec({required this.id, required this.kind});

  final int id;
  final ReactionKind kind;
}

/// One rising reaction emoji (realtime echo): spawns slightly below the
/// card's bottom edge, floats straight up the full card height and exits
/// slightly above the top edge. The glyph's top-left is fully off-canvas at
/// both extremes so it is fully hidden exactly at start/end; a brief
/// fade-in/fade-out envelope blurs the enter/exit.
///
/// The emoji renders LARGE and, per user spec, sways while it rises: each
/// particle gets a RANDOM horizontal wobble (frequency + amplitude drawn once
/// per particle — e.g. ~2.5 ± 1 sinusoidal cycles over the rise with a
/// ~12 ± 6 px swing) and a random horizontal lane + a small random stagger so
/// a burst of reactions looks lively rather than a rigid column. One-shot,
/// [SamayDurations.reactionFloat]. Reduced motion never creates a particle
/// (the canvas gate skips spawns entirely).
class _RisingReactionParticle extends StatefulWidget {
  const _RisingReactionParticle({
    super.key,
    required this.spec,
    required this.width,
    required this.height,
    required this.onDone,
  });

  final _RiseSpec spec;
  final double width;
  final double height;
  final VoidCallback onDone;

  @override
  State<_RisingReactionParticle> createState() =>
      _RisingReactionParticleState();
}

class _RisingReactionParticleState extends State<_RisingReactionParticle>
    with SingleTickerProviderStateMixin {
  /// The large render size of a rising reaction emoji (user spec — the rise
  /// must be clearly bigger than the deck's ~24 px tiles).
  static const double _fontSize = 44;

  /// How far the glyph must clear the card edge to be FULLY hidden (fully
  /// on-canvas starts being visible the instant any pixel crosses the edge).
  static const double _edgeClear = 4;

  /// The horizontal fraction of the card width the glyph's lane sits at — the
  /// rise starts from a random lane so reactions don't stack in one column.
  late final double _dx;

  /// Sinusoidal sway frequency: how many full back-and-forth cycles the emoji
  /// completes over one rise (randomized per particle — "random frequency").
  late final double _wobbleCycles;

  /// Sinusoidal sway amplitude in logical px (randomized per particle —
  /// "random amplitude").
  late final double _wobbleAmplitude;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.reactionFloat,
  );

  /// Rise path: fully below the bottom edge → fully above the top edge.
  late final Animation<double> _top =
      Tween<double>(
        begin: widget.height + _edgeClear,
        end: -(_fontSize + _edgeClear),
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: SamayDurations.defaultCurve,
        ),
      );

  /// Fade in over the first ~18% of the travel (below → entering), hold, then
  /// fade out over the last ~18% (exiting → fully hidden above).
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 18,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 64),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 18,
    ),
  ]).animate(_controller);

  Timer? _stagger;

  @override
  void initState() {
    super.initState();
    _dx = 0.12 + Random().nextDouble() * 0.76;
    // Random wobble per particle: ~1.5–3.5 cycles over the rise and a
    // ~6–18 px horizontal swing. Both are chosen once so the sway is smooth.
    _wobbleCycles = 1.5 + Random().nextDouble() * 2.0;
    _wobbleAmplitude = 6 + Random().nextDouble() * 12;
    // Small random stagger so a burst of reactions arrives with life rather
    // than as one rigid column (the canvas is the reduced-motion gate — it
    // never spawns a particle when animations are disabled).
    _stagger = Timer(Duration(milliseconds: Random().nextInt(320)), () {
      if (!mounted) return;
      _controller.forward().whenCompleteOrCancel(widget.onDone);
    });
  }

  @override
  void dispose() {
    _stagger?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// The horizontal sway offset at rise progress [t] (0 → 1): a sinusoid of
  /// the particle's random frequency × amplitude.
  double _sway(double t) {
    return _wobbleAmplitude * sin(2 * pi * _wobbleCycles * t);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Horizontal: fraction of the card width (card can be wide) so the
      // glyph never hugs the very edges. Width animated freely — the canvas
      // treats the glyph's top-left as its origin and clips at the edges.
      left: widget.width * _dx,
      top: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_sway(_controller.value), _top.value),
            child: Opacity(opacity: _opacity.value, child: child),
          );
        },
        child: _ReactionEmoji(kind: widget.spec.kind, fontSize: _fontSize),
      ),
    );
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

  late final Animation<double> _pressScale = Tween<double>(
    begin: 1.0,
    end: 0.9,
  ).animate(CurvedAnimation(parent: _press, curve: SamayDurations.defaultCurve));

  /// Burst scale: 1.0 → ~1.9. Opacity ramps 0 → 1 over the first ~30% then
  /// fades out, so the duplicate "gets bigger while it becomes more opaque"
  /// and finally disappears (per the user's spec).
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 1.9,
  ).animate(CurvedAnimation(parent: _burst, curve: Curves.easeOutCubic));

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeIn)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeOut)),
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
                child: _ReactionEmoji(
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
                    child: Transform.scale(
                      scale: _scale.value,
                      child: child,
                    ),
                  );
                },
                child: _ReactionEmoji(
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
    return VCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
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
            const SizedBox(height: AppSpacing.xs),
            if (_decrypted != null && _decrypted!.isNotEmpty) ...[
              Text(
                _decrypted!,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontFamily: AppTypography.quicksand),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (_imageBytes != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GestureDetector(
                    onTap: () => _showFullAnswerImage(context, _imageBytes!),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              )
            else if (_imageLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Center(child: VSpinner(size: 18)),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final kind in reactionEmojiKinds)
                  _ReactionDeckButton(
                    kind: kind,
                    fontSize: 20,
                    onReact: () => _react(context, ref, kind),
                  ),
              ],
            ),
            // Reactor-side Pasar (204) on the async reactable round — same
            // contract as the by_turns deck: the round's subject takes -0.5.
            // Exclusivity is enforced SERVER-side here (the async mirror is
            // subject-keyed, so a per-round grey-out would be ambiguous for
            // multi-round subjects); a cross-mode tap surfaces a rejection.
            const SizedBox(height: AppSpacing.sm),
            VButton.outlined(
              label: l10n.minigamesPasar,
              onPressed: () => _react(context, ref, ReactionKind.pass),
            ),
          ],
        ),
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
    final myEmojiReacted =
        myId != null && subjectId != null && skeleton != null
        ? skeleton.hasVoterEmojiReacted(subjectId, myId)
        : false;
    final myPassed =
        myId != null && subjectId != null && skeleton != null
        ? skeleton.hasVoterPassed(subjectId, myId)
        : false;
    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.minigamesReactionsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final kind in reactionEmojiKinds)
                  _ReactionDeckButton(
                    kind: kind,
                    fontSize: 24,
                    onReact: () => _react(kind),
                    disabled: myPassed,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Reactor-side Pasar (204): the voter opts out of emoji-reacting;
            // the round's subject scores -0.5 on the leaderboard. Locked once
            // the caller has emoji-reacted OR already passed (exclusivity —
            // a passed voter has nothing left to choose).
            VButton.outlined(
              label: l10n.minigamesPasar,
              onPressed: (myEmojiReacted || myPassed)
                  ? null
                  : () => _react(ReactionKind.pass),
            ),
          ],
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

/// The anonymous-mode temp-nickname editor (202): shows the current alias
/// (default `anónimoXXX`) with an "update name" button; the update is
/// encrypted nowhere (it is a display name, not content) and streams realtime
/// via `minigame_aliases`.
class _AliasEditor extends ConsumerStatefulWidget {
  const _AliasEditor({required this.sessionId, required this.state});

  final String sessionId;
  final MinigameGameState state;

  @override
  ConsumerState<_AliasEditor> createState() => _AliasEditorState();
}

class _AliasEditorState extends ConsumerState<_AliasEditor> {
  final _aliasController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final aliases = ref
        .watch(minigameAliasesProvider(widget.sessionId))
        .valueOrNull;
    final current = myId == null ? null : aliases?[myId];

    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.minigamesAliasLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              current ?? defaultAnonAlias(l10n, seed: myId ?? ''),
              style: const TextStyle(color: AppColors.mutedStrong),
            ),
            const SizedBox(height: AppSpacing.sm),
            VInput(
              label: l10n.minigamesAliasLabel,
              hint: current ?? defaultAnonAlias(l10n, seed: myId ?? ''),
              controller: _aliasController,
              maxLines: 1,
            ),
            const SizedBox(height: AppSpacing.sm),
            VButton.outlined(
              label: l10n.minigamesAliasUpdate,
              loading: _saving,
              onPressed: _saving ? null : _saveAlias,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAlias() async {
    final l10n = AppLocalizations.of(context);
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(minigameAliasesProvider(widget.sessionId).notifier)
          .setAlias(widget.sessionId, alias);
      _aliasController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesAliasUpdated)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// The finished-game leaderboard (201): reads the settled `minigame_results`
/// row and renders the ranked prize split. In anonymous mode the usernames
/// are revealed HERE — the only place real names appear during the match.
class _FinishedLeaderboard extends ConsumerWidget {
  const _FinishedLeaderboard({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(minigameResultProvider(sessionId));

    return result.when(
      loading: () => const VLoadingView(),
      error: (e, _) => ErrorView(message: e.toAppError().message),
      data: (settled) {
        if (settled == null || settled.rows.isEmpty) {
          return Center(
            child: VDisplayText(text: l10n.minigamesFinished, size: 28),
          );
        }
        final roster =
            ref.watch(minigameParticipantsProvider(sessionId)).valueOrNull ??
            const <MinigameParticipant>[];
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          children: [
            VDisplayText(text: l10n.minigamesLeaderboardTitle, size: 28),
            const SizedBox(height: AppSpacing.md),
            for (final row in settled.rows)
              VCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${row.rank}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _usernameFor(row.participantId, roster, l10n),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        row.prize > 0
                            ? l10n.minigamesPrizeAmount(row.prize)
                            : '${row.score}',
                        style: const TextStyle(color: AppColors.mutedStrong),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _usernameFor(
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
