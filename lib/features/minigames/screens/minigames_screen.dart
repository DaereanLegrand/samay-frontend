import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/theme/group_theme_colors.dart';
import 'package:samay/features/groups/theme/group_theme_scope.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/features/minigames/widgets/minigame_pool.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// Friendly message for a rejected session creation (typed errors — the UI
/// never pattern-matches raw exception strings).
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
    MinigameSessionRejection.inviteeNotAllowed =>
      l10n.minigamesErrorInviteeNotAllowed,
    MinigameSessionRejection.inviteeFriendsOnly =>
      l10n.minigamesErrorInviteeFriendsOnly,
    MinigameSessionRejection.tooManyInvitees =>
      l10n.minigamesErrorTooManyInvitees,
    MinigameSessionRejection.playerLimitReached =>
      l10n.minigamesErrorPlayerLimitReached,
    MinigameSessionRejection.invalidRounds =>
      l10n.minigamesErrorInvalidRounds,
    MinigameSessionRejection.invalidPrizePositions =>
      l10n.minigamesErrorInvalidPrizePositions,
    MinigameSessionRejection.invalidPlayMode =>
      l10n.minigamesErrorInvalidPlayMode,
    MinigameSessionRejection.invalidAsyncRounds =>
      l10n.minigamesErrorInvalidAsyncRounds,
    MinigameSessionRejection.invalidAsyncEndsAt =>
      l10n.minigamesErrorInvalidAsyncEndsAt,
    MinigameSessionRejection.notAllowed => l10n.minigamesErrorNotAllowed,
    MinigameSessionRejection.invalidCode => l10n.minigamesErrorInvalidCode,
    MinigameSessionRejection.notAuthenticated ||
    MinigameSessionRejection.invalidWager => l10n.minigamesErrorCreate,
  };
}

/// The two minigame scopes: a DIRECT session
/// (no group — play with friends or non-friends without belonging to any
/// group) and a GROUP session.
enum MinigameScope { direct, group }

/// Minigames hub: the five game-type
/// cards (icon + name + tagline), the optional wager input (0 = no wager)
/// with the create action, and the session list with lifecycle status
/// chips. Tapping a session shows the detail placeholder — the per-game UIs
/// (turns, timers, votes) are future work.
///
/// A DIRECT/GROUP toggle sits at the top: Direct is first-class — a new
/// user with zero groups can play with a friend without creating a group;
/// groups stay a convenience (bulk-invite / regular play). [groupId] (route
/// from group detail) preselects the Group scope for that group; the toggle
/// still lets a member start a direct game from inside a group.
///
/// Monochrome: flat cards; selection emphasis is white.
class MinigamesScreen extends ConsumerStatefulWidget {
  const MinigamesScreen({super.key, this.groupId});

  /// The group preselected when arriving from a group surface (group detail
  /// button / group chat). Null = the DIRECT hub is the default scope.
  final String? groupId;

  @override
  ConsumerState<MinigamesScreen> createState() => _MinigamesScreenState();
}

class _MinigamesScreenState extends ConsumerState<MinigamesScreen> {
  late MinigameScope _scope;
  MinigameType? _selected;
  final TextEditingController _wagerController = TextEditingController();
  bool _creating = false;

  /// The group resolved in Group scope (null until the user picks one —
  /// preseeded from [MinigamesScreen.groupId]).
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId;
    _scope = widget.groupId == null
        ? MinigameScope.direct
        : MinigameScope.group;
  }

  @override
  void dispose() {
    _wagerController.dispose();
    super.dispose();
  }

  void _setScope(MinigameScope scope) {
    setState(() => _scope = scope);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final type = _selected;
    if (type == null) return;
    final wager = int.tryParse(_wagerController.text.trim()) ?? 0;

    // creation is invite-free — invites happen in the lobby
    // (invite_minigame_players). The hub.create() returns the session id,
    // so the host jumps straight into the waiting room with the AppBar
    // Invite button ready.
    setState(() => _creating = true);
    try {
      final String sessionId;
      if (_scope == MinigameScope.group) {
        final groupId = _selectedGroupId;
        if (groupId == null) return;
        sessionId = await ref
            .read(minigameSessionsProvider(groupId).notifier)
            .create(type, wager);
      } else {
        sessionId = await ref
            .read(myMinigameSessionsProvider.notifier)
            .create(type, wager);
      }
      if (!mounted) return;
      _wagerController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.minigamesCreated)));
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
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showDetail(String sessionId) {
    context.push(RoutePaths.minigameSession(sessionId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupId = _scope == MinigameScope.group ? _selectedGroupId : null;
    final theme = groupId == null
        ? null
        : ref.watch(groupThemeProvider(groupId)).valueOrNull;
    final palette = theme == null ? null : groupThemePaletteOf(theme);

    final body = VHeaderBar(
        // Two-row header: "juegos" over the "Te atreves" tagline.
        titleWidget: MinigameHeaderTitle(
          word: l10n.minigamesTitle,
          secondary: l10n.minigamesTagline,
        ),
        child: Column(
          children: [
            // "Elige un juego" sits IMMEDIATELY below the AppBar — the
            // Directa/Grupo scope row and the game picker follow underneath.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: VDisplayText(text: l10n.minigamesPickGame, size: 28),
              ),
            ),
            _buildScopeSwitch(l10n),
            Divider(
              height: 1,
              thickness: 1,
              color: palette?.hairline ?? AppColors.hairline,
            ),
            Expanded(
              child: _scope == MinigameScope.group && _selectedGroupId == null
                  ? _buildGroupPicker(l10n)
                  : Column(
                      children: [
                        _buildGamePicker(l10n),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: palette?.hairline ?? AppColors.hairline,
                        ),
                        Expanded(child: _buildSessions(l10n)),
                      ],
                    ),
            ),
          ],
        ),
    );

    if (palette == null) {
      return Scaffold(body: body);
    }
    return GroupThemeScope(
      palette: palette,
      child: Scaffold(
        backgroundColor: palette.background,
        body: body,
      ),
    );
  }

  /// Direct / Group toggle — Direct is the default scope for group-less
  /// entry, Group routes to the picker below. In Group scope the SELECTED
  /// group's name + circular banner sit at the LEFT of the row, and a
  /// switch-groups icon (with the red pending-invite badge) sits at the
  /// RIGHT.
  ///
  /// The row has a FIXED height so switching Directa ↔ Grupo never changes
  /// the layout height: the chips, the group banner+name and the switch icon
  /// all center within the same box.
  Widget _buildScopeSwitch(AppLocalizations l10n) {
    final inGroup = _scope == MinigameScope.group;
    final groupId = _selectedGroupId;
    final pendingInvites = ref.watch(pendingMinigameInvitesProvider);

    return Container(
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          VChip(
            label: l10n.minigamesScopeDirect,
            selected: _scope == MinigameScope.direct,
            onSelected: () => _setScope(MinigameScope.direct),
            compact: true,
          ),
          const SizedBox(width: AppSpacing.sm),
          VChip(
            label: l10n.minigamesScopeGroup,
            selected: _scope == MinigameScope.group,
            onSelected: () => _setScope(MinigameScope.group),
            compact: true,
          ),
          const Spacer(),
          if (inGroup && groupId != null) ...[
            _selectedGroupChip(groupId: groupId, onSwitch: _switchGroup),
            const SizedBox(width: AppSpacing.xs),
          ],
          if (inGroup)
            _SwitchGroupButton(
              pendingCount: pendingInvites,
              onPressed: _switchGroup,
              tooltip: l10n.minigamesChangeGroup,
            ),
        ],
      ),
    );
  }

  /// Opens the group picker again (switches the selected group). Group scope
  /// with a null selection routes to the picker body.
  void _switchGroup() {
    setState(() => _selectedGroupId = null);
  }

  /// The selected group's identity in the scope row: a circular banner
  /// (height == width, no taller than the Directa/Grupo chips) + the name —
  /// resolved from the groups list (the hub must show the group
  /// name when "Grupo" is selected).
  Widget _selectedGroupChip({
    required String groupId,
    required VoidCallback onSwitch,
  }) {
    return ref
        .watch(myGroupsProvider)
        .maybeWhen(
          data: (groups) {
            final group = groups.where((g) => g.id == groupId).firstOrNull;
            if (group == null) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GroupBannerAvatar(group: group, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Builder(
                    builder: (context) {
                      final p = GroupThemeScope.paletteOf(context);
                      final tinted =
                          !identical(p, GroupThemeScope.standardPalette);
                      return Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tinted ? p.foreground : AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }

  /// Group scope with no group chosen yet: the user's groups to pick from
  /// (or the create-a-group hint when they have none — a fresh user lands on
  /// Direct, so this is an edge state for group-seeking players).
  Widget _buildGroupPicker(AppLocalizations l10n) {
    return ref
        .watch(myGroupsProvider)
        .when(
          loading: () => const VLoadingView(),
          error: (e, _) => ErrorView(
            message: e.toAppError().message,
            onRetry: () => ref.invalidate(myGroupsProvider),
          ),
          data: (groups) {
            if (groups.isEmpty) {
              return VEmptyView(
                icon: Icons.group_outlined,
                title: l10n.minigamesNoGroups,
                description: l10n.minigamesNoGroupsBody,
                actionLabel: l10n.groupsCreateGroupAction,
                onAction: () async {
                  await context.push(RoutePaths.groupCreate);
                  ref.invalidate(myGroupsProvider);
                },
              );
            }
            return ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final group = groups[i];
                return ListTile(
                  leading: _GroupBannerAvatar(
                    group: group,
                    size: AppSpacing.avatar,
                  ),
                  title: Text(group.name),
                  onTap: () => setState(() => _selectedGroupId = group.id),
                );
              },
            );
          },
        );
  }

  Widget _buildGamePicker(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                child: VButton.dark(
                  label: l10n.minigamesCreate,
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

  /// The scoped session list (the picker above sits outside it, so the list
  /// always owns the leftover height). Loading/error/empty use a scroll-safe
  /// centered block — the state widgets never overflow the available space.
  Widget _buildSessions(AppLocalizations l10n) {
    final direct = _scope == MinigameScope.direct;
    final sessions = direct
        ? ref.watch(myMinigameSessionsProvider)
        : ref.watch(minigameSessionsProvider(_selectedGroupId!));

    return sessions.when(
      loading: () => const VLoadingView(),
      error: (error, _) => _fillState(
        ErrorView(message: l10n.minigamesErrorLoad, onRetry: _refreshSessions),
      ),
      data: (rows) {
        final pending = direct
            ? (ref.watch(myPendingInvitesProvider).valueOrNull ??
                const <Map<String, dynamic>>[])
            : const <Map<String, dynamic>>[];
        final rowIds = rows
            .map((r) => r['id'] as String?)
            .whereType<String>()
            .toSet();
        final uniquePending =
            pending.where((p) => !rowIds.contains(p['id'])).toList();
        final all = [...uniquePending, ...rows];

        if (all.isEmpty) {
          // VEmptyView resolves the themed inks itself.
          return _fillState(
            VEmptyView(
              icon: Icons.sports_esports,
              title: direct ? l10n.minigamesDirectEmpty : l10n.minigamesEmpty,
              description: direct
                  ? l10n.minigamesDirectEmptyBody
                  : l10n.minigamesEmptyBody,
            ),
          );
        }
        return ListView.separated(
          itemCount: all.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (_, i) {
            final isPending = i < uniquePending.length;
            return _SessionCard(
              session: all[i],
              isPending: isPending,
              onTap: () => _showDetail(all[i]['id'] as String),
            );
          },
        );
      },
    );
  }

  /// Centered state block that fills its available height and scrolls when
  /// the state widget is taller than it (a centered state must never
  /// overflow its box).
  Widget _fillState(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }

  /// Re-runs whichever session list is currently scoped.
  Future<void> _refreshSessions() async {
    if (_scope == MinigameScope.direct) {
      await ref.read(myMinigameSessionsProvider.notifier).refresh();
      ref.invalidate(myPendingInvitesProvider);
    } else {
      await ref
          .read(minigameSessionsProvider(_selectedGroupId!).notifier)
          .refresh();
    }
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

  (
    IconData,
    String Function(AppLocalizations),
    String Function(AppLocalizations),
  )
  get _meta => switch (type) {
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
    MinigameType.twoLiesOneTruth => (
      minigameIcon(type),
      (l) => l.minigamesGameTwoLiesOneTruth,
      (l) => l.minigamesGameTwoLiesOneTruthTagline,
    ),
    MinigameType.charades => (
      minigameIcon(type),
      (l) => l.minigamesGameCharades,
      (l) => l.minigamesGameCharadesTagline,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, name, tagline) = _meta;
    final palette = GroupThemeScope.paletteOf(context);
    final themed = !identical(palette, GroupThemeScope.standardPalette);
    // Monochrome: selection emphasis is the primary text colour vs the muted
    // step (derived from the group theme when one is in scope).
    final primary = themed ? palette.foreground : AppColors.white;
    final secondary = themed ? palette.mutedForeground : AppColors.mutedStrong;
    final accent = selected ? primary : secondary;

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
                  color: selected ? primary : secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Text(
                  tagline(l10n),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(color: secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;
  final bool isPending;

  const _SessionCard({
    required this.session,
    required this.onTap,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = GroupThemeScope.paletteOf(context);
    final themed = !identical(palette, GroupThemeScope.standardPalette);
    final muted = themed ? palette.mutedForeground : AppColors.mutedStrong;
    final status = session['status'] as String?;
    final wager = (session['shard_wager'] as num?)?.toInt() ?? 0;
    final participants = (session['participants'] as List?)?.length ?? 0;
    final positions =
        (session['prize_positions'] as num?)?.toInt() ?? kDefaultPrizePositions;
    final inviterName = session['inviterName'] as String?;
    // A GROUP row carries the group name as a tag (resolved
    // from the caller's groups); a DIRECT row shows nothing.
    final groupId = session['group_id'] as String?;
    final groupName = groupId == null
        ? null
        : ref
              .watch(myGroupsProvider)
              .valueOrNull
              ?.where((g) => g.id == groupId)
              .firstOrNull
              ?.name;

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
                    if (isPending)
                      Text(
                        inviterName != null
                            ? l10n.minigamesInviteFromDirect(inviterName)
                            : l10n.minigamesInvitePendingBody,
                        style: TextStyle(color: muted),
                      ),
                    if (isPending) const SizedBox(height: AppSpacing.xs),
                    // Pool + live player count, no
                    // "apuesta"/"shards" literals. The pool amount recomputes
                    // when a participant joins (live session row).
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
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    if (groupName != null && groupName.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.minigamesInviteFromGroup(groupName),
                        style: AppTypography.bodySmall.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              VChip(
                label: isPending
                    ? l10n.groupsInvitePending
                    : (status == 'finished'
                        ? l10n.minigamesStatusFinished
                        : l10n.minigamesStatusActive),
                selected: isPending || status != 'finished',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular group banner avatar: a complete circle, height == width, no
/// bigger than the Directa/Grupo chips. The
/// cover image renders inside a circular clip; the initials fallback keeps
/// the ring when no cover exists.
class _GroupBannerAvatar extends StatelessWidget {
  final Group group;
  final double size;

  const _GroupBannerAvatar({required this.group, required this.size});

  @override
  Widget build(BuildContext context) {
    final hasCover = group.coverUrl != null && group.coverUrl!.isNotEmpty;
    final initials = group.name.isEmpty ? null : group.name.substring(0, 1);
    final palette = GroupThemeScope.paletteOf(context);
    final themed = !identical(palette, GroupThemeScope.standardPalette);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: themed ? palette.surfaceAlt : AppColors.surfaceAlt,
        border: Border.all(color: themed ? palette.border : AppColors.border),
      ),
      padding: const EdgeInsets.all(1),
      child: ClipOval(
        child: SizedBox.expand(
          child: hasCover
              ? VNetworkImage(imageUrl: group.coverUrl!, fit: BoxFit.cover)
              : Center(
                  child: Text(
                    initials ?? '',
                    style: TextStyle(
                      fontSize: size * 0.35,
                      color: themed ? palette.foreground : AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The switch-groups icon in the scope row — a swap icon that reopens the
/// group picker, carrying the red pending-invite badge — the red circle
/// appears on the invite/request affordance.
class _SwitchGroupButton extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onPressed;
  final String tooltip;

  const _SwitchGroupButton({
    required this.pendingCount,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: Builder(
            builder: (context) {
              final p = GroupThemeScope.paletteOf(context);
              return IconButton(
                icon: const Icon(Icons.swap_horiz, size: 20),
                tooltip: tooltip,
                color: !identical(p, GroupThemeScope.standardPalette)
                    ? p.foreground
                    : AppColors.white,
                padding: EdgeInsets.zero,
                onPressed: onPressed,
              );
            },
          ),
        ),
        if (pendingCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: VCountBadge(count: pendingCount),
          ),
      ],
    );
  }
}
