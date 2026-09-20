import 'package:flutter/cupertino.dart'
    show CupertinoPicker, FixedExtentScrollController;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/screens/minigames_screen.dart'
    show MinigameScope, minigameRejectionMessage;
import 'package:samay/features/minigames/widgets/minigame_pool.dart';
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
/// the caller's partidas — ongoing first, then finished (user directive
/// 2026-09-15: a settled match stays in the list instead of dropping off).
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
    // 2026-09-01: creation is invite-free — the host enters the LOBBY and
    // invites from there. The wizard pops the created session id; this screen
    // then jumps straight into the waiting room so the host lands with the
    // AppBar Invite button ready.
    final sessionId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _NewPartidaScreen(gameType: _type),
      ),
    );
    if (sessionId == null || !mounted) return;
    await ref.read(myMinigameSessionsProvider.notifier).refresh();
    if (!mounted) return;
    context.push(RoutePaths.minigameSession(sessionId));
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
    // Block 1: hero + CTA + "en curso" heading (+ its empty/loading state).
    // Then one item per partida (ongoing first, then finished) plus one per
    // pending invite.
    // Then block 2: the "abiertas" heading (+ its empty/loading state), and
    // one item per published partida (210_minigame_public).
    return 1 +
        _partidasOfThisGame().length +
        _pendingInvitesOfThisGame.length +
        1 +
        _publicRows.length;
  }

  /// Every partida of this game the caller can see — ongoing AND finished.
  /// Ongoing rows come first, finished ones after, each newest first, so a
  /// settled match stays reachable at the foot of the list (user directive
  /// 2026-09-15) without pushing the live games down.
  List<Map<String, dynamic>> _partidasOfThisGame() {
    final sessions = ref.watch(myMinigameSessionsProvider).valueOrNull;
    if (sessions == null) return const [];
    final rows = sessions
        .where((row) => row['game_type'] == _type.value)
        .toList();
    int finishedRank(Map<String, dynamic> row) =>
        row['status'] == 'finished' ? 1 : 0;
    rows.sort((a, b) {
      final byStatus = finishedRank(a).compareTo(finishedRank(b));
      if (byStatus != 0) return byStatus;
      final ac = a['created_at'] as String? ?? '';
      final bc = b['created_at'] as String? ?? '';
      return bc.compareTo(ac);
    });
    return rows;
  }

  /// The published partidas of this game (210_minigame_public) — the rows
  /// block 2 lists. Empty while loading / on error (the heading block shows
  /// the state).
  List<Map<String, dynamic>> get _publicRows =>
      ref.watch(publicMinigamesProvider(_type.value)).valueOrNull ?? const [];

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
    final partidas = _partidasOfThisGame();
    final pendingInvites = _pendingInvitesOfThisGame;
    final combined = [...partidas, ...pendingInvites];
    final rowIndex = index - 1;

    // Block 1 rows: the caller's partidas (ongoing, then finished) + pending
    // invites.
    if (rowIndex < combined.length) {
      final session = combined[rowIndex];
      final isPending = rowIndex >= partidas.length;
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

    // Block 2 heading: the open lobby (210_minigame_public).
    final publicIndex = rowIndex - combined.length;
    if (publicIndex == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.minigamesPublicLobbyTitle.toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildPublicLobbyState(l10n),
          ],
        ),
      );
    }

    // Block 2 rows: one published partida each.
    final publicRows = _publicRows;
    final pIndex = publicIndex - 1;
    if (pIndex < 0 || pIndex >= publicRows.length) {
      return const SizedBox.shrink();
    }
    final row = publicRows[pIndex];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: _PublicSessionRow(
        session: row,
        busy: _busySessionIds.contains(row['id']),
        onOpen: () => _showDetail(row['id'] as String),
        onJoin: () => _joinPublic(row['id'] as String),
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
  /// The open lobby's non-row state (210_minigame_public): the loader, the
  /// error retry or the empty line. The rows themselves are their own lazy
  /// list items, so this never has to size an unbounded child.
  Widget _buildPublicLobbyState(AppLocalizations l10n) {
    final feed = ref.watch(publicMinigamesProvider(_type.value));
    return feed.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: VSpinner(),
      ),
      error: (error, _) => ErrorView(
        message: l10n.minigamesErrorLoad,
        onRetry: () =>
            ref.read(publicMinigamesProvider(_type.value).notifier).refresh(),
      ),
      data: (rows) => rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.minigamesPublicEmpty,
                style: const TextStyle(
                  color: AppColors.mutedStrong,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  /// Joins a published partida and drops the caller straight into its lobby.
  Future<void> _joinPublic(String sessionId) async {
    if (_busySessionIds.contains(sessionId)) return;
    setState(() => _busySessionIds.add(sessionId));
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(publicMinigamesProvider(_type.value).notifier)
          .join(sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesPublicJoined)));
      _showDetail(sessionId);
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
      data: (_) {
        final partidas = _partidasOfThisGame();
        final pendingInvites = _pendingInvitesOfThisGame;
        if (partidas.isEmpty && pendingInvites.isEmpty) {
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

/// Small outlined pill for the audience fact ("Para jugar con amigos"):
/// transparent fill, 1px `border` hairline, white text, sharp corners — the
/// design-token voice for a secondary label (2026-08-28 user directive;
/// outlined, not emphasized).
class _AudienceTag extends StatelessWidget {
  final String label;

  const _AudienceTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.sharp,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
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
class _SessionRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = session['status'] as String?;
    final wager = (session['shard_wager'] as num?)?.toInt() ?? 0;
    final participants = (session['participants'] as List?)?.length ?? 0;
    final positions =
        (session['prize_positions'] as num?)?.toInt() ?? kDefaultPrizePositions;
    final name = minigameSessionName(l10n, session, index: index);
    final inviterName = session['inviterName'] as String?;
    final payloadGroupName = session['groupName'] as String?;
    final groupId = session['group_id'] as String?;
    // Who invited me / which group: a GROUP session shows the group name; a
    // DIRECT session shows the inviter's username (both ride the notification
    // payload for a PENDING row — RLS hides the underlying rows from a
    // non-member invitee). An ONGOING group row has no invite payload, so its
    // name is resolved from the caller's groups (1, 2026-09-15) to carry the
    // group tag in PARTIDAS EN CURSO.
    final groupName = pendingInvite
        ? payloadGroupName
        : groupId == null
        ? null
        : ref
              .watch(myGroupsProvider)
              .valueOrNull
              ?.where((g) => g.id == groupId)
              .firstOrNull
              ?.name;
    final fromLabel = groupId != null
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
                    // 2026-09-20 revamp: pool + live player count, no
                    // "apuesta"/"shards" literals. The pool recomputes when a
                    // participant joins (live session row).
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MinigamePoolAmount(
                          wager: wager,
                          players: participants,
                          positions: positions,
                          onTap: () => showMinigamePoolBreakdown(
                            context,
                            wager: wager,
                            players: participants,
                            positions: positions,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          '${l10n.minigamesParticipantsTitle.toUpperCase()} '
                          '$participants',
                          style: const TextStyle(
                            color: AppColors.mutedStrong,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
/// One row of the open lobby (210_minigame_public): the partida's name, who
/// hosts it and how full it is, with a Join button for anyone not in it yet.
class _PublicSessionRow extends StatelessWidget {
  const _PublicSessionRow({
    required this.session,
    required this.busy,
    required this.onOpen,
    required this.onJoin,
  });

  final Map<String, dynamic> session;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMember = session['is_member'] == true;
    final count = (session['player_count'] as num?)?.toInt() ?? 0;
    final limit = (session['player_limit'] as num?)?.toInt() ?? 0;
    final full = limit > 0 && count >= limit;
    final host = session['host_username'] as String? ?? '';
    final name =
        (session['name'] as String?)?.trim().isNotEmpty == true
            ? session['name'] as String
            : session['auto_name'] as String? ?? '';

    return InkWell(
      onTap: isMember ? onOpen : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.hairline),
        ),
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
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.minigamesPublicHostedBy(host)} · '
                    '${l10n.minigamesPublicPlayers(count, limit)}',
                    style: const TextStyle(
                      color: AppColors.mutedStrong,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isMember)
              VChip(label: l10n.minigamesPublicAlreadyIn, selected: false, compact: true)
            else if (full)
              VChip(label: l10n.minigamesPublicFull, selected: false, compact: true)
            else
              // VButton sizes itself to double.infinity, so inside a Row it
              // needs an explicit width box.
              SizedBox(
                width: 104,
                child: VButton.outlined(
                  label: l10n.minigamesPublicJoin,
                  loading: busy,
                  onPressed: onJoin,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
  /// Shared control-row height for the two-column mode section: the chips
  /// and the anonymous switch both occupy this fixed height so their control
  /// baselines align and the gap to their labels matches (2026-09-01).
  static const double wizardControlHeight = 40;

  final _nameController = TextEditingController();
  final _wagerController = TextEditingController(text: '10');
  final _roundsController = TextEditingController(text: '5');
  final _asyncRoundsController = TextEditingController(text: '1');
  final _asyncDaysController = TextEditingController(text: '1');
  MinigameScope _scope = MinigameScope.direct;
  String? _selectedGroupId;
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
            // 1 (2026-09-15): myMinigameSessionsProvider now also carries GROUP
            // rows; the DIRECT auto-name still counts only direct games. The
            // group scope reads its own per-group provider, so this is a no-op
            // there.
            .where(
              (row) =>
                  _scope == MinigameScope.group || row['group_id'] == null,
            )
            .length ??
        0;
    return l10n.minigamesAutoName(ongoing + 1);
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
      // 2026-09-01: the wizard creates with ZERO invitees — invites happen
      // in the lobby (invite_minigame_players). Both .create() calls return
      // the created session id so the wizard pops it up for auto-entry.
      final String sessionId;
      if (_scope == MinigameScope.group) {
        final groupId = _selectedGroupId;
        if (groupId == null) return;
        sessionId = await ref
            .read(minigameSessionsProvider(groupId).notifier)
            .create(
              type,
              wager,
              name: name,
              rounds: rounds,
              prizePositions: prizePositions,
              playMode: _playMode,
              anonymous: _anonymous,
              asyncRoundsPerPlayer: asyncRoundsPerPlayer,
              asyncEndsAt: asyncEndsAt,
            );
      } else {
        sessionId = await ref
            .read(myMinigameSessionsProvider.notifier)
            .create(
              type,
              wager,
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
      Navigator.of(context).pop(sessionId);
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
    final balance =
        (ref.watch(profile.myProfileProvider).valueOrNull?['personal_shards']
                as num? ??
            0).toInt();

    return Scaffold(
      body: VHeaderBar(
        // AppBar titles are lowercase (2026-08-30 directive): the l10n
        // default is capitalized ("Nueva partida"), so the wizard title
        // lowercases it here.
        title: l10n.minigamesNewPartida.toLowerCase(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            // The shard number+symbol shares the header's default action
            // nudge (VHeaderMetrics.actionNudge) — no local offset.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VShardIcon(size: AppIconSizes.sm),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  // Just the number — the shard icon already conveys the unit.
                  '$balance',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Scope: labels row (Partida | Elige un grupo) then controls row
            // (Directa/Grupo | selected group) — the two columns share the
            // same vertical lines (2026-09-01 directive).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WizardSectionLabel(l10n.minigamesScopeLabel),
                const Spacer(),
                if (_scope == MinigameScope.group)
                  InkWell(
                    onTap: _pickGroup,
                    child: _WizardSectionLabel(
                      l10n.minigamesChooseGroup,
                      alignEnd: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    VChip(
                      label: l10n.minigamesScopeDirect,
                      selected: _scope == MinigameScope.direct,
                      onSelected: () =>
                          setState(() => _scope = MinigameScope.direct),
                      compact: true,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    VChip(
                      label: l10n.minigamesScopeGroup,
                      selected: _scope == MinigameScope.group,
                      onSelected: () =>
                          setState(() => _scope = MinigameScope.group),
                      compact: true,
                    ),
                  ],
                ),
                const Spacer(),
                if (_scope == MinigameScope.group)
                  _SelectedGroupButton(
                    groupId: _selectedGroupId,
                    onTap: _pickGroup,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            VInput(
              label: l10n.minigamesPartidaNameLabel,
              hint: l10n.minigamesPartidaNameHint(_nextAutoName()),
              controller: _nameController,
            ),
            const SizedBox(height: AppSpacing.xs),
            // 202_minigame_play_v2: play-mode selector (by_turns / async) +
            // the async per-player rounds + timer (settable at creation, no
            // override after) + the anonymous toggle.
            // Two columns: left = "Modo de juego" + its Por turnos/Asíncrono
            // chips; right = "Partida anónima" + its switch. Labels share one
            // vertical line, controls the next (2026-09-01 directive). Both
            // control areas share [wizardControlHeight] so the chips and the
            // switch sit on the same baseline with identical label gaps.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WizardSectionLabel(l10n.minigamesModeLabel),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        height: wizardControlHeight,
                        child: Row(
                          children: [
                            VChip(
                              label: l10n.minigamesModeByTurns,
                              selected: _playMode == MinigamePlayMode.byTurns,
                              onSelected: () => setState(
                                () => _playMode = MinigamePlayMode.byTurns,
                              ),
                              compact: true,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            VChip(
                              label: l10n.minigamesModeAsync,
                              selected: _playMode == MinigamePlayMode.async,
                              onSelected: () => setState(
                                () => _playMode = MinigamePlayMode.async,
                              ),
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _AnonymousToggle(
                  value: _anonymous,
                  onChanged: (v) => setState(() => _anonymous = v),
                ),
              ],
            ),
            if (_playMode == MinigamePlayMode.async) ...[
              const SizedBox(height: AppSpacing.md),
              _LabeledNumberRow(
                label: l10n.minigamesAsyncRoundsLabel,
                controller: _asyncRoundsController,
                hint: l10n.minigamesRoundsHint,
              ),
              const SizedBox(height: AppSpacing.md),
              _LabeledNumberRow(
                label: l10n.minigamesAsyncEndsLabel,
                controller: _asyncDaysController,
                hint: l10n.minigamesRoundsHint,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            // 201_minigame_voting: the total-turn target (default 5). The
            // host-set prize-position (N) selector is deferred (TODO) — the
            // client sends the default N = 3.
            _WagerRoundsRow(
              wagerController: _wagerController,
              roundsController: _roundsController,
              onWagerChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xl),
            VButton.emphasized(
              label: l10n.minigamesCreate,
              loading: _creating,
              onPressed: _creating ? null : _create,
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the group picker bottom sheet (all the user's groups); picking a
  /// group selects it for the Grupo scope.
  Future<void> _pickGroup() async {
    final l10n = AppLocalizations.of(context);
    final groups = ref.read(myGroupsProvider).valueOrNull ?? const <Group>[];
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.minigamesNoGroupsBody)),
      );
      return;
    }
    final pickedId = await showGroupPickerSheet(
      context,
      groups: groups,
      selectedId: _selectedGroupId,
    );
    if (pickedId == null || !mounted) return;
    setState(() => _selectedGroupId = pickedId);
  }
}

/// The wizard's compact subtitle (create-partida) — UPPERCASE, regular weight,
/// small (2026-09-01 user directive: all subtitles uppercase + not bold).
/// Rendered ABOVE its control group; left-aligned labels get left padding,
/// right-aligned get right padding — ONLY on these title tiles.
class _WizardSectionLabel extends StatelessWidget {
  final String text;
  final bool alignEnd;

  const _WizardSectionLabel(this.text, {this.alignEnd = false});

  /// Shared style — the compact wizard-subtitle voice. Uppercase is applied at
  /// render time (`.toUpperCase()`); regular weight (not bold).
  static const TextStyle style = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 2.0,
    color: AppColors.mutedStrong,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: alignEnd ? 0 : AppSpacing.sm,
        right: alignEnd ? AppSpacing.sm : 0,
      ),
      child: Text(
        text.toUpperCase(),
        style: style,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      ),
    );
  }
}

/// The selected group's name on the RIGHT of the Directa/Grupo chips when
/// Grupo is selected — vertically centered with the chips. Tapping it opens
/// the group picker sheet. The "Elige un grupo" LABEL lives one row above in
/// the scope labels row (2026-09-01 directive); this widget renders only the
/// value (name or a "…" prompt while nothing is chosen).
class _SelectedGroupButton extends ConsumerWidget {
  final String? groupId;
  final VoidCallback onTap;

  const _SelectedGroupButton({required this.groupId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final group = ref
        .watch(myGroupsProvider)
        .valueOrNull
        ?.where((g) => g.id == groupId)
        .firstOrNull;
    final selectedName = group?.name;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              selectedName ?? l10n.minigamesChooseGroupEllipsis,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selectedName != null
                    ? AppColors.white
                    : AppColors.mutedStrong,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.expand_more,
            size: 18,
            color: AppColors.mutedStrong,
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet list of every [groups] group (radio-style selection). Picking
/// returns the chosen group id; dismissing returns null. The sheet is the
/// wizard's "picker with all groups list" (2026-09-01 user directive).
Future<String?> showGroupPickerSheet(
  BuildContext context, {
  required List<Group> groups,
  required String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.discoBlack,
    shape: const RoundedRectangleBorder(),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      return SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.hairline),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  l10n.minigamesChooseGroup,
                  style: AppTypography.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final group = groups[i];
                    final selected = group.id == selectedId;
                    return InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(group.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                              color: selected
                                  ? AppColors.white
                                  : AppColors.mutedStrong,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                group.name,
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.white
                                      : AppColors.mutedStrong,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The wager + rounds row in the create-partida wizard — two columns in one
/// row (2026-09-01 directive): LEFT = "Usando" (plain editable amount with a
/// shard icon on the right); RIGHT = "Rondas" (wheel picker).
class _WagerRoundsRow extends StatelessWidget {
  final TextEditingController wagerController;
  final TextEditingController roundsController;
  final ValueChanged<String> onWagerChanged;

  const _WagerRoundsRow({
    required this.wagerController,
    required this.roundsController,
    required this.onWagerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _labelFieldColumn(
            label: l10n.minigamesWagerLabel,
            // Constrain the wager input width so the amount + shard icon sit
            // together instead of the input stretching full column width
            // (2026-09-01).
            field: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                // Plain editable amount field (no wheel picker — the picker
                // stays only on Rondas; 2026-09-01). Shard symbol on the
                // RIGHT of the number.
                child: VInput(
                  label: l10n.minigamesWagerLabel,
                  hint: l10n.minigamesWagerDefaultHint,
                  controller: wagerController,
                  keyboardType: TextInputType.number,
                  onChanged: onWagerChanged,
                  suffixIcon: const Padding(
                    padding: EdgeInsets.only(
                      left: AppSpacing.xs,
                      right: AppSpacing.lg,
                    ),
                    child: VShardIcon(size: AppIconSizes.sm),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _labelFieldColumn(
            label: l10n.minigamesRoundsLabel,
            field: _NumberField(
              hint: l10n.minigamesRoundsHint,
              controller: roundsController,
              // Rondas value right-aligned like its column (2026-09-01).
              textAlign: TextAlign.end,
            ),
            // Rondas right-aligned against the column's right edge so the two
            // columns mirror (2026-09-01).
            alignEnd: true,
          ),
        ),
      ],
    );
  }

  Widget _labelFieldColumn({
    required String label,
    required Widget field,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: alignEnd ? 0 : AppSpacing.sm,
            right: alignEnd ? AppSpacing.sm : 0,
          ),
          child: Text(
            label.toUpperCase(),
            style: _WizardSectionLabel.style,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          ),
        ),
        // Tight gap between label and its input (2026-09-01).
        const SizedBox(height: 0),
        field,
      ],
    );
  }
}

/// A single labeled number row used by the async mode fields (per-player
/// rounds + game-time days): label ABOVE the wheel, same voice as the wager
/// column's label.
class _LabeledNumberRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _LabeledNumberRow({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Text(
            label.toUpperCase(),
            style: _WizardSectionLabel.style,
          ),
        ),
        const SizedBox(height: 2),
        _NumberField(hint: hint, controller: controller),
      ],
    );
  }
}

/// A compact numeric field that opens a scrollable wheel picker on tap
/// (2026-09-01 user directive: "Rondas" + the async fields use the scrollable
/// picker for easier set up; the wager "Usando" is a plain `VInput`). It
/// LOOKS like a numeric `VInput` (bare text on black, same hint voice) but the
/// keyboard never opens — the whole field is an inkwell that slides up a
/// monochrome `CupertinoPicker` bottom sheet; picking writes the value into
/// [controller].
class _NumberField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;

  /// Text alignment of the input value (the Rondas input right-aligns to
  /// mirror the right-aligned column; 2026-09-01).
  final TextAlign textAlign;

  const _NumberField({
    required this.hint,
    required this.controller,
    this.textAlign = TextAlign.start,
  });

  Future<void> _openPicker(BuildContext context) async {
    final current = int.tryParse(controller.text.trim()) ?? 0;
    final picked = await showNumberWheelSheet(context, min: 0, max: 50, value: current);
    if (picked == null || !context.mounted) return;
    controller.text = '$picked';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPicker(context),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: () => _openPicker(context),
        showCursor: false,
        textAlign: textAlign,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintStyle: const TextStyle(
            color: AppColors.mutedStrong,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 1.35,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

/// Opens a monochrome scrollable number wheel (sharp, hairline border, white
/// `CupertinoPicker` text on black — the design-token voice). Returns the
/// selected integer, or null when dismissed.
Future<int?> showNumberWheelSheet(
  BuildContext context, {
  required int min,
  required int max,
  required int value,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.discoBlack,
    shape: const RoundedRectangleBorder(),
    builder: (sheetContext) {
      final values = [for (var v = min; v <= max; v++) v];
      var index = (value - min).clamp(0, values.length - 1);
      final l10n = AppLocalizations.of(sheetContext);
      return SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.hairline),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(values[index]),
                      child: Text(l10n.commonOk),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 220,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: index),
                  itemExtent: 44,
                  onSelectedItemChanged: (i) => index = i,
                  selectionOverlay: const DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  children: [
                    for (final v in values)
                      Center(
                        child: Text(
                          '$v',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The anonymous-mode toggle in the create wizard (202_minigame_play_v2):
/// hides usernames during play — participants use temp nicknames until the
/// leaderboard. Two-column mode section: the label sits ABOVE the switch in
/// the right column, so both mode labels share one line and both controls
/// (chips + switch) the next (2026-09-01 directive).
class _AnonymousToggle extends StatelessWidget {
  const _AnonymousToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Text(
            l10n.minigamesAnonymousLabel.toUpperCase(),
            style: _WizardSectionLabel.style,
            textAlign: TextAlign.end,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Same fixed control height as the mode chips so the switch centers
        // on the chips' baseline; the materialSwitchTapTargetSize.shrinkWrap
        // removes the extra tap-target padding that inflated the label gap
        // and dropped the switch below the chips (2026-09-01). Right padding
        // mirrors the label's so text and switch share the right edge.
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: SizedBox(
            height: _NewPartidaScreenState.wizardControlHeight,
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}
