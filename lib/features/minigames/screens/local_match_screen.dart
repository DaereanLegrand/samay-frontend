import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:samay/core/services/storage_service.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/minigames/local/local_match.dart';
import 'package:samay/features/minigames/local/local_match_config.dart';
import 'package:samay/features/minigames/local/local_match_store.dart';
import 'package:samay/features/minigames/local/local_prompt_pack.dart';
import 'package:samay/features/minigames/local/local_roster.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/features/minigames/widgets/minigame_prompt_pill.dart';
import 'package:samay/features/minigames/widgets/minigame_rank_row.dart';
import 'package:samay/features/minigames/widgets/minigame_session_surface.dart';
import 'package:samay/features/packs/providers/packs_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Single-device ("pass the phone") play for the PROMPT games —
/// verdad o reto, 2 mentiras 1 verdad.
///
/// The roster, the round target and the rest of the setup come from the lobby
/// ([localRosterProvider]), so this screen never asks anything: opening it with
/// a playable roster deals round 1 immediately, exactly like the deck's play
/// button promises.
///
/// Charadas and botella have their own local screens (a forehead tilt game and
/// a spinning board cannot share this turn shape).
class LocalMatchScreen extends ConsumerStatefulWidget {
  const LocalMatchScreen({super.key, required this.gameType});

  final MinigameType gameType;

  @override
  ConsumerState<LocalMatchScreen> createState() => _LocalMatchScreenState();
}

class _LocalMatchScreenState extends ConsumerState<LocalMatchScreen> {
  LocalMatch? _match;
  LocalPromptPack? _pack;
  bool _loadingPack = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPack();
  }

  /// The playable bank for this game: the on-device cache when warm, one
  /// network fetch when cold. A failure leaves `_pack` null and the screen
  /// explains it rather than crashing.
  Future<void> _loadPack() async {
    try {
      final pack = await ref.read(
        localMatchPackProvider(widget.gameType).future,
      );
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _loadingPack = false;
      });
      _start();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pack = null;
        _loadingPack = false;
        _loadError = '$e';
      });
    }
  }

  /// Deals round 1 from the lobby's roster.
  void _start() {
    final l10n = AppLocalizations.of(context);
    final roster = ref.read(localRosterProvider(widget.gameType));
    final pack = _pack;
    if (pack == null || pack.prompts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesLocalNoPack)));
      return;
    }
    if (!roster.isPlayable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesLobbyNeedPlayers)));
      return;
    }
    // The lobby sets rounds PER PLAYER; one turn per seat per round, so the
    // match target is the product (a fair table plays the same number of turns
    // per person however many are seated).
    final config = LocalMatchConfig(
      gameType: widget.gameType,
      players: roster.players,
      rounds: roster.rounds * roster.players.length,
      packId: pack.id,
    );
    try {
      config.assertValid();
    } on ArgumentError {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesLocalNeedPlayers)));
      return;
    }
    setState(() => _match = LocalMatch.start(config, pack, random: Random()));
  }

  Future<void> _persist(LocalMatch match) async {
    final scores = match.scoreboard();
    final summary = LocalMatchSummary(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      gameType: widget.gameType,
      playerNames: [for (final s in scores) s.name],
      scores: {for (final s in scores) s.name: s.score},
      rounds: match.state.round,
      finishedAt: DateTime.now(),
    );
    try {
      await HiveLocalMatchStore(
        // Already opened by HiveService.init; resolves synchronously.
        openBox: () async =>
            Hive.box<String>(HiveService.minigameSummaryBoxName),
      ).save(summary);
    } catch (_) {
      // History is a convenience; a cache failure must never break the board.
    }
  }

  /// The seat the current round belongs to, by id.
  String? _subjectName(LocalMatch match) {
    final id = match.state.subjectPlayerId;
    if (id == null) return null;
    for (final p in match.config.players) {
      if (p.id == id) return p.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = minigameGameNameLower(l10n, widget.gameType.value);
    final match = _match;
    final subject = match == null ? null : _subjectName(match);
    // The modern two-line play header: whose turn it is over the game name.
    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        titleWidget: subject == null
            ? MinigameHeaderTitle(word: title)
            : MinigameHeaderTitle(
                prefix: l10n.minigamesTurnBarPrefix,
                name: subject,
                suffix: l10n.minigamesTurnBarSuffix,
                secondary: title,
              ),
        child: match == null
            ? _pending(context, l10n)
            : _board(context, l10n, match),
      ),
    );
  }

  Widget _pending(BuildContext context, AppLocalizations l10n) {
    if (_loadingPack) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _loadError == null
                  ? l10n.minigamesLocalNoPack
                  : l10n.minigamesLocalNoPack,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: context.palette.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            VButton.emphasized(
              label: l10n.minigamesLocalPlayAgain,
              onPressed: () {
                setState(() {
                  _loadingPack = true;
                  _loadError = null;
                });
                _loadPack();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _board(BuildContext context, AppLocalizations l10n, LocalMatch match) {
    final state = match.state;
    if (state.isFinished) {
      return _summary(context, l10n, match);
    }

    final prompt = state.prompt;
    final promptBody = prompt?.body;
    final roundCounter = l10n.minigamesLocalRoundOf(
      state.round + 1,
      state.roundTarget,
    );

    // The round reads like the multi-device play card: the prompt on the
    // sanctioned rounded card (play voice), VERTICALLY CENTERED in the region
    // between the header and the pinned answer/pass bar, with the round
    // counter tucked under that bar.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.cardPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (promptBody != null)
                    MinigamePromptCard(
                      body: promptBody,
                      promptType: prompt?.promptType,
                    )
                  else
                    Text(
                      l10n.minigamesLocalNoPrompt,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: MinigameInks.of(context).muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
          ),
          child: Text(
            l10n.minigamesAnswerPasarLine,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: MinigameInks.of(context).muted,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          // Bottom action bar: inset from the display's rounded corners and
          // lifted above the home-indicator strip by the SafeArea inset —
          // the same bar the multi-device round pins.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      // "Listo" is the primary resolution of a round: white
                      // fill, black label — the inverse of the dark/outlined
                      // pair it used to share, so it reads as THE action.
                      child: VButton.emphasized(
                        label: l10n.minigamesLocalDone,
                        onPressed: () =>
                            _advance(match, LocalRoundOutcome.done),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: VButton.outlined(
                        label: l10n.minigamesLocalSkip,
                        onPressed: () =>
                            _advance(match, LocalRoundOutcome.skip),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  roundCounter,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall.copyWith(
                    color: MinigameInks.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The settled board: the winner in the display voice over the rank rows,
  /// each in the finished-leaderboard card footer's voice.
  Widget _summary(
    BuildContext context,
    AppLocalizations l10n,
    LocalMatch match,
  ) {
    final scores = match.scoreboard();
    final winner = match.winner();
    final rounds = match.state.results.length;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text(
          l10n.minigamesFinished.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall.copyWith(
            color: MinigameInks.of(context).muted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        VDisplayText(
          text: winner == null ? l10n.minigamesLocalTie : winner.name,
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.minigamesLocalRoundsPlayed(rounds).toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: MinigameInks.of(context).muted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < scores.length; i++)
          MinigameRankRow(
            rank: i + 1,
            name: scores[i].name,
            meta: l10n.minigamesPointsAmount(scores[i].score),
            divider: i < scores.length - 1,
          ),
        const SizedBox(height: AppSpacing.xl),
        VButton.emphasized(
          label: l10n.minigamesLocalPlayAgain,
          onPressed: () {
            match.restart();
            setState(() {});
          },
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  void _advance(LocalMatch match, LocalRoundOutcome outcome) {
    setState(() {
      if (outcome == LocalRoundOutcome.done) {
        match.markDone();
      } else {
        match.markSkip();
      }
    });
    if (match.state.isFinished) {
      _persist(match);
    }
  }
}
