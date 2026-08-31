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
import 'package:samay/features/minigames/logic/minigame_engine.dart';
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
import 'package:samay/shared/widgets/v_spinner.dart';

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

  /// Session ids with an accept/decline in flight — the inline buttons turn
  /// into spinners and ignore taps until the RPC settles (double-tap guard).
  final Set<String> _busySessionIds = <String>{};

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

  /// Inline ACCEPT (2026-08-30): accepts the pending invite straight from the
  /// per-game list — no need to open the session detail first. On success the
  /// user is taken to the partida LOBBY (the session detail becomes the
  /// pre-play room once they are a participant). Rejections surface the typed
  /// [MinigameSessionRejectedException] through [minigameRejectionMessage] so
  /// "insufficient shards" reads as a friendly explanation, never a raw error.
  Future<void> _acceptInvite(String sessionId) async {
    final l10n = AppLocalizations.of(context);
    if (_busySessionIds.contains(sessionId)) return;
    setState(() => _busySessionIds.add(sessionId));
    try {
      await ref.read(minigameInviteProvider(sessionId).notifier).accept();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesInviteAccepted)));
      context.push(RoutePaths.minigameSession(sessionId));
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
      if (mounted) setState(() => _busySessionIds.remove(sessionId));
    }
  }

  /// Inline DECLINE (2026-08-30): declines the pending invite straight from
  /// the per-game list. The accept/decline action invalidates
  /// [myPendingInvitesProvider], so the row drops off the list on success.
  Future<void> _declineInvite(String sessionId) async {
    final l10n = AppLocalizations.of(context);
    if (_busySessionIds.contains(sessionId)) return;
    setState(() => _busySessionIds.add(sessionId));
    try {
      await ref.read(minigameInviteProvider(sessionId).notifier).decline();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesInviteDeclined)));
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
      if (mounted) setState(() => _busySessionIds.remove(sessionId));
    }
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
        title: minigameGameNameLower(l10n, type.value),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
        busy: _busySessionIds.contains(session['id']),
        onTap: () => _showDetail(session['id'] as String),
        onAccept: isPending
            ? () => _acceptInvite(session['id'] as String)
            : null,
        onDecline: isPending
            ? () => _declineInvite(session['id'] as String)
            : null,
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
/// ready to accept" entry — which renders:
///
///   * the who-invited context (2026-08-30): "Invitado por {name}" for a
///     DIRECT session, "Grupo {name}" for a GROUP session — resolved from the
///     notification payload the server embeds (RLS keeps the raw group/user
///     rows unreadable to a non-member invitee),
///   * a trailing ACCEPT (emphasized check) / DECLINE (outlined x) pair so the
///     invite is handled straight from the list — accepting lands on the
///     partida lobby, declining drops the row — instead of deep-linking to
///     the session detail for the accept/decline pair.
///
/// Tapping the row body still deep-links to the accept/decline detail.
class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> session;
  final int index;
  final bool pendingInvite;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _SessionRow({
    required this.session,
    required this.index,
    this.pendingInvite = false,
    this.busy = false,
    required this.onTap,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = session['status'] as String?;
    final wager = (session['shard_wager'] as num?)?.toInt() ?? 0;
    final participants = (session['participants'] as List?)?.length ?? 0;
    final name = minigameSessionName(l10n, session, index: index);
    final inviterName = session['inviterName'] as String?;
    final groupName = session['groupName'] as String?;
    final groupId = session['group_id'] as String?;
    // Who invited me: a GROUP session shows the group name; a DIRECT session
    // shows the inviter's username (both ride the notification payload — RLS
    // hides the underlying rows from a non-member invitee).
    final fromLabel = pendingInvite && groupId != null
        ? groupName == null || groupName.isEmpty
              ? null
              : l10n.minigamesInviteFromGroup(groupName)
        : pendingInvite && inviterName != null && inviterName.isNotEmpty
        ? l10n.minigamesInviteFromDirect(inviterName)
        : null;

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
                    if (fromLabel != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        fromLabel,
                        style: const TextStyle(
                          color: AppColors.mutedStrong,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (pendingInvite)
                _PendingInviteActions(
                  busy: busy,
                  onAccept: onAccept,
                  onDecline: onDecline,
                )
              else
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

/// The inline ACCEPT (emphasized check) / DECLINE (outlined x) pair on a
/// pending-invite row (2026-08-30). The check is the emphasized voice — white
/// fill, black icon; the x is the outlined voice — transparent fill, white
/// border + icon. While the RPC is in flight both turn into a single spinner
/// and ignore taps (double-tap guard).
class _PendingInviteActions extends StatelessWidget {
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _PendingInviteActions({
    required this.busy,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (busy) {
      return const SizedBox(
        width: 72,
        height: 36,
        child: Center(child: VSpinner(size: 18)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            onPressed: onAccept,
            tooltip: l10n.minigamesInviteAccept,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white,
              shape: const RoundedRectangleBorder(),
              padding: EdgeInsets.zero,
              disabledBackgroundColor: AppColors.muted,
            ),
            icon: const Icon(Icons.check, size: 20, color: AppColors.discoBlack),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            onPressed: onDecline,
            tooltip: l10n.minigamesInviteDecline,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: AppColors.white),
              shape: const RoundedRectangleBorder(),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.close, size: 20, color: AppColors.white),
          ),
        ),
      ],
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
  final _roundsController = TextEditingController(text: '5');
  final _asyncRoundsController = TextEditingController(text: '1');
  final _asyncDaysController = TextEditingController(text: '1');
  MinigameScope _scope = MinigameScope.direct;
  String? _selectedGroupId;
  List<String> _inviteeIds = const [];
  final int _prizePositions = kDefaultPrizePositions;
  MinigamePlayMode _playMode = MinigamePlayMode.byTurns;
  bool _anonymous = false;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _wagerController.dispose();
    _roundsController.dispose();
    _asyncRoundsController.dispose();
    _asyncDaysController.dispose();
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
    final rounds = int.tryParse(_roundsController.text.trim()) ?? 5;
    final prizePositions = _prizePositions;
    final asyncRoundsPerPlayer =
        int.tryParse(_asyncRoundsController.text.trim()) ?? 1;
    final asyncDays = int.tryParse(_asyncDaysController.text.trim()) ?? 1;
    final asyncEndsAt = _playMode == MinigamePlayMode.async
        ? DateTime.now().add(Duration(days: asyncDays))
        : null;

    setState(() => _creating = true);
    try {
      if (_scope == MinigameScope.group) {
        final groupId = _selectedGroupId;
        if (groupId == null) return;
        await ref
            .read(minigameSessionsProvider(groupId).notifier)
            .create(
              type,
              wager,
              inviteeIds: _inviteeIds,
              name: name,
              rounds: rounds,
              prizePositions: prizePositions,
              playMode: _playMode,
              anonymous: _anonymous,
              asyncRoundsPerPlayer: asyncRoundsPerPlayer,
              asyncEndsAt: asyncEndsAt,
            );
      } else {
        await ref
            .read(myMinigameSessionsProvider.notifier)
            .create(
              type,
              wager,
              inviteeIds: _inviteeIds,
              name: name,
              rounds: rounds,
              prizePositions: prizePositions,
              playMode: _playMode,
              anonymous: _anonymous,
              asyncRoundsPerPlayer: asyncRoundsPerPlayer,
              asyncEndsAt: asyncEndsAt,
            );
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
            const SizedBox(height: AppSpacing.md),
            // 201_minigame_voting: the total-turn target (default 5). The
            // host-set prize-position (N) selector is deferred (TODO) — the
            // client sends the default N = 3.
            _RoundsRow(controller: _roundsController),
            const SizedBox(height: AppSpacing.md),
            // 202_minigame_play_v2: play-mode selector (by_turns / async) +
            // the async per-player rounds + timer (settable at creation, no
            // override after) + the anonymous toggle.
            Text(
              l10n.minigamesModeLabel.toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                VChip(
                  label: l10n.minigamesModeByTurns,
                  selected: _playMode == MinigamePlayMode.byTurns,
                  onSelected: () =>
                      setState(() => _playMode = MinigamePlayMode.byTurns),
                  compact: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                VChip(
                  label: l10n.minigamesModeAsync,
                  selected: _playMode == MinigamePlayMode.async,
                  onSelected: () =>
                      setState(() => _playMode = MinigamePlayMode.async),
                  compact: true,
                ),
              ],
            ),
            if (_playMode == MinigamePlayMode.async) ...[
              const SizedBox(height: AppSpacing.md),
              _RoundsRow(
                controller: _asyncRoundsController,
                label: l10n.minigamesAsyncRoundsLabel,
              ),
              const SizedBox(height: AppSpacing.md),
              _RoundsRow(
                controller: _asyncDaysController,
                label: l10n.minigamesAsyncEndsLabel,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _AnonymousToggle(
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            VButton.emphasized(
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

/// The rounds row in the create-partida wizard (201_minigame_voting): the
/// total-turn target (default 5) with a compact label to the left, mirroring
/// the wager row's layout. The play engine auto-finishes once this many
/// turns complete.
class _RoundsRow extends StatelessWidget {
  const _RoundsRow({required this.controller, this.label});

  final TextEditingController controller;

  /// Overrides the default "Rondas" label (202 async fields reuse the row
  /// with their own labels).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = label ?? l10n.minigamesRoundsLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Text(
            title,
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
              label: title,
              hint: l10n.minigamesRoundsHint,
              controller: controller,
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }
}

/// The anonymous-mode toggle in the create wizard (202_minigame_play_v2):
/// hides usernames during play — participants use temp nicknames until the
/// leaderboard.
class _AnonymousToggle extends StatelessWidget {
  const _AnonymousToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.minigamesAnonymousLabel,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
