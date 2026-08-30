import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Verdad o Reto play screen (150_minigame_play) — the first game built on
/// the reusable play engine.
///
/// Flow: the server randomly selects the subject (never self-selected), any
/// participant taps Verdad or Reto (the reveal RPC draws a random prompt),
/// the subject answers/does it and taps Hecho/Saltar (the advance RPC closes
/// the round and the server picks the next subject), and any participant can
/// end the game (draw settlement). The whole state rides
/// [minigameGameStateProvider], live via the `minigame_game_state` realtime
/// channel — every participant sees the same turn.
class TruthDareScreen extends ConsumerWidget {
  const TruthDareScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final game = ref.watch(minigameGameStateProvider(sessionId));
    final session = ref.watch(sessionStatusProvider(sessionId));
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];

    return Scaffold(
      body: VHeaderBar(
        title: l10n.minigamesPlayTitle,
        actions: [
          TextButton(
            onPressed: () => _confirmComplete(context, ref, l10n),
            child: Text(l10n.minigamesComplete),
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

            final subjectId = state.skeleton.subjectId;
            final isMyTurn = subjectId != null && subjectId == myId;
            final subjectName = _nameFor(subjectId, _participants(session));

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                VDisplayText(
                  text: isMyTurn
                      ? l10n.minigamesPromptHeader(
                          subjectName.isEmpty
                              ? l10n.minigamesPromptGeneric
                              : subjectName,
                        )
                      : truthDareChooseHeader(l10n, subjectName),
                  size: 28,
                ),
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
                        : Text(
                            truthDarePromptBody(state.skeleton.prompt) ??
                                l10n.minigamesChoosePromptFor(
                                  subjectName.isEmpty
                                      ? l10n.minigamesChoosePromptGeneric
                                      : subjectName,
                                ),
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The current subject's localized display: resolves the username from the
  /// session's participants (the session detail provider carries user rows),
  /// falling back to a short id slice when the row is missing.
  String _nameFor(String? subjectId, List<Map<String, dynamic>> participants) {
    if (subjectId == null) return '';
    for (final p in participants) {
      if (p['id'] == subjectId) {
        final name = p['username'] as String?;
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return subjectId.length <= 8 ? subjectId : subjectId.substring(0, 8);
  }

  List<Map<String, dynamic>> _participants(
    AsyncValue<Map<String, dynamic>> session,
  ) {
    final raw = session.valueOrNull?['participants'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesFinished)));
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
