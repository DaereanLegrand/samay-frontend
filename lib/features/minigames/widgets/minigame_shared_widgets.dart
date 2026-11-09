import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart' show defaultAnonAlias;
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Resolves the display name of a participant: temp nickname in anonymous mode
/// (falling back to localized default), otherwise the username.
String minigameResolveDisplayName(
  String? userId,
  List<MinigameParticipant> roster,
  Map<String, String>? aliases,
  GameTurnSkeleton skeleton,
  AppLocalizations l10n,
) {
  if (userId == null || userId.isEmpty) return '';
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

/// Subject header label (`<name>'s turn`) — single helper shared by every
/// game screen, so each play screen renders the turn header identically.
String minigameSubjectLabel(AppLocalizations l10n, String displayName) =>
    l10n.minigamesTurnFor(displayName);

/// Reusable finished-game leaderboard rendering settled prize split or scores.
class MinigameFinishedLeaderboard extends ConsumerWidget {
  const MinigameFinishedLeaderboard({super.key, required this.sessionId});

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
            VDisplayText(
              text: l10n.minigamesLeaderboardTitle,
              size: 28,
            ),
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
                        style: TextStyle(color: context.palette.mutedForeground),
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

/// Reusable temporary-nickname editor for anonymous mode.
class MinigameAliasEditor extends ConsumerStatefulWidget {
  const MinigameAliasEditor({
    super.key,
    required this.sessionId,
    required this.state,
  });

  final String sessionId;
  final MinigameGameState state;

  @override
  ConsumerState<MinigameAliasEditor> createState() => _MinigameAliasEditorState();
}

class _MinigameAliasEditorState extends ConsumerState<MinigameAliasEditor> {
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
    final aliases = ref.watch(minigameAliasesProvider(widget.sessionId)).valueOrNull;
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
              style: TextStyle(color: context.palette.mutedForeground),
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
