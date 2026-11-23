import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/minigames/local/charades_decks.dart';
import 'package:samay/features/minigames/local/local_group_providers.dart';
import 'package:samay/features/minigames/local/local_group_store.dart';
import 'package:samay/features/minigames/local/local_player.dart';
import 'package:samay/features/minigames/local/local_roster.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// The pass-the-phone lobby every local game shares.
///
/// Three steps, in order, and nothing else:
///
/// 1. **How many are playing?** A number field; fewer than [LocalRoster.
///    minPlayers] never starts.
/// 2. **One name per seat.** The name field asks "escribe tu nombre o alias"
///    and the sheet says "pasa el teléfono a la persona de tu derecha" between
///    entries, until the roster is full.
/// 3. **Save the group?** So the same table can play again without typing.
///
/// Then the roster screen: symbol-only edit/delete per player, symbol-only add,
/// the game's own knobs (rounds or turn seconds + deck) and ONE big circular
/// play control in the bottom-right corner.
class LocalLobbyScreen extends ConsumerStatefulWidget {
  const LocalLobbyScreen({super.key, required this.gameType});

  final MinigameType gameType;

  @override
  ConsumerState<LocalLobbyScreen> createState() => _LocalLobbyScreenState();
}

enum _LobbyStep { count, collect, save, roster }

class _LocalLobbyScreenState extends ConsumerState<LocalLobbyScreen> {
  _LobbyStep _step = _LobbyStep.count;

  final _name = TextEditingController();
  final _groupName = TextEditingController();

  /// The names typed so far — the thing the roster is built from.
  final List<String> _pending = [];
  int _total = LocalRoster.minPlayers;

  @override
  void dispose() {
    _name.dispose();
    _groupName.dispose();
    super.dispose();
  }

  LocalRoster get _roster => ref.watch(localRosterProvider(widget.gameType));

  /// Largest party the stepper allows; above this the roster list stops being
  /// a roster and becomes a phone tree.
  static const int _maxPlayers = 20;

  /// The stepper's bounds: the game's own floor (never fewer than three) and
  /// [_maxPlayers].
  int get _minPlayers => LocalRoster.minPlayers;

  void _bumpCount(int delta) {
    setState(() {
      _total = (_total + delta).clamp(_minPlayers, _maxPlayers);
    });
  }

  void _startCollecting() {
    setState(() {
      _total = _total.clamp(_minPlayers, _maxPlayers);
      _pending.clear();
      _name.clear();
      _step = _LobbyStep.collect;
    });
  }

  /// Commits the current name field and moves on (or finishes collecting).
  void _commitName() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast(AppLocalizations.of(context).minigamesLobbyNameRequired);
      return;
    }
    setState(() {
      _pending.add(name);
      _name.clear();
      if (_pending.length >= _total) {
        _groupName.text = LocalGroup.suggestedName(_pending);
        _step = _LobbyStep.save;
      }
    });
  }

  void _finishCollecting() {
    ref
        .read(localRosterProvider(widget.gameType).notifier)
        .setPlayers([..._pending]);
    setState(() => _step = _LobbyStep.roster);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = minigameGameNameLower(l10n, widget.gameType.value);
    final setup = _step != _LobbyStep.roster;
    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        titleWidget: MinigameHeaderTitle(word: title),
        // The setup is a three-step flow: show where you are, the way every
        // modern onboarding does, so the number of questions is never a
        // surprise. The roster is the destination, so it carries no progress.
        bottom: setup
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: _StepProgress(
                  // count -> 0, collect -> 1, save -> 2
                  index: switch (_step) {
                    _LobbyStep.count => 0,
                    _LobbyStep.collect => 1,
                    _ => 2,
                  },
                  total: 3,
                ),
              )
            : null,
        child: switch (_step) {
          _LobbyStep.count => _countStep(context, l10n),
          _LobbyStep.collect => _collectStep(context, l10n),
          _LobbyStep.save => _saveStep(context, l10n),
          _LobbyStep.roster => _rosterStep(context, l10n),
        },
      ),
    );
  }

  // ── Step 1: how many ──────────────────────────────────────────────────────

  Widget _countStep(BuildContext context, AppLocalizations l10n) {
    return _LobbyStepLayout(
      title: l10n.minigamesLobbyPlayersQuestion,
      subtitle: l10n.minigamesLobbyPlayersHint,
      action: VButton.emphasized(
        label: l10n.commonContinue,
        onPressed: _startCollecting,
      ),
      child: _CountStepper(
        value: _total,
        min: _minPlayers,
        max: _maxPlayers,
        onStep: _bumpCount,
      ),
    );
  }

  // ── Step 2: one name per seat ────────────────────────────────────────────

  Widget _collectStep(BuildContext context, AppLocalizations l10n) {
    final next = _pending.length + 1;
    return _LobbyStepLayout(
      // Humans count from 1: the line names the seat being filled (1..total).
      overline: l10n.minigamesLobbyNamesProgress(next, _total),
      // The headline names WHOSE name this is; the question itself lives in the
      // field as its hint, where an input conventionally explains what it wants.
      title: l10n.minigamesLocalPlayerName(next),
      // Between seats the instruction is the point; on the first one nothing
      // has to be handed over yet.
      subtitle: next > 1 ? l10n.minigamesLobbyPassRight : null,
      action: VButton.emphasized(
        label: l10n.commonContinue,
        onPressed: _commitName,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BigNameField(
            controller: _name,
            hint: l10n.minigamesLobbyNamePrompt,
            onSubmitted: (_) => _commitName(),
            autofocus: true,
          ),
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in _pending) _PlayerPill(name: name),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 3: save the group? ─────────────────────────────────────────────

  Widget _saveStep(BuildContext context, AppLocalizations l10n) {
    return _LobbyStepLayout(
      title: l10n.minigamesLobbySaveGroupQuestion,
      subtitle: l10n.minigamesLobbySaveGroupHint,
      action: VButton.emphasized(
        label: l10n.commonSave,
        onPressed: () async {
          final group = LocalGroup.create(_groupName.text, _pending);
          await ref.read(savedLocalGroupsProvider.notifier).save(group);
          _finishCollecting();
        },
      ),
      secondaryAction: TextButton(
        onPressed: _finishCollecting,
        child: Text(
          l10n.commonSkip,
          style: TextStyle(color: context.palette.mutedForeground),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final name in _pending) _PlayerPill(name: name),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _BigNameField(
            controller: _groupName,
            onSubmitted: (_) {},
          ),
        ],
      ),
    );
  }

  // ── Step 4: the roster ─────────────────────────────────────────────────

  Widget _rosterStep(BuildContext context, AppLocalizations l10n) {
    final roster = _roster;
    final count = roster.players.length;
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              _PlayButton.size + AppSpacing.xxxl,
            ),
            children: [
              VDisplayText(text: l10n.minigamesLobbyPlayersTitle, maxLines: 2),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    l10n.minigamesLobbyPlayerCount(count),
                    style: AppTypography.bodyLarge.copyWith(
                      color: context.palette.mutedForeground,
                    ),
                  ),
                  Text(
                    ' · ',
                    style: AppTypography.bodyLarge.copyWith(
                      color: context.palette.mutedForeground,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${l10n.minigamesLobbyRosterHint} · ${l10n.minigamesLobbyReorderHint}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.palette.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _RosterList(
                players: roster.players,
                onEdit: _editPlayer,
                onDelete: (player) => ref
                    .read(localRosterProvider(widget.gameType).notifier)
                    .remove(player.id),
                onReorder: (from, to) => ref
                    .read(localRosterProvider(widget.gameType).notifier)
                    .reorder(from, to),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _AddPlayerButton(
                  label: l10n.minigamesLocalAddPlayer,
                  onPressed: _addPlayer,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _GameKnobs(gameType: widget.gameType),
              const SizedBox(height: AppSpacing.xxl),
              _SavedGroups(onUse: _useGroup),
            ],
          ),
        ),
        // The ONE play control: circular, bottom-right, independent of the list.
        Positioned(
          right: AppSpacing.screenHorizontal,
          bottom: AppSpacing.xl,
          child: _PlayButton(
            enabled: roster.isPlayable,
            label: l10n.minigamesLobbyPlay,
            onPressed: roster.isPlayable
                ? () => context.push(_playRoute(widget.gameType))
                : () => _toast(l10n.minigamesLobbyNeedPlayers),
          ),
        ),
      ],
    );
  }

  /// Where this game's local play screen lives: charadas and botella have
  /// their own turn shapes, the prompt games share one surface.
  static String _playRoute(MinigameType gameType) => switch (gameType) {
    MinigameType.charades => RoutePaths.localCharades(gameType.value),
    MinigameType.drunkBottle => RoutePaths.localBottle(gameType.value),
    _ => RoutePaths.localMatch(gameType.value),
  };

  Future<void> _editPlayer(LocalPlayer player) async {
    final l10n = AppLocalizations.of(context);
    final name = await _askName(
      title: l10n.minigamesLobbyEditTitle,
      initial: player.name,
    );
    if (name == null || name.isEmpty) return;
    ref
        .read(localRosterProvider(widget.gameType).notifier)
        .rename(player.id, name);
  }

  Future<void> _addPlayer() async {
    final l10n = AppLocalizations.of(context);
    final name = await _askName(title: l10n.minigamesLobbyAddTitle);
    if (name == null || name.isEmpty) return;
    ref.read(localRosterProvider(widget.gameType).notifier).add(name);
  }

  /// One themed prompt for both roster actions: a display title, the same big
  /// centred field the lobby steps use, and Guardar/Cancelar.
  ///
  /// The sheet owns its controller (`_PromptSheet`): disposing a controller from
  /// the caller right after `pop` tears it down while the route is still
  /// animating out, which crashes on the field's focus dependents.
  Future<String?> _askName({required String title, String initial = ''}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceAlt,
      builder: (_) => _PromptSheet(
        title: title,
        initial: initial,
        autofocus: false,
      ),
    );
  }

  void _useGroup(LocalGroup group) {
    ref
        .read(localRosterProvider(widget.gameType).notifier)
        .setPlayers(group.playerNames);
    setState(() {});
  }
}

/// One roster row: name, then symbol-only edit and delete.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.onEdit,
    required this.onDelete,
    this.handle,
  });

  final LocalPlayer player;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// The drag handle, when the row is reorderable.
  final Widget? handle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: context.palette.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // The whole row is the rename target: a list row that opens its own
        // editor is the pattern users already know, and it buys a large target
        // instead of a 36px pencil.
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: context.palette.foreground,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.palette.mutedForeground,
              ),
              const SizedBox(width: AppSpacing.xs),
              _CircleIconButton(
                icon: Icons.close,
                tooltip: l10n.commonDelete,
                onPressed: onDelete,
              ),
              if (handle != null) ...[
                const SizedBox(width: AppSpacing.xs),
                handle!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A round, quiet icon button (48px target) used by the roster rows.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: context.palette.mutedForeground),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: context.palette.background.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        minimumSize: const Size.square(36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// "agregar jugador" as a round, dashed-feel add control that reads as a slot
/// waiting to be filled instead of a stray toolbar icon.
class _AddPlayerButton extends StatelessWidget {
  const _AddPlayerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 18,
                  color: context.palette.mutedForeground,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.palette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The circular play control — same shape as the deck card's, but the lobby's
/// is the primary action, so it is filled with the foreground ink.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  static const double size = 72;

  @override
  Widget build(BuildContext context) {
    final ink = enabled
        ? context.palette.foreground
        : context.palette.mutedForeground;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: ink,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.play_arrow_rounded,
              size: 40,
              color: context.palette.background,
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-game setup knobs under the roster.
class _GameKnobs extends ConsumerWidget {
  const _GameKnobs({required this.gameType});

  final MinigameType gameType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final roster = ref.watch(localRosterProvider(gameType));
    final notifier = ref.read(localRosterProvider(gameType).notifier);

    if (gameType == MinigameType.charades) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(l10n.charadesDuration),
          const SizedBox(height: AppSpacing.sm),
          _PresetPicker(
            presets: const [30, 60, 90],
            value: roster.seconds,
            format: l10n.charadesSeconds,
            customLabel: l10n.minigamesLobbyCustom,
            onPreset: notifier.setSeconds,
            customTitle: l10n.minigamesLobbyCustomSeconds,
            min: 5,
            max: 600,
            suffix: 's',
            onCustom: notifier.setSeconds,
          ),
          const SizedBox(height: AppSpacing.xxl),
          _SectionLabel(l10n.charadesPickCategory),
          const SizedBox(height: AppSpacing.sm),
          // Decks are a longer, icon-led list: cards read better than chips.
          _DeckGrid(
            selectedId: roster.deckId,
            labelFor: (deck) => _deckLabel(l10n, deck),
            allLabel: l10n.charadesCategoryAll,
            onSelected: notifier.setDeck,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l10n.minigamesLobbyRoundsTitle),
        const SizedBox(height: AppSpacing.sm),
        _PresetPicker(
          presets: const [3, 5, 10, 15],
          value: roster.rounds,
          format: (n) => '$n',
          customLabel: l10n.minigamesLobbyCustom,
          onPreset: notifier.setRounds,
          customTitle: l10n.minigamesLobbyCustomRounds,
          min: 1,
          max: 99,
          onCustom: notifier.setRounds,
        ),
      ],
    );
  }

  static String _deckLabel(AppLocalizations l10n, CharadesDeck deck) {
    return switch (deck.labelKey) {
      'Animals' => l10n.charadesCategoryAnimals,
      'Pop' => l10n.charadesCategoryPop,
      'Literature' => l10n.charadesCategoryLiterature,
      'Art' => l10n.charadesCategoryArt,
      'Sports' => l10n.charadesCategorySports,
      'Drama' => l10n.charadesCategoryDrama,
      'Food' => l10n.charadesCategoryFood,
      _ => deck.id,
    };
  }
}

/// The quiet uppercase heading that introduces a section in the roster step.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.labelMedium.copyWith(
        color: context.palette.mutedForeground,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// Saved rosters, one tap to reapply.
class _SavedGroups extends ConsumerWidget {
  const _SavedGroups({required this.onUse});

  final ValueChanged<LocalGroup> onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final groups =
        ref.watch(savedLocalGroupsProvider).valueOrNull ?? const <LocalGroup>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l10n.minigamesLobbySavedGroups),
        const SizedBox(height: AppSpacing.sm),
        if (groups.isEmpty)
          Text(
            l10n.minigamesLobbyNoSavedGroups,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.mutedForeground,
            ),
          )
        else
          for (final group in groups)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: context.palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            color: context.palette.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          group.playerNames.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: context.palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.play_arrow_rounded,
                    tooltip: l10n.minigamesLobbyUseGroup,
                    onPressed: () => onUse(group),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _CircleIconButton(
                    icon: Icons.close,
                    tooltip: l10n.minigamesLobbyDeleteGroup,
                    onPressed: () => ref
                        .read(savedLocalGroupsProvider.notifier)
                        .delete(group.id),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// `−  4  +` — the only way to set the player count.
///
/// Two circular symbol buttons either side of the live number: the table picks
/// its own size instead of choosing from a preset list. The buttons disable at
/// the bounds, so the number can never go below the game's floor or above
/// [_LocalLobbyScreenState._maxPlayers].
class _CountStepper extends StatelessWidget {
  const _CountStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onStep,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onStep;

  /// Diameter of the round symbol buttons.
  static const double _buttonSize = 64;

  /// Cap the control's width so the number never floats off in the middle of a
  /// wide phone; it stays a compact, centred instrument.
  static const double _maxWidth = 320;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StepperButton(
              icon: Icons.remove,
              size: _buttonSize,
              enabled: value > min,
              semanticLabel: '−',
              onPressed: () => onStep(-1),
            ),
            Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.inter,
                fontSize: 88,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -2,
                color: context.palette.foreground,
              ),
            ),
            _StepperButton(
              icon: Icons.add,
              size: _buttonSize,
              enabled: value < max,
              semanticLabel: '+',
              onPressed: () => onStep(1),
            ),
          ],
        ),
      ),
    );
  }
}

/// One round, symbol-only stepper button (`−` / `+`).
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final double size;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = enabled
        ? context.palette.foreground
        : context.palette.mutedForeground;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: context.palette.surfaceAlt,
        shape: CircleBorder(
          side: BorderSide(
            color: enabled ? context.palette.border : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 30, color: ink),
          ),
        ),
      ),
    );
  }
}

/// The shared layout of the three lobby steps before the roster.
///
/// One visual idea, used everywhere in the app (onboarding, the deck, the game
/// page): big LEFT-aligned display copy, a quiet secondary line under it, one
/// large centred control, and the primary action pinned above the bottom
/// inset. It replaces the form-looking stack of labels + field + button.
class _LobbyStepLayout extends StatelessWidget {
  const _LobbyStepLayout({
    required this.title,
    required this.action,
    this.overline,
    this.subtitle,
    this.secondaryAction,
    this.child,
  });

  /// Small uppercase counter above the title ("1 de 3").
  final String? overline;

  /// The step's headline — rendered in the display voice.
  final String title;

  /// The quiet line under the headline (rule, hint, or instruction).
  final String? subtitle;

  /// The step's own control (stepper, field…), centred in the free space.
  final Widget? child;

  /// The primary action, full width, above the bottom inset.
  final Widget action;

  /// An optional quieter action under [action] ("omitir").
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final over = overline;
    final sub = subtitle;
    // The whole composition (headline + control) sits on the page's optical
    // centre, with the action pinned at the bottom — the app's display pages
    // are centred compositions, not top-aligned forms.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (over != null) ...[
                    Text(
                      over.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTypography.labelMedium.copyWith(
                        color: context.palette.mutedForeground,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  VDisplayText(
                    text: title,
                    maxLines: 3,
                    textAlign: TextAlign.center,
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      sub,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: context.palette.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (child != null) ...[
                    const SizedBox(height: AppSpacing.xxxl),
                    child!,
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            0,
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              action,
              if (secondaryAction != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(child: secondaryAction),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The big, centred, borderless name input used by the lobby steps.
///
/// It is the same "bare text on black" contract as [VInput] but at title size,
/// centred, with a fruit-machine style underline that brightens on focus — the
/// field is the hero of the step, not a form row.
class _BigNameField extends StatefulWidget {
  const _BigNameField({
    required this.controller,
    required this.onSubmitted,
    this.hint,
    this.autofocus = false,
    this.numeric = false,
    this.suffix = '',
  });

  final TextEditingController controller;

  /// Placeholder shown while the field is empty ("Escribe tu nombre o alias").
  final String? hint;

  final ValueChanged<String> onSubmitted;

  /// Whether to raise the keyboard as soon as the field mounts — the name
  /// steps are keyboard-first, so the user types instead of hunting the field.
  final bool autofocus;

  /// A number field (custom rounds / turn length): numeric keypad, digits only.
  final bool numeric;

  /// A small unit printed after the digits ("s" for seconds).
  final String suffix;

  @override
  State<_BigNameField> createState() => _BigNameFieldState();
}

class _BigNameFieldState extends State<_BigNameField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _field(context),
        const SizedBox(height: AppSpacing.sm),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          color: _focus.hasFocus
              ? context.palette.foreground
              : context.palette.hairline,
        ),
      ],
    );
  }

  Widget _field(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          keyboardType: widget.numeric
              ? TextInputType.number
              : TextInputType.text,
          inputFormatters: widget.numeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: widget.onSubmitted,
          cursorColor: context.palette.foreground,
          style: AppTypography.displaySmall.copyWith(
            color: context.palette.foreground,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTypography.bodyLarge.copyWith(
              color: context.palette.mutedForeground,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            suffixText: widget.suffix.isEmpty ? null : widget.suffix,
            suffixStyle: AppTypography.displaySmall.copyWith(
              color: context.palette.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

/// One already-collected player name, as a quiet pill.
class _PlayerPill extends StatelessWidget {
  const _PlayerPill({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: context.palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check,
            size: 14,
            color: context.palette.mutedForeground,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            name,
            style: AppTypography.bodyMedium.copyWith(
              color: context.palette.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// The three-dot step indicator shown while the lobby collects its setup.
///
/// Modern onboarding convention: the number of questions is visible up front,
/// the current step is filled, completed steps are solid, and the rest are
/// hairlines. It is deliberately quiet — geometry, no labels.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.index, required this.total});

  /// Zero-based current step.
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${index + 1}/$total',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= index
                        ? context.palette.foreground
                        : context.palette.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single-select segmented control: the iOS/Material-3 pattern for a short,
/// fixed set of mutually exclusive values. One pill slides between slots, so
/// the current choice is unambiguous without a checkmark per item.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
    this.allowNoSelection = false,
  });

  final T value;
  final List<({T value, String label})> options;
  final ValueChanged<T> onChanged;

  /// When true (a custom value is active) no segment is highlighted.
  final bool allowNoSelection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _Segment(
                label: option.label,
                selected: !allowNoSelection && option.value == value,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? context.palette.foreground : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLarge.copyWith(
              color: selected
                  ? context.palette.background
                  : context.palette.mutedForeground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// The charades decks as a two-column grid of tap cards: emoji, name, and a
/// filled state. A card per deck scans faster than eight chips and gives each
/// category enough room for its own emoji.
class _DeckGrid extends StatelessWidget {
  const _DeckGrid({
    required this.selectedId,
    required this.labelFor,
    required this.allLabel,
    required this.onSelected,
  });

  /// Selected deck id; null = every deck.
  final String? selectedId;
  final String Function(CharadesDeck deck) labelFor;
  final String allLabel;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = <({String? id, String emoji, String label})>[
      (id: null, emoji: '🎲', label: allLabel),
      for (final deck in kCharadesDecks)
        (id: deck.id, emoji: deck.emoji, label: labelFor(deck)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 340 ? 2 : 2;
        final gap = AppSpacing.sm;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: _DeckCard(
                  emoji: entry.emoji,
                  label: entry.label,
                  selected: entry.id == selectedId,
                  onTap: () => onSelected(entry.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? context.palette.foreground
            : context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: selected
                          ? context.palette.background
                          : context.palette.foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The roster as a reorderable list.
///
/// Wraps [ReorderableListView] in shrink-wrap mode inside the lobby's scroll
/// view: each row keeps its own tap-to-rename and X-to-remove, and gains a
/// three-line drag handle on the right (the modern convention — the handle is
/// the only place a drag starts, so scrubbing over the list never reorders it by
/// accident).
class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.players,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final List<LocalPlayer> players;
  final ValueChanged<LocalPlayer> onEdit;
  final ValueChanged<LocalPlayer> onDelete;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: players.length,
      // onReorderItem reports the final index (already adjusted for the
      // removal), unlike the deprecated onReorder.
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final player = players[index];
        return Padding(
          key: ValueKey(player.id),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _PlayerRow(
            player: player,
            onEdit: () => onEdit(player),
            onDelete: () => onDelete(player),
            handle: ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Icon(Icons.drag_handle, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A preset segmented control plus a **custom** slot.
///
/// The presets cover the common answers; "Personalizado" opens a numeric prompt
/// so a table that wants 7 rounds or 45 seconds is not forced into a bucket.
/// When the current value is not one of the presets the custom slot is the
/// selected segment and shows the live value.
class _PresetPicker extends StatelessWidget {
  const _PresetPicker({
    required this.presets,
    required this.value,
    required this.format,
    required this.customLabel,
    required this.onPreset,
    required this.customTitle,
    required this.min,
    required this.max,
    required this.onCustom,
    this.suffix = '',
  });

  final List<int> presets;
  final int value;
  final String Function(int value) format;
  final String customLabel;
  final ValueChanged<int> onPreset;
  final String customTitle;
  final int min;
  final int max;
  final ValueChanged<int> onCustom;
  final String suffix;

  bool get _isPreset => presets.contains(value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Presets only: the segmented control stays legible with 3–4 short
        // values. "Personalizado" lives on its own row below instead of being
        // squeezed in as a fifth segment (it ellipsized to "Person…").
        _Segmented<int>(
          value: value,
          options: [
            for (final preset in presets)
              (value: preset, label: format(preset)),
          ],
          // A custom value is not a segment; nothing is selected until the
          // table picks a preset again.
          onChanged: onPreset,
          allowNoSelection: !_isPreset,
        ),
        const SizedBox(height: AppSpacing.sm),
        _CustomValueRow(
          selected: !_isPreset,
          label: customLabel,
          value: _isPreset ? null : format(value),
          onTap: () => _promptCustom(context),
        ),
      ],
    );
  }

  Future<void> _promptCustom(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceAlt,
      builder: (_) => _PromptSheet(
        title: customTitle,
        initial: _isPreset ? '' : '$value',
        numeric: true,
        suffix: suffix,
        autofocus: true,
      ),
    );
    final parsed = int.tryParse((result ?? '').trim());
    if (parsed == null) return;
    onCustom(parsed.clamp(min, max));
  }
}

/// The shared bottom-sheet prompt used for renaming, adding a player and typing
/// a custom value.
///
/// Stateful on purpose: the sheet OWN its [TextEditingController] and disposes
/// it in `dispose()`. The previous version disposed the controller in the
/// caller immediately after `pop`, while the route was still animating out and
/// the field still had focus listeners attached — which crashed with
/// `'_dependents.isEmpty': is not true`.
class _PromptSheet extends StatefulWidget {
  const _PromptSheet({
    required this.title,
    this.initial = '',
    this.numeric = false,
    this.suffix = '',
    this.autofocus = false,
  });

  final String title;
  final String initial;
  final bool numeric;
  final String suffix;
  final bool autofocus;

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void initState() {
    super.initState();
    // Pre-fill selects the whole value, so typing REPLACES it. Without this a
    // numeric prompt opened on an existing value appended instead ("7" onto a
    // previous "0" saved 70).
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xl,
        AppSpacing.screenHorizontal,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VDisplayText(text: widget.title, maxLines: 2),
            const SizedBox(height: AppSpacing.xl),
            _BigNameField(
              controller: _controller,
              onSubmitted: (_) => _submit(),
              autofocus: widget.autofocus,
              numeric: widget.numeric,
              suffix: widget.suffix,
            ),
            const SizedBox(height: AppSpacing.xl),
            VButton.emphasized(
              label: AppLocalizations.of(context).commonSave,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context).commonCancel,
                style: TextStyle(color: context.palette.mutedForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Personalizado" affordance: one full-width row under the presets.
///
/// When a custom value is active the row is filled and shows it, so the choice
/// is visible without a fifth, ellipsized segment.
class _CustomValueRow extends StatelessWidget {
  const _CustomValueRow({
    required this.selected,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final bool selected;
  final String label;

  /// The formatted custom value, or null while a preset is active.
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shownValue = value;
    return Semantics(
      button: true,
      selected: selected,
      label: shownValue == null ? label : '$label $shownValue',
      child: Material(
        color: selected
            ? context.palette.foreground
            : context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.full),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tune,
                  size: 18,
                  color: selected
                      ? context.palette.background
                      : context.palette.mutedForeground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: selected
                          ? context.palette.background
                          : context.palette.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (shownValue != null)
                  Text(
                    shownValue,
                    style: AppTypography.bodyMedium.copyWith(
                      color: selected
                          ? context.palette.background
                          : context.palette.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
