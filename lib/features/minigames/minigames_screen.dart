import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// Friendly message for a rejected session creation (GWAG/GMCR typed errors
/// — the UI never pattern-matches raw exception strings, I-62 pattern).
String minigameRejectionMessage(
  AppLocalizations l10n,
  MinigameSessionRejection rejection,
) {
  return switch (rejection) {
    MinigameSessionRejection.notMember => l10n.minigamesErrorNotMember,
    MinigameSessionRejection.insufficientShards =>
      l10n.minigamesErrorInsufficientShards,
    MinigameSessionRejection.invalidGameType =>
      l10n.minigamesErrorInvalidGameType,
    MinigameSessionRejection.notAuthenticated ||
    MinigameSessionRejection.invalidWager =>
      l10n.minigamesErrorCreate,
  };
}

/// Localized name of a `game_type` column value (the DB enum string maps to
/// the l10n label; unknown values fall back to the raw data string).
String minigameGameName(AppLocalizations l10n, String? gameType) {
  return switch (gameType) {
    'poke_chain' => l10n.minigamesGamePokeChain,
    'questions' => l10n.minigamesGameQuestions,
    'truth_dare' => l10n.minigamesGameTruthDare,
    'drunk_bottle' => l10n.minigamesGameDrunkBottle,
    'challenge' => l10n.minigamesGameChallenge,
    _ => gameType ?? l10n.minigamesTitle,
  };
}

/// Group minigames hub (GMCR foundation — I-63): the five game-type cards
/// (icon + name + tagline), the optional wager input (GWAG: 0 = no wager)
/// with the create action, and the group's session list with lifecycle
/// status chips. Tapping a session shows the detail placeholder — the
/// per-game UIs (turns, timers, votes) are future work.
///
/// Disco-minimalist per DISCO-DESIGN-SYSTEM §1/§5: black surface, hairline
/// borders, white core text; the signature glowPink is the game-selection
/// accent only.
class MinigamesScreen extends ConsumerStatefulWidget {
  const MinigamesScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<MinigamesScreen> createState() => _MinigamesScreenState();
}

class _MinigamesScreenState extends ConsumerState<MinigamesScreen> {
  MinigameType? _selected;
  final TextEditingController _wagerController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _wagerController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final type = _selected;
    if (type == null) return;
    final wager = int.tryParse(_wagerController.text.trim()) ?? 0;

    setState(() => _creating = true);
    try {
      await ref
          .read(minigameSessionsProvider(widget.groupId).notifier)
          .create(type, wager);
      if (!mounted) return;
      _wagerController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.minigamesCreated)),
      );
    } on MinigameSessionRejectedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(minigameRejectionMessage(l10n, e.rejection))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toAppError().message)),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showDetailPlaceholder() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.minigamesDetailComingSoon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(minigameSessionsProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.minigamesTitle)),
      body: Column(
        children: [
          _buildGamePicker(l10n),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          Expanded(child: _buildSessions(l10n, sessions)),
        ],
      ),
    );
  }

  Widget _buildGamePicker(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.minigamesPickGame,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: MinigameType.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) {
                final type = MinigameType.values[i];
                return _GameCard(
                  type: type,
                  selected: _selected == type,
                  onTap: () => setState(() => _selected = type),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VInput(
                  label: l10n.minigamesWagerLabel,
                  hint: l10n.minigamesWagerHint,
                  controller: _wagerController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: 150,
                child: VButton(
                  label: l10n.minigamesCreate,
                  loading: _creating,
                  onPressed: _selected == null ? null : _create,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessions(
    AppLocalizations l10n,
    AsyncValue<List<Map<String, dynamic>>> sessions,
  ) {
    return sessions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: l10n.minigamesErrorLoad,
        onRetry: () =>
            ref.read(minigameSessionsProvider(widget.groupId).notifier).refresh(),
      ),
      data: (rows) => rows.isEmpty
          ? _EmptyState(l10n: l10n)
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.hairline),
              itemBuilder: (_, i) => _SessionCard(
                session: rows[i],
                onTap: _showDetailPlaceholder,
              ),
            ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final MinigameType type;
  final bool selected;
  final VoidCallback onTap;

  const _GameCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  (IconData, String Function(AppLocalizations), String Function(AppLocalizations))
      get _meta => switch (type) {
            MinigameType.pokeChain => (
                Icons.bolt,
                (l) => l.minigamesGamePokeChain,
                (l) => l.minigamesGamePokeChainTagline,
              ),
            MinigameType.questions => (
                Icons.question_answer,
                (l) => l.minigamesGameQuestions,
                (l) => l.minigamesGameQuestionsTagline,
              ),
            MinigameType.truthDare => (
                Icons.psychology,
                (l) => l.minigamesGameTruthDare,
                (l) => l.minigamesGameTruthDareTagline,
              ),
            MinigameType.drunkBottle => (
                Icons.sports_bar,
                (l) => l.minigamesGameDrunkBottle,
                (l) => l.minigamesGameDrunkBottleTagline,
              ),
            MinigameType.challenge => (
                Icons.emoji_events,
                (l) => l.minigamesGameChallenge,
                (l) => l.minigamesGameChallengeTagline,
              ),
          };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, name, tagline) = _meta;
    final accent = selected ? AppColors.glowPink : AppColors.white;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: accent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppIconSizes.xl, color: accent),
            const SizedBox(height: AppSpacing.md),
            Text(
              name(l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.glowPink : AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: Text(
                tagline(l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.mutedStrong,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = session['status'] as String?;
    final wager = (session['shard_wager'] as num?)?.toInt() ?? 0;
    final participants =
        (session['participants'] as List?)?.length ?? 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    minigameGameName(l10n, session['game_type'] as String?),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    wager > 0
                        ? l10n.minigamesWagerPerPerson(wager)
                        : l10n.minigamesParticipants(participants),
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            VChip(
              label: status == 'finished'
                  ? l10n.minigamesStatusFinished
                  : l10n.minigamesStatusActive,
              selected: status != 'finished',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_esports,
              size: AppIconSizes.xxl,
              color: AppColors.border,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.minigamesEmpty,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.minigamesEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedStrong),
            ),
          ],
        ),
      ),
    );
  }
}
