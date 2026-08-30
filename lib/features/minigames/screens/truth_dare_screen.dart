import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Verdad o Reto play screen (150_minigame_play + 190_minigame_countdown) —
/// the first game built on the reusable play engine.
///
/// Flow: the server randomly selects the subject (never self-selected), any
/// participant taps Verdad or Reto (the reveal RPC draws a random prompt),
/// the subject answers/does it and taps Hecho/Saltar (the advance RPC closes
/// the round and the server picks the next subject), and the HOST can end the
/// game via the X (draw settlement). The whole state rides
/// [minigameGameStateProvider], live via the `minigame_game_state` realtime
/// channel — every participant sees the same turn.
///
/// 2026-08-30 directives:
///   * The play screen NEVER shows a raw UUID — the current subject and the
///     "next" player are resolved to usernames through the same roster the
///     lobby uses ([minigameParticipantsProvider]); a missing name falls back
///     to the generic line, never an id slice.
///   * The header reads "Turno de {username}" for EVERY participant — the
///     non-subject view shows the revealed prompt (or a waiting line) with NO
///     choice buttons; only the current subject can pick/reveal/advance.
///   * The AppBar title is the LOWERCASE minigame name, and ending the game is
///     the HOST-ONLY X icon (confirm dialog, wagers redistributed). The back
///     arrow stays non-destructive — it returns to the lobby, the game stays
///     active server-side.
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

    return Scaffold(
      body: VHeaderBar(
        // The AppBar title is the minigame name in LOWERCASE (2026-08-30
        // user directive), mirroring the lobby.
        title: session.valueOrNull == null
            ? l10n.minigamesPlayTitle.toLowerCase()
            : minigameGameNameLower(
                l10n,
                session.valueOrNull!['game_type'] as String?,
              ),
        // The X is the HOST-ONLY end-game action (draw settlement); everyone
        // else sees no close affordance here — the back arrow returns to the
        // lobby without ending the game.
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
              return Center(
                child: VDisplayText(text: l10n.minigamesFinished, size: 28),
              );
            }

            final skeleton = state.skeleton;
            final subjectId = skeleton.subjectId;
            final isMyTurn = subjectId != null && subjectId == myId;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                // "Turno de <username>" for everyone — the subject sees the
                // picker/reveal body, the rest a waiting view, both under the
                // same authoritative turn header.
                VDisplayText(
                  text: minigameSubjectLabel(
                    l10n,
                    _nameFor(subjectId, roster),
                  ),
                  size: 28,
                ),
                if (skeleton.nextSubjectId != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.minigamesNextTurn(
                      _nameFor(skeleton.nextSubjectId, roster),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                VCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: isMyTurn
                        ? _RevealPromptCard(
                            sessionId: sessionId,
                            state: state,
                            l10n: l10n,
                          )
                        : _WaitingCard(state: state, l10n: l10n),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The current/next subject's localized display: resolves the username from
  /// the same roster the lobby renders ([minigameParticipantsProvider]),
  /// falling back to an empty string — the caller then renders the generic
  /// line. A raw UUID is NEVER shown (2026-08-30 directive).
  String _nameFor(String? userId, List<MinigameParticipant> roster) {
    if (userId == null) return '';
    for (final participant in roster) {
      if (participant.id == userId) {
        final name = participant.username.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return '';
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
      await ref.read(minigameGameStateProvider(sessionId).notifier).complete();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }
}

/// The turn body for the current subject: reveals a prompt (Verdad / Reto)
/// when none is shown, else the prompt body + Hecho/Saltar actions.
class _RevealPromptCard extends ConsumerWidget {
  const _RevealPromptCard({
    required this.sessionId,
    required this.state,
    required this.l10n,
  });

  final String sessionId;
  final MinigameGameState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompt = truthDarePromptBody(state.skeleton.prompt);
    if (prompt == null) {
      return Row(
        children: [
          Expanded(
            child: VButton.dark(
              label: l10n.minigamesTruth,
              onPressed: () => _reveal(context, ref, TruthDareKind.truth),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: VButton.outlined(
              label: l10n.minigamesDare,
              onPressed: () => _reveal(context, ref, TruthDareKind.dare),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: VButton.dark(
                label: l10n.minigamesPromptDone,
                onPressed: () => _advance(context, ref, PromptOutcome.done),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: VButton.outlined(
                label: l10n.minigamesPromptSkip,
                onPressed: () => _advance(context, ref, PromptOutcome.skip),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _reveal(
    BuildContext context,
    WidgetRef ref,
    TruthDareKind kind,
  ) async {
    try {
      await ref.read(minigameGameStateProvider(sessionId).notifier).reveal(kind);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  Future<void> _advance(
    BuildContext context,
    WidgetRef ref,
    PromptOutcome outcome,
  ) async {
    try {
      await ref
          .read(minigameGameStateProvider(sessionId).notifier)
          .advance(outcome: outcome);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }
}

/// The non-subject's view of the current turn: the revealed prompt body (so
/// everyone reads it) or a waiting line — with NO choice buttons (2026-08-30
/// directive: only the current subject picks/advances).
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.state, required this.l10n});

  final MinigameGameState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final prompt = truthDarePromptBody(state.skeleton.prompt);
    final text = prompt ?? l10n.minigamesWaitingChoiceGeneric;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
      textAlign: TextAlign.center,
    );
  }
}
