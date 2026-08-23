import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
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

/// LUXE v2 family for this screen — **peach** (the LUXE restyle pass (historical) map:
/// minigames → peach).
final AppGradient _family = AppGradients.familyOf('minigames');

/// Group minigames hub (GMCR foundation — I-63): the five game-type cards
/// (icon + name + tagline), the optional wager input (GWAG: 0 = no wager)
/// with the create action, and the group's session list with lifecycle
/// status chips. Tapping a session shows the detail placeholder — the
/// per-game UIs (turns, timers, votes) are future work.
///
/// LUXE v2: peach liquid-glass cards; the game-selection accent is the peach
/// family (never pink — 2026-08-12 directive).
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
          Expanded(
            child: Column(
                children: [
                  _buildGamePicker(l10n),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.hairline,
                  ),
                  Expanded(child: _buildSessions(l10n, sessions)),
                ],
              ),
          ),
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
          VDisplayText(
            text: l10n.minigamesPickGame,
            size: 28,
            gradient: _family,
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
                child: VButton.glowAccent(
                  label: l10n.minigamesCreate,
                  filled: true,
                  gradient: _family,
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
      loading: () => const VLoadingView(),
      error: (error, _) => ErrorView(
        message: l10n.minigamesErrorLoad,
        onRetry: () =>
            ref.read(minigameSessionsProvider(widget.groupId).notifier).refresh(),
      ),
      data: (rows) => rows.isEmpty
          ? VEmptyView(
              icon: Icons.sports_esports,
              title: l10n.minigamesEmpty,
              description: l10n.minigamesEmptyBody,
            )
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
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
                minigameIcon(type),
                (l) => l.minigamesGamePokeChain,
                (l) => l.minigamesGamePokeChainTagline,
              ),
            MinigameType.questions => (
                minigameIcon(type),
                (l) => l.minigamesGameQuestions,
                (l) => l.minigamesGameQuestionsTagline,
              ),
            MinigameType.truthDare => (
                minigameIcon(type),
                (l) => l.minigamesGameTruthDare,
                (l) => l.minigamesGameTruthDareTagline,
              ),
            MinigameType.drunkBottle => (
                minigameIcon(type),
                (l) => l.minigamesGameDrunkBottle,
                (l) => l.minigamesGameDrunkBottleTagline,
              ),
            MinigameType.challenge => (
                minigameIcon(type),
                (l) => l.minigamesGameChallenge,
                (l) => l.minigamesGameChallengeTagline,
              ),
          };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, name, tagline) = _meta;
    // LUXE: the selection accent is the peach family (vivid end), never pink.
    final accent = selected ? _family.colors.last : AppColors.white;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 170,
        child: VCard(
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
                  color: selected ? _family.colors.last : AppColors.white,
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
          vertical: AppSpacing.xs,
        ),
        child: VCard(
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
      ),
    );
  }
}
