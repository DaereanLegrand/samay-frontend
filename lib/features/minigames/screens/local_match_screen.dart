import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/minigames/local/local_match.dart';
import 'package:samay/features/minigames/local/local_match_config.dart';
import 'package:samay/features/minigames/local/local_match_store.dart';
import 'package:samay/features/minigames/local/local_player.dart';
import 'package:samay/features/minigames/local/local_prompt_pack.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/features/packs/providers/packs_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// Single-device ("pass the phone") play.
///
/// Two entry modes, one screen:
///
/// * **quick** (`?quick=1`, the game page's primary CTA): the match starts
///   IMMEDIATELY with two default seats. Nothing is typed before play; the
///   table renames itself from the play screen's header action.
/// * **setup** (the secondary CTA): a roster + round target are collected
///   first, for a group that wants to be named up front.
///
/// In both modes the match is fully local from the cached prompt pack: no
/// account, no network, no per-player device.
class LocalMatchScreen extends ConsumerStatefulWidget {
  const LocalMatchScreen({super.key, required this.gameType, this.quick = false});

  final MinigameType gameType;

  /// Skip the setup step and deal the first round with default seats.
  final bool quick;

  @override
  ConsumerState<LocalMatchScreen> createState() => _LocalMatchScreenState();
}

class _LocalMatchScreenState extends ConsumerState<LocalMatchScreen> {
  final List<TextEditingController> _names = [];
  int _rounds = 5;
  LocalMatch? _match;
  LocalPromptPack? _pack;
  bool _loadingPack = true;
  bool _quickStarted = false;

  @override
  void initState() {
    super.initState();
    _addPlayer();
    _addPlayer();
    _loadPack();
  }

  /// The playable bank for this game: the on-device cache when warm, one
  /// network fetch when cold. A failure leaves `_pack` null and the setup's
  /// start button explains it rather than crashing.
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
      // Quick mode: deal as soon as the bank is ready.
      if (widget.quick) _start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pack = null;
        _loadingPack = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPlayer() => setState(() => _names.add(TextEditingController()));

  void _removePlayer(int index) {
    setState(() {
      _names.removeAt(index).dispose();
    });
  }

  List<LocalPlayer> _players() {
    final l10n = AppLocalizations.of(context);
    return [
      for (var i = 0; i < _names.length; i++)
        LocalPlayer.create(l10n.minigamesLocalPlayerName(i + 1)),
    ];
  }

  Future<void> _start() async {
    if (_quickStarted && _match != null) return;
    final l10n = AppLocalizations.of(context);
    final players = _players();
    final config = LocalMatchConfig(
      gameType: widget.gameType,
      players: players,
      rounds: _rounds,
      packId: _pack?.id ?? '',
    );
    try {
      config.assertValid();
    } on ArgumentError {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.minigamesLocalNeedPlayers)),
      );
      return;
    }
    final pack = _pack;
    if (pack == null || pack.prompts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.minigamesLocalNoPack)),
      );
      return;
    }
    setState(() {
      _match = LocalMatch.start(config, pack, random: Random());
      _quickStarted = true;
    });
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
        openBox: () => Hive.openBox<String>('minigame_summary_cache'),
      ).save(summary);
    } catch (_) {
      // History is a convenience; a cache failure must never break the board.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = minigameGameNameLower(l10n, widget.gameType.value);
    final match = _match;
    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        titleWidget: MinigameHeaderTitle(word: title),
        actions: match == null
            ? null
            : [
                // Renaming happens HERE, mid-match — that is what removes the
                // typing step from the first run.
                IconButton(
                  icon: const Icon(Icons.group_outlined),
                  tooltip: l10n.minigamesEditPlayers,
                  onPressed: () => _editPlayers(match),
                ),
              ],
        child: match == null
            ? _loadingPack && widget.quick
                  ? const Center(child: CircularProgressIndicator())
                  : _setup(context, l10n)
            : _board(context, l10n, match),
      ),
    );
  }

  /// Sheet to correct the seat names while the match runs.
  Future<void> _editPlayers(LocalMatch match) async {
    final l10n = AppLocalizations.of(context);
    final controllers = {
      for (final p in match.config.players) p.id: TextEditingController(text: p.name),
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom:
              MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.minigamesEditPlayers.toUpperCase(),
              style: Theme.of(sheetContext).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final entry in controllers.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: VInput(
                  label: l10n.minigamesLocalPlayerName(
                    match.config.players.indexWhere((p) => p.id == entry.key) + 1,
                  ),
                  controller: entry.value,
                ),
              ),
            VButton.emphasized(
              label: l10n.commonSave,
              onPressed: () {
                setState(() {
                  for (final entry in controllers.entries) {
                    final name = entry.value.text.trim();
                    if (name.isEmpty) continue;
                    match.renamePlayer(entry.key, name);
                  }
                });
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _setup(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.minigamesLocalIntro,
          style: AppTypography.bodyLarge.copyWith(
            color: context.palette.mutedForeground,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (var i = 0; i < _names.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: VInput(
                    label: l10n.minigamesLocalPlayerName(i + 1),
                    controller: _names[i],
                  ),
                ),
                if (_names.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removePlayer(i),
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addPlayer,
            icon: const Icon(Icons.add),
            label: Text(l10n.minigamesLocalAddPlayer),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.minigamesRoundsLabel.toUpperCase(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            DropdownButton<int>(
              value: _rounds,
              onChanged: (v) => setState(() => _rounds = v ?? _rounds),
              items: [
                for (final n in [3, 5, 10, 15])
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        VButton.emphasized(
          label: l10n.minigamesLocalStart,
          loading: _loadingPack,
          onPressed: _loadingPack ? null : _start,
        ),
      ],
    );
  }

  Widget _board(BuildContext context, AppLocalizations l10n, LocalMatch match) {
    final state = match.state;
    if (state.isFinished) {
      final scores = match.scoreboard();
      final winner = match.winner();
      return ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        children: [
          const SizedBox(height: AppSpacing.lg),
          VDisplayText(
            text: winner == null ? l10n.minigamesLocalTie : winner.name,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final s in scores)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: VCard(
                child: Row(
                  children: [
                    Expanded(child: Text(s.name)),
                    Text('${s.score}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          VButton.emphasized(
            label: l10n.minigamesLocalPlayAgain,
            onPressed: () => setState(() => _match = null),
          ),
        ],
      );
    }

    final judge = state.judgePlayerId == null
        ? ''
        : match.config.players
              .firstWhere((p) => p.id == state.judgePlayerId)
              .name;
    final subject = state.subjectPlayerId == null
        ? ''
        : match.config.players
              .firstWhere((p) => p.id == state.subjectPlayerId)
              .name;
    final prompt = state.prompt?.body;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          '${state.round + 1} / ${state.roundTarget}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.minigamesLocalJudge(judge),
          style: AppTypography.bodyMedium.copyWith(
            color: context.palette.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        VCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Text(
                  prompt ?? l10n.minigamesLocalNoPrompt,
                  style: AppTypography.bodyLarge.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        VButton.emphasized(
          label: l10n.minigamesLocalDone,
          onPressed: () => _advance(match, LocalRoundOutcome.done),
        ),
        const SizedBox(height: AppSpacing.md),
        VButton.outlined(
          label: l10n.minigamesLocalSkip,
          onPressed: () => _advance(match, LocalRoundOutcome.skip),
        ),
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
