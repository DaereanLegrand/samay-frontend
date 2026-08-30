import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Session detail (140_minigame_invites): replaces the GMCR "coming soon"
/// placeholder. Shows the game, status, wager and participant count, and —
/// when the current user has a PENDING invite (they need not be a group
/// member — `ms_read_invitee` opened the row) — an Aceptar/Rechazar pair.
///
/// Accept is only possible while the session is ACTIVE; once finished the
/// invite is closed (server `session_finished`). Live status rides the
/// existing `sessionStatusProvider` realtime sync.
class MinigameSessionDetailScreen extends ConsumerWidget {
  const MinigameSessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final session = ref.watch(sessionStatusProvider(sessionId));
    final invite = ref.watch(minigameInviteProvider(sessionId));

    return Scaffold(
      body: VHeaderBar(
        title: l10n.minigamesDetailTitle,
        child: session.when(
          loading: () => const VLoadingView(),
          error: (e, _) => ErrorView(
            message: l10n.minigamesErrorLoad,
            onRetry: () => ref.invalidate(sessionStatusProvider(sessionId)),
          ),
          data: (row) {
            final status = row['status'] as String?;
            final gameType = row['game_type'] as String?;
            final wager = (row['shard_wager'] as num?)?.toInt() ?? 0;
            final participants =
                (row['participants'] as List?)?.cast<String?>() ?? const [];
            final finished = status == 'finished';
            final inviteStatus = invite.valueOrNull?['status'] as String?;
            final isPending = inviteStatus == 'pending' && !finished;
            // The partida name (user title or the canonical server auto
            // partida-N — 170_minigame_invite_badges) so an invited friend
            // sees exactly the match they were invited to (e.g. "partida-1").
            final partidaName = minigameSessionName(l10n, row);

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                VDisplayText(text: minigameGameName(l10n, gameType), size: 28),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  partidaName,
                  style: const TextStyle(
                    color: AppColors.mutedStrong,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                VCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wager > 0
                            ? l10n.minigamesWagerPerPerson(wager)
                            : l10n.minigamesWagerFree,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.minigamesParticipants(participants.length),
                        style: const TextStyle(color: AppColors.mutedStrong),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      VChip(
                        label: finished
                            ? l10n.minigamesStatusFinished
                            : l10n.minigamesStatusActive,
                        selected: !finished,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (isPending)
                  VCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.minigamesInvitePendingBody,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: VButton.dark(
                                label: l10n.minigamesInviteAccept,
                                onPressed: () => _accept(context, ref, l10n),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: VButton.outlined(
                                label: l10n.minigamesInviteDecline,
                                onPressed: () => _decline(context, ref, l10n),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else if (inviteStatus == 'pending' && finished)
                  VCard(child: Text(l10n.minigamesInviteClosed))
                else if (inviteStatus == 'accepted')
                  VCard(child: Text(l10n.minigamesInviteAccepted)),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    try {
      await ref.read(minigameInviteProvider(sessionId).notifier).accept();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesInviteAccepted)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    try {
      await ref.read(minigameInviteProvider(sessionId).notifier).decline();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesInviteDeclined)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }
}
