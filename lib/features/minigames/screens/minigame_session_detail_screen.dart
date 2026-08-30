import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

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
            context.mounted) {
          context.push(RoutePaths.truthDare(_sessionId));
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
                    if (isPending)
                      _InviteCard(
                        onAccept: () => _accept(context, ref, l10n),
                        onDecline: () => _decline(context, ref, l10n),
                      )
                    else if (inviteStatus == 'pending' && finished)
                      VCard(child: Text(l10n.minigamesInviteClosed))
                    else
                      _LobbySection(sessionId: _sessionId, finished: finished),
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
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }
}

/// The accept/decline pair for a PENDING invitee (unchanged 140 behavior).
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.onAccept, required this.onDecline});

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.minigamesInvitePendingBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
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
                      onRemove: () =>
                          _confirmRemove(context, ref, participants[i]),
                    ),
                  ],
                ],
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        if (!finished) ...[
          if (isCreator)
            VButton.emphasized(
              label: l10n.minigamesStart,
              loading: gameState.isLoading,
              // Start is disabled while the countdown runs — the host
              // cancels instead (190_minigame_countdown).
              onPressed: isPlaying || isCountdown
                  ? null
                  : () => _start(context, ref),
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
      if (context.mounted) Navigator.of(context).pop();
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
class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.isCreator,
    required this.canRemove,
    required this.onRemove,
  });

  final MinigameParticipant participant;
  final bool isCreator;
  final bool canRemove;
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
          // emphasized) "Listo"/"Ready" with NO username (2026-08-30).
          if (!isCreator && participant.ready)
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

/// The full-screen pre-play countdown (190_minigame_countdown): a large
/// 5→0 number seeded from the server-set `countdown_ends_at`, shown to every
/// participant the moment the host taps Start. The timer is purely visual —
/// the AUTHORITATIVE transition back to the game is the server flipping
/// countdown → playing on the game-state row (streamed via realtime); the
/// overlay's own tick only nudges a re-read at 0 so the flip is observed
/// promptly. Only the HOST gets the Cancel button (wired to
/// `cancel_minigame_start`, creator-only server-side); when the countdown
/// ends uncancelled, the whole lobby navigates to the play screen together.
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
  Timer? _ticker;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    // Seed the display from the server deadline (covers a client that enters
    // the lobby mid-countdown); tick every second. Ticking at 0 nudges a
    // re-read so the server performs the authoritative countdown → playing
    // flip promptly.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = ref.read(minigameGameStateProvider(widget.sessionId));
      final deadline = state.valueOrNull?.skeleton.countdownEndsAt;
      if (deadline == null) return;
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero && mounted) {
        _ticker?.cancel();
        ref
            .read(minigameGameStateProvider(widget.sessionId).notifier)
            .refresh();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int _remaining() {
    final state = ref.read(minigameGameStateProvider(widget.sessionId));
    final deadline = state.valueOrNull?.skeleton.countdownEndsAt;
    if (deadline == null) return _seconds;
    final remaining = deadline.difference(DateTime.now()).inSeconds;
    return remaining.clamp(0, _seconds);
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      await ref
          .read(minigameGameStateProvider(widget.sessionId).notifier)
          .cancelStart();
    } catch (e) {
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
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VDisplayText(text: '${_remaining()}', size: 64),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.minigamesCountdownStarting,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (widget.isCreator)
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
