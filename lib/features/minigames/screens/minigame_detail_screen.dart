import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/screens/minigame_invite_screen.dart';
import 'package:samay/features/minigames/screens/minigames_screen.dart'
    show MinigameScope, minigameRejectionMessage;
import 'package:samay/features/profile/providers/profile_providers.dart'
    as profile;
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

/// Dedicated per-game landing page (2026-08-28): the reusable shell every
/// minigame owns — game title + icon, explanation, audience ("con amigos /
/// solo"), the primary "Nueva partida" action and the list of this game's
/// ongoing partidas.
///
/// Game-agnostic by construction: everything game-specific (name, tagline,
/// explanation, audience) resolves through the [MinigameMeta] extension, so
/// a new game only needs a l10n pair + a switch arm.
///
/// Scope: arriving from the feed the page defaults to DIRECT play; the
/// wizard lets the player switch to a Group. Direct sessions come from
/// [myMinigameSessionsProvider]; group sessions from the scoped
/// [minigameSessionsProvider]. The list is filtered to [gameType] and shows
/// only ACTIVE (ongoing) partidas — finished ones drop off.
class MinigameDetailScreen extends ConsumerStatefulWidget {
  const MinigameDetailScreen({super.key, required this.gameType});

  final MinigameType gameType;

  @override
  ConsumerState<MinigameDetailScreen> createState() =>
      _MinigameDetailScreenState();
}

class _MinigameDetailScreenState extends ConsumerState<MinigameDetailScreen> {
  MinigameType get _type => widget.gameType;

  Future<void> _openNewPartida() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _NewPartidaScreen(gameType: _type),
      ),
    );
    if (created == true && mounted) {
      await ref.read(myMinigameSessionsProvider.notifier).refresh();
    }
  }

  void _showDetail(String sessionId) {
    context.push(RoutePaths.minigameSession(sessionId));
  }

  Future<void> _refresh() async {
    await ref.read(myMinigameSessionsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = _type;

    return Scaffold(
      body: VHeaderBar(
        title: minigameGameName(l10n, type.value),
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _listItemCount(l10n),
          itemBuilder: (context, index) => _buildListItem(context, l10n, type, index),
        ),
      ),
    );
  }

  /// The lazy list: index 0 is the fixed hero + CTA + heading block; the
  /// ongoing partidas (mine + pending invited) follow one per item
  /// (PERF-01: data-derived rows must be lazily built). Loading/error/empty
  /// collapse the list to the hero block alone.
  int _listItemCount(AppLocalizations l10n) {
    final sessions = ref.watch(myMinigameSessionsProvider);
    final data = sessions.valueOrNull;
    if (data == null) return 1; // loading / error → hero block only
    final ongoing = data
        .where((row) => row['status'] != 'finished')
        .where((row) => row['game_type'] == _type.value)
        .length;
    final pendingInvites = _pendingInvitesOfThisGame;
    // +1 header block; ongoing + pending rows render as their own items (when
    // empty the header block embeds the empty view).
    return 1 + ongoing + pendingInvites.length;
  }

  /// Pending invited sessions of THIS game (170_minigame_invite_badges): the
  /// invitee-side rows the user was invited to but has not accepted yet. They
  /// render under the same list so an invited friend SEES "partida-1" ready
  /// to accept — no need to already be a participant.
  List<Map<String, dynamic>> get _pendingInvitesOfThisGame {
    final pending = ref.watch(myPendingInvitesProvider).valueOrNull ?? const [];
    return pending
        .where((row) => row['game_type'] == _type.value)
        .toList();
  }

  Widget _buildListItem(
    BuildContext context,
    AppLocalizations l10n,
    MinigameType type,
    int index,
  ) {
    if (index == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(l10n, type),
          const SizedBox(height: AppSpacing.lg),
          // White button with black font (2026-08-28 user directive) — the
          // primary CTA voice on the per-game page.
          VButton.emphasized(
            label: l10n.minigamesNewPartida,
            onPressed: _openNewPartida,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.minigamesOngoingTitle.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSessions(l10n),
        ],
      );
    }
    final sessions = ref.watch(myMinigameSessionsProvider).valueOrNull;
    final ongoing = sessions
            ?.where((row) => row['status'] != 'finished')
            .where((row) => row['game_type'] == _type.value)
            .toList() ??
        const <Map<String, dynamic>>[];
    final pendingInvites = _pendingInvitesOfThisGame;
    final combined = [...ongoing, ...pendingInvites];
    final rowIndex = index - 1;
    if (rowIndex >= combined.length) return const SizedBox.shrink();
    final session = combined[rowIndex];
    final isPending = rowIndex >= ongoing.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: _SessionRow(
        session: session,
        index: rowIndex,
        pendingInvite: isPending,
        onTap: () => _showDetail(session['id'] as String),
      ),
    );
  }

  /// Title + tagline + explanation + audience chip — the fixed hero block.
  /// No duplicated title: the AppBar already names the game (2026-08-28
  /// user directive — drop the redundant hero title + icon).
  Widget _buildHero(AppLocalizations l10n, MinigameType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          type.tagline(l10n),
          style: const TextStyle(
            color: AppColors.mutedStrong,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          type.explanation(l10n),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        _AudienceTag(label: type.audienceLabel(l10n)),
      ],
    );
  }

  /// The ongoing partidas of this game — the DIRECT list (group partidas
  /// stay in the group hub / group scope; the feed lands on Direct by
  /// default). Loading/error render inline; the empty view renders in the
  /// header block; the rows themselves are lazily built items of the outer
  /// [ListView.builder] (PERF-01).
  Widget _buildSessions(AppLocalizations l10n) {
    final sessions = ref.watch(myMinigameSessionsProvider);

    return sessions.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: VLoadingView(),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ErrorView(
          message: l10n.minigamesErrorLoad,
          onRetry: _refresh,
        ),
      ),
      data: (rows) {
        final ongoing = rows
            .where((row) => row['status'] != 'finished')
            .where((row) => row['game_type'] == _type.value)
            .toList();
        final pendingInvites = _pendingInvitesOfThisGame;
        if (ongoing.isEmpty && pendingInvites.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: VEmptyView(
              icon: minigameIcon(_type),
              title: l10n.minigamesDetailEmpty(
                minigameGameName(l10n, _type.value),
              ),
              description: l10n.minigamesDetailEmptyBody,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Small grey pill for the audience fact ("Para jugar con amigos"): grey
/// background, black text, compact — the design-token voice for a secondary
/// label (2026-08-28 user directive).
class _AudienceTag extends StatelessWidget {
  final String label;

  const _AudienceTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softGray,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.discoBlack,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One ongoing partida row: display name (user or auto partida-XX), the
/// wager or participant count, and the status chip. A row may be a PENDING
/// INVITE (170_minigame_invite_badges) — an invited friend's "partida-N
/// ready to accept" entry — which renders the invite chip instead of the
/// active chip and deep-links to the accept/decline detail.
class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> session;
  final int index;
  final bool pendingInvite;
  final VoidCallback onTap;

  const _SessionRow({
    required this.session,
    required this.index,
    this.pendingInvite = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = session['status'] as String?;
    final wager = (session['shard_wager'] as num?)?.toInt() ?? 0;
    final participants = (session['participants'] as List?)?.length ?? 0;
    final name = minigameSessionName(l10n, session, index: index);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: VCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
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
                label: pendingInvite
                    ? l10n.minigamesInvitePending
                    : status == 'finished'
                    ? l10n.minigamesStatusFinished
                    : l10n.minigamesStatusActive,
                selected: pendingInvite ? false : status != 'finished',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The create-partida wizard launched by "Nueva partida": name (blank →
/// auto partida-XX), Directa/Grupo type (group picker when Grupo), invite
/// players, wager (default 10). Pops `true` when a partida was created so
/// the detail page refreshes its list.
class _NewPartidaScreen extends ConsumerStatefulWidget {
  const _NewPartidaScreen({required this.gameType});

  final MinigameType gameType;

  @override
  ConsumerState<_NewPartidaScreen> createState() => _NewPartidaScreenState();
}

class _NewPartidaScreenState extends ConsumerState<_NewPartidaScreen> {
  final _nameController = TextEditingController();
  final _wagerController = TextEditingController(text: '10');
  MinigameScope _scope = MinigameScope.direct;
  String? _selectedGroupId;
  List<String> _inviteeIds = const [];
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _wagerController.dispose();
    super.dispose();
  }

  /// The auto name a NEW partida would get: `partida-N` where N is the count
  /// of this game's ongoing partidas + 1 (the running number matches the
  /// per-game list the detail page renders — 160_minigame_names).
  String _nextAutoName() {
    final l10n = AppLocalizations.of(context);
    final sessions =
        _scope == MinigameScope.group && _selectedGroupId != null
        ? ref.watch(minigameSessionsProvider(_selectedGroupId!)).valueOrNull
        : ref.watch(myMinigameSessionsProvider).valueOrNull;
    final ongoing = sessions
            ?.where((row) => row['status'] != 'finished')
            .where((row) => row['game_type'] == widget.gameType.value)
            .length ??
        0;
    return l10n.minigamesAutoName(ongoing + 1);
  }

  Future<void> _pickInvitees() async {
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const MinigameInviteScreen()),
    );
    if (picked != null && mounted) {
      setState(() => _inviteeIds = picked);
    }
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final type = widget.gameType;
    final name = _nameController.text.trim();
    final wager = int.tryParse(_wagerController.text.trim()) ?? 0;

    setState(() => _creating = true);
    try {
      if (_scope == MinigameScope.group) {
        final groupId = _selectedGroupId;
        if (groupId == null) return;
        await ref
            .read(minigameSessionsProvider(groupId).notifier)
            .create(type, wager, inviteeIds: _inviteeIds, name: name);
      } else {
        await ref
            .read(myMinigameSessionsProvider.notifier)
            .create(type, wager, inviteeIds: _inviteeIds, name: name);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesCreated)));
      Navigator.of(context).pop(true);
    } on MinigameSessionRejectedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(minigameRejectionMessage(l10n, e.rejection))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: VHeaderBar(
        title: l10n.minigamesNewPartida,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
	    Row(
              children: [
                VChip(
                  label: l10n.minigamesScopeDirect,
                  selected: _scope == MinigameScope.direct,
                  onSelected: () => setState(() => _scope = MinigameScope.direct),
                  compact: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                VChip(
                  label: l10n.minigamesScopeGroup,
                  selected: _scope == MinigameScope.group,
                  onSelected: () => setState(() => _scope = MinigameScope.group),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            VInput(
              label: l10n.minigamesPartidaNameLabel,
              hint: l10n.minigamesPartidaNameHint(_nextAutoName()),
              controller: _nameController,
            ),
            if (_scope == MinigameScope.group) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildGroupPicker(l10n),
            ],
            const SizedBox(height: AppSpacing.xs),
            _WagerRow(
              controller: _wagerController,
              balanceCaption: l10n.minigamesWagerBalanceCaption,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xl),
            VButton.dark(
              label: l10n.minigamesCreate,
              loading: _creating,
              onPressed: _creating ? null : _create,
            ),
            const SizedBox(height: AppSpacing.lg),
            _InviteesSummary(
              count: _inviteeIds.length,
              onPick: _pickInvitees,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupPicker(AppLocalizations l10n) {
    return ref.watch(myGroupsProvider).when(
      loading: () => const VLoadingView(),
      error: (e, _) => ErrorView(message: e.toAppError().message),
      data: (groups) {
        if (groups.isEmpty) {
          return Text(
            l10n.minigamesNoGroupsBody,
            style: const TextStyle(color: AppColors.mutedStrong),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.minigamesChooseGroup.toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final group in groups)
              _GroupPickTile(
                group: group,
                selected: group.id == _selectedGroupId,
                onTap: () =>
                    setState(() => _selectedGroupId = group.id),
              ),
          ],
        );
      },
    );
  }
}

/// Group radio-style tile in the wizard's group picker.
class _GroupPickTile extends StatelessWidget {
  final Group group;
  final bool selected;
  final VoidCallback onTap;

  const _GroupPickTile({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.white : AppColors.mutedStrong,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              group.name,
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.mutedStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined row that opens the player picker and reports the chosen count.
class _InviteesSummary extends StatelessWidget {
  final int count;
  final VoidCallback onPick;

  const _InviteesSummary({required this.count, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VButton.outlined(
      onPressed: onPick,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_add_outlined, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            count > 0
                ? l10n.minigamesInviteCount(count)
                : l10n.minigamesInviteTitle,
          ),
        ],
      ),
    );
  }
}

/// The wager row in the create-partida wizard: the amount input with the
/// player's available shard balance to the right (small caption + count) so
/// the amount is always compared against what they actually have.
///
/// The balance comes from [myProfileProvider] (`personal_shards`); while it
/// loads, the right column shows a placeholder. The row carries its own
/// horizontal padding so it never sits flush against the screen edges.
class _WagerRow extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String balanceCaption;

  const _WagerRow({
    required this.controller,
    required this.onChanged,
    required this.balanceCaption,
  });

  @override
  ConsumerState<_WagerRow> createState() => _WagerRowState();
}

class _WagerRowState extends ConsumerState<_WagerRow> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final balance =
        (ref.watch(profile.myProfileProvider).valueOrNull?['personal_shards']
                as num? ??
            0).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.minigamesWagerLabel,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: VInput(
              label: l10n.minigamesWagerLabel,
              hint: l10n.minigamesWagerDefaultHint,
              controller: widget.controller,
              keyboardType: TextInputType.number,
              onChanged: widget.onChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Balance block: "Disponibles" caption over the amount. Both lines
          // use a small font so the two stacked lines occupy the same height
          // as the single "Usando: XX" 17px line (user directive 2026-08-28).
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.balanceCaption,
                style: const TextStyle(
                  color: AppColors.mutedStrong,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const VShardIcon(size: AppIconSizes.xs),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.profileShardsCount(balance),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
