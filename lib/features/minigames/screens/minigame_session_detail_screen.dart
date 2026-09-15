import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/screens/minigame_invite_screen.dart';
import 'package:samay/features/minigames/screens/minigames_screen.dart'
    show minigameRejectionMessage;
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// Partida lobby (180_minigame_lobby) — the session detail screen, now the
/// game's pre-play room. Shows the game (the AppBar is its LOWERCASE name,
/// e.g. "verdad o reto"), the partida name, the wager/status, a REALTIME
/// participants list with a Ready toggle per player, a creator-only Start
/// button (backend-enforced via `init_minigame_game_state` → `not_creator`),
/// and creator-only player removal (wager refunded server-side).
///
/// A PENDING invitee (who need not be a group member — `ms_read_invitee`
/// opened the row) still gets the Aceptar/Rechazar pair instead of the lobby;
/// accepting adds them to the roster live.
///
/// Live state: the roster rides [minigameParticipantsProvider] (names/avatars
/// via one RPC + the authoritative ready map from
/// [minigameGameStateProvider], both streaming through their realtime
/// channels); participant joins/removes arrive via the `minigame_sessions`
/// realtime stream feeding [sessionStatusProvider].
class MinigameSessionDetailScreen extends ConsumerStatefulWidget {
  const MinigameSessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<MinigameSessionDetailScreen> createState() =>
      _MinigameSessionDetailScreenState();
}

class _MinigameSessionDetailScreenState
    extends ConsumerState<MinigameSessionDetailScreen> {
  /// Whether this client was ever seen as a participant — gates the kicked
  /// detection so a PENDING invitee (who is legitimately not in participants
  /// yet) is never flagged.
  bool _wasParticipant = false;
  bool _kickedShown = false;
  Timer? _kickPoller;

  /// D (2026-09-15): true from the countdown→playing flip until the opaque
  /// play route has committed. The countdown overlay is dropped in the same
  /// rebuild that triggers the push; without this cover the lobby showed
  /// through the play screen's transition.
  bool _startingNavigation = false;

  /// Guards the countdown→playing auto-push against realtime re-emissions so
  /// the play screen is pushed exactly once per countdown.
  bool _navigatedToMatch = false;

  String get _sessionId => widget.sessionId;

  @override
  void initState() {
    super.initState();
    // 2026-08-30: a REMOVED participant can no longer read the session row
    // (RLS) and realtime stops delivering to them, so the kicked user's UI
    // would otherwise sit stale forever. Poll the authoritative session state
    // and surface the "Oops!" popup once the user stops being a participant.
    _kickPoller = Timer.periodic(const Duration(seconds: 3), (_) => _checkKicked());
  }

  @override
  void dispose() {
    _kickPoller?.cancel();
    super.dispose();
  }

  void _checkKicked() {
    if (_kickedShown || !mounted) return;
    final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (myId == null) return;
    // 2026-08-30: a REMOVED participant loses RLS read access to the session
    // row, so the CACHED provider stays frozen with the old participants list
    // forever. Poll the RAW service instead — getSession returns null once the
    // row is unreadable, the definitive kicked signal. Never flag on a
    // transient network error.
    ref
        .read(minigameServiceProvider)
        .getSession(_sessionId)
        .then((row) {
      if (!mounted || _kickedShown) return;
      if (row == null) {
        if (_wasParticipant) _showKicked();
        return;
      }
      final ids = (row['participants'] as List?)?.cast<String?>() ?? const [];
      if (ids.contains(myId)) {
        _wasParticipant = true;
        return;
      }
      if (_wasParticipant) _showKicked();
    }).catchError((Object _) {
      // Transient network/server error — skip this tick, never a false kick.
    });
  }

  Future<void> _showKicked() async {
    if (!mounted || _kickedShown) return;
    _kickedShown = true;
    _kickPoller?.cancel();
    // 2026-08-30: refresh the kicked client's cached lists so returning to the
    // game landing page drops the match (PARTIDAS EN CURSO) and any closed
    // invite row — without a hot restart.
    ref.invalidate(myMinigameSessionsProvider);
    ref.invalidate(myPendingInvitesProvider);
    ref.invalidate(minigameInviteProvider(_sessionId));
    ref.invalidate(minigameParticipantsProvider(_sessionId));
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.minigamesKickedTitle),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: Text(l10n.commonBack),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final session = ref.watch(sessionStatusProvider(_sessionId));
    final invite = ref.watch(minigameInviteProvider(_sessionId));
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final participantIds =
        (session.valueOrNull?['participants'] as List?)?.cast<String?>() ??
            const [];
    final isCreator = participantIds.isNotEmpty && participantIds.first == myId;
    final gameState = ref.watch(minigameGameStateProvider(_sessionId));
    // The session status also gates the AppBar Invite button (host-only, while
    // the partida is still active — 205_minigame_invite_lobby).
    final isFinished = session.valueOrNull?['status'] == 'finished';

    // 209_minigame_invite_context (2026-09-11): the authoritative "am I in
    // this session" switch. A non-participant is a pending invitee or a
    // stranger — neither may ever render `_LobbySection`, whose roster RPC is
    // readable to a pending invitee (that was the pre-accept roster flash).
    final isParticipant = myId != null && participantIds.contains(myId);
    // Only a non-participant needs the inviter context (the host has no invite
    // row), so participants never pay for the extra RPC.
    final inviteContext = (!isParticipant && !isFinished)
        ? ref.watch(minigameInviteContextProvider(_sessionId))
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    // 190_minigame_countdown: when the server flips countdown → playing (the
    // 5s deadline passed and the host did not cancel), EVERY participant is
    // taken to the play screen together — the countdown overlay is replaced
    // by the game. Ref.listen (not watch) so navigation stays a side effect.
    // The roster is re-read fresh inside the callback so a participant whose
    // session row loaded after this build still navigates.
    ref.listen<AsyncValue<MinigameGameState>>(
      minigameGameStateProvider(_sessionId),
      (previous, next) {
        final wasCountdown = previous?.valueOrNull?.skeleton.isCountdown ??
            false;
        final phase = next.valueOrNull?.skeleton.phase;
        final currentIds =
            (ref.read(sessionStatusProvider(_sessionId)).valueOrNull
                    ?['participants'] as List?)
                ?.cast<String?>() ??
                const [];
        final isParticipant =
            currentIds.isNotEmpty && currentIds.contains(myId);
        if (isParticipant &&
            wasCountdown &&
            phase == MinigamePhase.playing &&
            context.mounted &&
            !_navigatedToMatch) {
          _navigatedToMatch = true;
          // D: cover the lobby in the same frame the countdown overlay drops,
          // then push the opaque play route. The cover holds until that route
          // has committed, so only the match screen is ever visible.
          setState(() => _startingNavigation = true);
          context.push(RoutePaths.truthDare(_sessionId));
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            if (mounted) setState(() => _startingNavigation = false);
          });
        }
      },
    );

    return Scaffold(
      body: VHeaderBar(
        // The AppBar title is the minigame name in LOWERCASE (2026-08-30
        // user directive): "partida" → "verdad o reto", "game" → "truth or
        // dare".
        title: session.valueOrNull == null
            ? l10n.minigamesDetailTitle
            : minigameGameNameLower(
                l10n,
                session.valueOrNull!['game_type'] as String?,
              ),
        // 2026-09-01: invites moved out of match creation into the lobby.
        // The HOST (participants[0]) sees the Invite button at the title's
        // right while waiting — inviting is done AFTER the match exists.
        actions: [
          if (isCreator && !isFinished)
            IconButton(
              icon: const Icon(Icons.person_add_alt),
              tooltip: l10n.minigamesInviteTitle,
              color: AppColors.white,
              onPressed: () => _invite(context, ref, l10n),
            ),
        ],
        child: session.when(
          loading: () => const VLoadingView(),
          error: (e, _) => ErrorView(
            message: l10n.minigamesErrorLoad,
            onRetry: () => ref.invalidate(sessionStatusProvider(_sessionId)),
          ),
          data: (row) {
            final status = row['status'] as String?;
            final wager = (row['shard_wager'] as num?)?.toInt() ?? 0;
            final finished = status == 'finished';
            final inviteStatus = invite.valueOrNull?['status'] as String?;
            final isPending = inviteStatus == 'pending' && !finished;
            // The partida name (user title or the canonical server auto
            // partida-N — 170_minigame_invite_badges) so an invited friend
            // sees exactly the match they were invited to (e.g. "partida-1").
            final partidaName = minigameSessionName(l10n, row);

            final countdown = gameState.valueOrNull?.skeleton.isCountdown ??
                false;

            // 209_minigame_invite_context (2026-09-11): a not-yet-accepted
            // invitee must never see the roster. `isParticipant` gates the
            // lobby; a non-participant waits on the invite/context load and
            // then renders ONLY the inviter ("INVITADO POR").
            final Widget inviteOrLobby;
            if (isParticipant) {
              inviteOrLobby = _LobbySection(
                sessionId: _sessionId,
                finished: finished,
              );
            } else if (invite.isLoading ||
                (isPending && inviteContext.isLoading)) {
              inviteOrLobby = const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: VLoadingView(),
              );
            } else if (isPending) {
              inviteOrLobby = _InviteCard(
                inviter: inviteContext.valueOrNull?['inviter']
                    as Map<String, dynamic>?,
                groupName: inviteContext.valueOrNull?['groupName'] as String?,
                onAccept: () => _accept(context, ref, l10n),
                onDecline: () => _decline(context, ref, l10n),
              );
            } else {
              // No invite and not a participant (stranger), or a pending
              // invite on a finished session: nothing may be revealed.
              inviteOrLobby = VCard(child: Text(l10n.minigamesInviteClosed));
            }

            return Stack(
              children: [
                ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    Text(
                      partidaName,
                      style: const TextStyle(
                        color: AppColors.mutedStrong,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    VCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wager > 0
                                ? l10n.minigamesWagerPerPerson(wager)
                                : l10n.minigamesWagerFree,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.minigamesParticipants(
                              (row['participants'] as List?)?.length ?? 0,
                            ),
                            style: const TextStyle(
                              color: AppColors.mutedStrong,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          VChip(
                            label: finished
                                ? l10n.minigamesStatusFinished
                                : l10n.minigamesStatusActive,
                            selected: !finished,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    inviteOrLobby,
                  ],
                ),
                // 190: the full-screen pre-play countdown overlay (all
                // participants see it; only the host can cancel).
                if (countdown)
                  Positioned.fill(
                    child: _CountdownOverlay(
                      sessionId: _sessionId,
                      isCreator: isCreator,
                    ),
                  )
                else if (_startingNavigation)
                  // D: the countdown just ended and the opaque play route is
                  // being pushed — hold a full-screen cover so the lobby is
                  // never exposed during the handoff.
                  const Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.surface,
                      child: VLoadingView(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    try {
      await ref.read(minigameInviteProvider(_sessionId).notifier).accept();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesInviteAccepted)));
    } on MinigameSessionRejectedException catch (e) {
      // The accept RPC rejects with a typed status (insufficient_shards for a
      // player without the funds, session_finished for a closed game…) — map
      // it through the friendly localized message, never the raw error text.
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(minigameRejectionMessage(l10n, e.rejection))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    try {
      await ref.read(minigameInviteProvider(_sessionId).notifier).decline();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesInviteDeclined)));
    } on MinigameSessionRejectedException catch (e) {
      // Typed rejection → friendly localized message (I-62 pattern), never
      // the raw exception text.
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(minigameRejectionMessage(l10n, e.rejection))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  /// The HOST's AppBar invite (205_minigame_invite_lobby): opens the player
  /// picker with the current participants excluded (no re-picking people
  /// already in the lobby), then calls the lobby invite RPC and surfaces a
  /// confirmation. Typed rejections (blocked / friends-only / cap) map to
  /// the friendly localized message — never the raw error text.
  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final participantIds =
        (ref.read(sessionStatusProvider(_sessionId)).valueOrNull?['participants']
                as List?)
            ?.whereType<String>()
            .toSet() ??
        const <String>{};
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => MinigameInviteScreen(
          excludedIds: participantIds,
          sessionId: _sessionId,
        ),
      ),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    try {
      await ref
          .read(minigameInviteProvider(_sessionId).notifier)
          .invitePlayers(picked);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesInviteSent)));
    } on MinigameSessionRejectedException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(minigameRejectionMessage(l10n, e.rejection))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }
}

/// The accept/decline card for a PENDING invitee. Shows the inviter as an
/// "INVITADO POR" row — avatar + username + subtitle, the same voice as a
/// [_ParticipantRow] — and NOTHING else about the roster
/// (209_minigame_invite_context). On accept `isParticipant` flips and this
/// card is replaced by the lobby, so the label disappears on RPC confirmation.
class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.inviter,
    this.groupName,
    required this.onAccept,
    required this.onDecline,
  });

  /// The inviter's `{id, username, avatar_url}` from
  /// `get_minigame_invite_context` (null when the profile is deleted/blocked).
  final Map<String, dynamic>? inviter;

  /// The group name for a GROUP session, null for a direct one.
  final String? groupName;

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final username = (inviter?['username'] as String?)?.trim();
    final avatarUrl = inviter?['avatar_url'] as String?;
    final hasName = username != null && username.isNotEmpty;
    final initials = hasName ? username[0] : '?';

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.minigamesInvitePendingBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          // INVITADO POR — the inviter alone, styled like a participant row.
          Row(
            children: [
              ProfileAvatar(
                size: 36,
                initials: initials,
                imageUrl: avatarUrl,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasName ? username : l10n.minigamesInvitedBy,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (hasName)
                      Text(
                        l10n.minigamesInvitedBy,
                        style: const TextStyle(
                          color: AppColors.mutedStrong,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (groupName != null && groupName!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.minigamesInviteFromGroup(groupName!),
              style: const TextStyle(
                color: AppColors.mutedStrong,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: VButton.emphasized(
                  label: l10n.minigamesInviteAccept,
                  onPressed: onAccept,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: VButton.outlined(
                  label: l10n.minigamesInviteDecline,
                  onPressed: onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The partida lobby: realtime participants list (ready toggles live), the
/// creator's Start button (backend-enforced creator-only), and creator
/// removal. Hidden for pending invitees and finished sessions.
class _LobbySection extends ConsumerWidget {
  const _LobbySection({required this.sessionId, required this.finished});

  final String sessionId;
  final bool finished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final session = ref.watch(sessionStatusProvider(sessionId)).valueOrNull;
    final participantIds =
        (session?['participants'] as List?)?.cast<String?>() ?? const [];
    final isCreator = participantIds.isNotEmpty && participantIds.first == myId;
    final gameState = ref.watch(minigameGameStateProvider(sessionId));
    final skeleton = gameState.valueOrNull?.skeleton;
    final isPlaying = skeleton?.phase == MinigamePhase.playing;
    final isCountdown = skeleton?.isCountdown ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.minigamesParticipantsTitle.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        ref
            .watch(minigameParticipantsProvider(sessionId))
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: VLoadingView(),
              ),
              error: (e, _) => ErrorView(
                message: e.toAppError().message,
                onRetry: () =>
                    ref.invalidate(minigameParticipantsProvider(sessionId)),
              ),
              data: (participants) => Column(
                children: [
                  // The HOST marker resolves from the AUTHORITATIVE
                  // participant[0] id (null-safe). The roster may briefly lag
                  // that array after a join/remove (hot reload preserves
                  // provider state) — a mismatch must mark the wrong player,
                  // never crash a row (2026-08-30).
                  for (var i = 0; i < participants.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ParticipantRow(
                      participant: participants[i],
                      isCreator: participantIds.isNotEmpty &&
                          participants[i].id == participantIds.first,
                      canRemove:
                          isCreator && participants[i].id != myId && !finished,
                      // The "Listo" ready chip is pre-play semantics — once
                      // the match is running it means nothing (2026-09-02).
                      showReadyChip: !isPlaying,
                      onRemove: () =>
                          _confirmRemove(context, ref, participants[i]),
                    ),
                  ],
                ],
              ),
            ),
        // Anonymous mode: the temp nickname lives in the LOBBY (never during
        // the match). A button opens a popup; the current name shows inline
        // and streams live to every lobby member via minigame_aliases.
        if ((skeleton?.anonymous ?? false) && !isPlaying) ...[
          const SizedBox(height: AppSpacing.md),
          _AliasButton(sessionId: sessionId),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (!finished) ...[
          // 2026-09-02: the match is already RUNNING (a participant reopened
          // the partida after leaving the app / losing connection mid-play —
          // they never left the roster). Empezar/¿Listo? are pre-play
          // semantics and mean nothing here, so BOTH host and participant get
          // a "Volver a la partida" rejoin CTA that routes back into the play
          // screen (TruthDareScreen renders the correct mid-round state from
          // the same providers).
          if (isPlaying)
            VButton.emphasized(
              label: l10n.minigamesRejoin,
              onPressed: () => _rejoin(context, ref),
            )
          else if (isCreator)
            VButton.emphasized(
              label: l10n.minigamesStart,
              loading: gameState.isLoading,
              // Start is disabled while the countdown runs — the host
              // cancels instead (190_minigame_countdown).
              onPressed: isCountdown ? null : () => _start(context, ref),
            )
          else if (!isCountdown)
            _ReadyToggle(
              isReady: gameState.valueOrNull?.isReady(myId ?? '') ?? false,
              onPressed: () => _toggleReady(context, ref),
            ),
        ],
      ],
    );
  }

  /// Returns the caller to the RUNNING match (2026-09-02): pushes the play
  /// screen exactly like the live countdown → playing navigation does — the
  /// game-state row is already `playing` and holds the current round, so
  /// TruthDareScreen picks up the right subject/prompt/reactions.
  void _rejoin(BuildContext context, WidgetRef ref) {
    context.push(RoutePaths.truthDare(sessionId));
  }

  Future<void> _toggleReady(BuildContext context, WidgetRef ref) async {
    final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (myId == null) return;
    final current = ref.read(minigameGameStateProvider(sessionId)).valueOrNull;
    final isReady = current?.isReady(myId) ?? false;
    await ref
        .read(minigameGameStateProvider(sessionId).notifier)
        .setReady(!isReady);
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    try {
      // 190_minigame_countdown: Start only triggers the server signal — the
      // countdown overlay appears for everyone and navigation happens on the
      // countdown → playing flip (or the host cancels and everyone stays).
      await ref.read(minigameGameStateProvider(sessionId).notifier).start();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    MinigameParticipant participant,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.minigamesRemovePlayerConfirm(participant.username)),
        content: Text(l10n.minigamesRemovePlayerConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.minigamesRemovePlayer),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      // 2026-08-30 stale-state repair: the RPC either removes the player or
      // answers a typed `not_participant` (the row was already refreshed — a
      // double tap, or a concurrent remove). The removed player is already
      // out server-side; there is nothing to undo, so the retry must not
      // resurface an error. Pop the dialog so the tap feels acknowledged.
      await ref
          .read(minigameGameStateProvider(sessionId).notifier)
          .removeParticipant(participant.id);
      // Pop the lobby back to the list ONLY when it was actually pushed —
      // when the session detail is the root route (deep link / direct
      // navigation) there is nothing to pop to, and popping would leave
      // go_router re-pushing the same page (Navigator `!_debugLocked` teardown
      // race).
      if (context.mounted) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      }
    } catch (e) {
      if (e.toAppError().code == 'NOT_FOUND' && context.mounted) {
        Navigator.of(context).pop();
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }
}

/// One participant row in the lobby: avatar, username (+ host marker), a
/// Ready chip for OTHERS (only when they are ready — a not-ready player shows
/// nothing, and the HOST never shows a ready chip: the host is ready by
/// default, 2026-08-30), and a creator-only remove button.
///
/// [showReadyChip] suppresses the "Listo" chip once the match is RUNNING
/// (2026-09-02) — ready is pre-play semantics and means nothing mid-game.
class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.isCreator,
    required this.canRemove,
    this.showReadyChip = true,
    required this.onRemove,
  });

  final MinigameParticipant participant;
  final bool isCreator;
  final bool canRemove;
  final bool showReadyChip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final initials = participant.username.isEmpty
        ? '?'
        : participant.username[0];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          ProfileAvatar(
            size: 36,
            initials: initials,
            imageUrl: participant.avatarUrl,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.username,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (isCreator)
                  Text(
                    l10n.minigamesCreator,
                    style: const TextStyle(
                      color: AppColors.mutedStrong,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // Others show their ready state only once ready — a not-ready
          // participant renders nothing, and the chip is the plain (non-
          // emphasized) "Listo"/"Ready" with NO username (2026-08-30). Hidden
          // entirely once the match is running (2026-09-02).
          if (showReadyChip && !isCreator && participant.ready)
            VChip(label: l10n.minigamesReady, selected: false, compact: true),
          if (canRemove) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(Icons.person_remove_outlined, size: 18),
              tooltip: l10n.minigamesRemovePlayer,
              color: AppColors.white,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

/// The non-creator participant's ready toggle — sits exactly where the
/// creator's "Empezar partida" button does (2026-08-30). Not ready shows the
/// EMPHASIZED "¿Listo?" (white fill, black font); once ready it flips to the
/// flat outlined "Listo". The HOST is ready by default and never sees this.
class _ReadyToggle extends StatelessWidget {
  const _ReadyToggle({required this.isReady, required this.onPressed});

  final bool isReady;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return isReady
        ? VButton.outlined(label: l10n.minigamesReady, onPressed: onPressed)
        : VButton.emphasized(
            label: l10n.minigamesReadyQuestion,
            onPressed: onPressed,
          );
  }
}

/// The full-screen pre-play countdown (190 + 203_minigame_host_start). The
/// countdown is DEVICE-BASED: every participant runs a 5s countdown from
/// their own internal clock, started the moment the server's `countdown`
/// phase streams in (there is NO server deadline / countdown_ends_at).
///
///   * HOST sees the countdown number AND a Cancel button. When its own
///     countdown reaches 0 without a cancel, the host's device calls
///     `start_minigame_match` (203) → the server flips countdown → playing →
///     realtime streams it to everyone, who navigate to the play screen
///     together.
///   * NON-HOSTS see the countdown number. At 1 they switch to a
///     "Waiting for the host…" line (Counter A is done; only the host decides
///     whether the match actually starts). A 10s watchdog from that moment
///     surfaces a host-error if neither start nor cancel arrives.
class _CountdownOverlay extends ConsumerStatefulWidget {
  const _CountdownOverlay({
    required this.sessionId,
    required this.isCreator,
  });

  final String sessionId;
  final bool isCreator;

  @override
  ConsumerState<_CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends ConsumerState<_CountdownOverlay> {
  static const int _seconds = 5;
  static const int _waitingTimeoutSeconds = 10;

  Timer? _ticker;
  Timer? _watchdog;
  bool _cancelling = false;
  bool _starting = false;
  bool _hostError = false;
  int _remaining = _seconds;

  @override
  void initState() {
    super.initState();
    AppLogger.instance.debug(
      'countdown overlay mounted session=${widget.sessionId} '
      'isCreator=${widget.isCreator} seconds=$_seconds',
    );
    // Device-clock countdown, ticked every second with a repaint. The host's
    // device auto-confirms at 0; non-hosts go to "waiting for the host".
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _ticker?.cancel();
        AppLogger.instance.debug(
          'countdown tick finished session=${widget.sessionId} '
          'isCreator=${widget.isCreator}',
        );
        if (widget.isCreator) {
          _confirmStart();
        } else {
          setState(() {
            _remaining = 0;
          });
          _armWaitingWatchdog();
        }
        return;
      }
      setState(() => _remaining -= 1);
      AppLogger.instance.debug(
        'countdown tick session=${widget.sessionId} remaining=$_remaining',
      );
    });
  }

  @override
  void dispose() {
    AppLogger.instance.debug(
      'countdown overlay disposed session=${widget.sessionId} '
      'isCreator=${widget.isCreator}',
    );
    _ticker?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  /// The host's device confirms the countdown finished without a cancel:
  /// calls `start_minigame_match` (203). The server streams the flip to every
  /// participant.
  Future<void> _confirmStart() async {
    if (_starting || !mounted) return;
    AppLogger.instance.debug(
      'countdown host confirming start session=${widget.sessionId}',
    );
    setState(() => _starting = true);
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .startMatch();
      AppLogger.instance.debug(
        'countdown host startMatch succeeded session=${widget.sessionId}',
      );
    } catch (e) {
      AppLogger.instance.warn(
        'countdown host startMatch FAILED session=${widget.sessionId} '
        'type=${e.runtimeType}: $e',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Non-host watchdog: after the on-device countdown ends, wait up to 10s for
  /// the host's start (or a cancel). If neither arrives, surface a host-error.
  void _armWaitingWatchdog() {
    AppLogger.instance.debug(
      'countdown non-host waiting for host session=${widget.sessionId} '
      'watchdogSeconds=$_waitingTimeoutSeconds',
    );
    _watchdog = Timer(const Duration(seconds: _waitingTimeoutSeconds), () {
      if (!mounted) return;
      AppLogger.instance.warn(
        'countdown watchdog fired — host did not confirm/cancel '
        'session=${widget.sessionId}',
      );
      setState(() => _hostError = true);
    });
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    AppLogger.instance.debug(
      'countdown host cancelling session=${widget.sessionId}',
    );
    setState(() => _cancelling = true);
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .cancelStart();
      AppLogger.instance.debug(
        'countdown cancel succeeded session=${widget.sessionId}',
      );
    } catch (e) {
      AppLogger.instance.warn(
        'countdown cancel FAILED session=${widget.sessionId} '
        'type=${e.runtimeType}: $e',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String title;
    final bool showCancel = widget.isCreator && !_starting;
    final bool waitingForHost = !widget.isCreator && _remaining == 0;

    if (_hostError) {
      title = l10n.minigamesCountdownHostError;
    } else if (waitingForHost) {
      title = l10n.minigamesCountdownWaitingHost;
    } else if (widget.isCreator && _starting) {
      title = l10n.minigamesCountdownStarting;
    } else {
      title = l10n.minigamesCountdownStarting;
    }

    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VDisplayText(
              text: _hostError || waitingForHost ? '…' : '$_remaining',
              size: 64,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (showCancel)
              VButton.outlined(
                label: l10n.minigamesCountdownCancel,
                loading: _cancelling,
                onPressed: _cancel,
              ),
          ],
        ),
      ),
    );
  }
}

/// The anonymous-mode nickname control for the LOBBY (2026-09-10 move): shows
/// the caller's current temp nickname and an "update name" button that opens
/// [_AliasDialog]. The nickname is a display name (never encrypted) and
/// streams live to every lobby member via `minigame_aliases`; the server
/// enforces session-uniqueness (`set_minigame_alias` → `alias_taken`).
class _AliasButton extends ConsumerWidget {
  const _AliasButton({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final current = myId == null
        ? null
        : ref.watch(minigameAliasesProvider(sessionId)).valueOrNull?[myId];
    final display = current ?? defaultAnonAlias(l10n, seed: myId ?? '');

    return VCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.minigamesAliasLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.mutedStrong),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          VButton.outlined(
            label: l10n.minigamesAliasUpdate,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _AliasDialog(sessionId: sessionId, current: display),
            ),
          ),
        ],
      ),
    );
  }
}

/// The nickname popup: one field + a confirm that shows a spinner until the
/// RPC answers. On success it pops and the live `minigame_aliases` stream
/// updates every lobby; on `alias_taken` / any error it stays open and shows
/// the message.
class _AliasDialog extends ConsumerStatefulWidget {
  const _AliasDialog({required this.sessionId, required this.current});

  final String sessionId;
  final String current;

  @override
  ConsumerState<_AliasDialog> createState() => _AliasDialogState();
}

class _AliasDialogState extends ConsumerState<_AliasDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.current);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final alias = _controller.text.trim();
    if (alias.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(minigameAliasesProvider(widget.sessionId).notifier)
          .setAlias(widget.sessionId, alias);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toAppError().message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.minigamesAliasLabel),
      content: VInput(
        label: l10n.minigamesAliasLabel,
        hint: widget.current,
        controller: _controller,
        errorText: _error,
        maxLines: 1,
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.minigamesAliasUpdate),
        ),
      ],
    );
  }
}
