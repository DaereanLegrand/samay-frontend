import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/screens/minigames_screen.dart'
    show minigameRejectionMessage;
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/features/minigames/widgets/minigame_pool.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_spinner.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Dedicated per-game landing page: the reusable shell every
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
/// the caller's partidas — ongoing first, then finished (a settled match
/// stays in the list instead of dropping off).
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

  void _showDetail(String sessionId) {
    context.push(RoutePaths.minigameSession(sessionId));
  }

  /// Inline ACCEPT: accepts the pending invite straight from the
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

  /// Inline DECLINE: declines the pending invite straight from
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
        titleWidget: MinigameHeaderTitle(
          word: minigameGameNameLower(l10n, type.value),
          secondary: type.tagline(l10n),
        ),
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
  /// (data-derived rows must be lazily built). Loading/error/empty
  /// collapse the list to the hero block alone.
  int _listItemCount(AppLocalizations l10n) {
    // Block 1: hero + CTA + "en curso" heading (+ its empty/loading state).
    // Then one item per partida (ongoing first, then finished) plus one per
    // pending invite.
    // Then block 2: the "abiertas" heading (+ its empty/loading state), and
    // one item per published partida (210_minigame_public).
    return 1 +
        _partidasOfThisGame().length +
        _pendingInvitesOfThisGame.length;
  }

  /// Every partida of this game the caller can see — ongoing AND finished.
  /// Ongoing rows come first, finished ones after, each newest first, so a
  /// settled match stays reachable at the foot of the list without pushing
  /// the live games down.
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
          // ONE tap to play: the lobby asks who is playing, then deals.
          VButton.emphasized(
            label: l10n.minigamesPlayNow,
            onPressed: () => context.push(RoutePaths.localLobby(type.value)),
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

    return const SizedBox.shrink();
  }


  /// Explanation + audience chip — the fixed hero block.
  /// No duplicated title: the AppBar already names the game — drop the
  /// redundant hero title + icon.
  Widget _buildHero(AppLocalizations l10n, MinigameType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
  /// [ListView.builder].
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
/// design-token voice for a secondary label (outlined, not emphasized).
class _AudienceTag extends StatelessWidget {
  final String label;

  const _AudienceTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.transparent,
        border: Border.all(color: context.palette.border),
        borderRadius: AppRadius.sharp,
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(color: context.palette.foreground),
      ),
    );
  }
}

/// One ongoing partida row: display name (user or auto partida-XX), the
/// wager or participant count, and the status chip. A row may be a PENDING
/// INVITE (170_minigame_invite_badges) — an invited friend's "partida-N
/// ready to accept" entry — which renders:
///
/// * the who-invited context: "Invitado por {name}" for a
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
    // name is resolved from the caller's groups to carry the
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
                    // Pool + live player count, no
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
                          style: AppTypography.bodySmall.copyWith(
                            color: context.palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    if (fromLabel != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        fromLabel,
                        style: AppTypography.bodySmall.copyWith(
                          color: context.palette.mutedForeground,
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
/// pending-invite row. The check is the emphasized voice — white
/// fill, black icon; the x is the outlined voice — transparent fill, white
/// border + icon. While the RPC is in flight both turn into a single spinner
/// and ignore taps (double-tap guard).
/// One row of the open lobby (210_minigame_public): the partida's name, who

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
              backgroundColor: context.palette.foreground,
              shape: const RoundedRectangleBorder(),
              padding: EdgeInsets.zero,
              disabledBackgroundColor: context.palette.mutedForeground,
            ),
            icon: Icon(Icons.check, size: 20, color: context.palette.background),
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
              backgroundColor: AppColors.transparent,
              side: BorderSide(color: context.palette.foreground),
              shape: const RoundedRectangleBorder(),
              padding: EdgeInsets.zero,
            ),
            icon: Icon(Icons.close, size: 20, color: context.palette.foreground),
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
