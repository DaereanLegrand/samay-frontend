import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/theme/group_theme_colors.dart';
import 'package:samay/features/groups/theme/group_theme_scope.dart';
import 'package:samay/features/groups/widgets/member_actions_sheet.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

class GroupMembersScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupMembersScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends ConsumerState<GroupMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await ref
          .read(groupsRepositoryProvider)
          .getGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() => _members = members.map((m) => m.toJson()).toList());
    } catch (e, st) {
      AppLogger.instance.error(
        'GroupMembersScreen._load error: $e',
        st.toString(),
      );
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Rows are admin-gated — the current user's own
  /// membership row carries their role; `host`/`staff` can act on
  /// everyone except themselves and the owner.
  bool _canAct(String myRole, String targetUserId, String targetRole) =>
      (myRole == 'host' || myRole == 'staff') &&
      targetUserId != ref.read(authServiceProvider).auth.currentUser?.id &&
      targetRole != 'host';

  Future<void> _openActions(Map<String, dynamic> member) =>
      showMemberActionsSheet(
        context,
        ref: ref,
        groupId: widget.groupId,
        member: member,
        onChanged: _load,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.read(authServiceProvider).auth.currentUser?.id;
    final myRow = myId == null
        ? null
        : _members.where((m) => m['user_id'] == myId).firstOrNull;
    final myRole = myRow?['role'] as String? ?? 'member';
    final error = _error;
    final theme = ref.watch(groupThemeProvider(widget.groupId)).valueOrNull;
    final palette = theme == null ? null : groupThemePaletteOf(theme);
    final body = VHeaderBar(
        title: l10n.groupsMembersTitle,
        child: VStateView(
          loading: _loading,
          error: error,
          errorMessage: error?.toAppError().localize(l10n),
          onRetry: _load,
          empty: VEmptyView(
            icon: Icons.people_outline,
            title: l10n.groupsNoMembers,
          ),
          child: _members.isEmpty
              ? null
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: palette?.hairline ?? AppColors.hairline,
                  ),
                  itemBuilder: (context, index) {
                    final m = _members[index];
                    final user = m['users'] as Map<String, dynamic>?;
                    final rawUsername = user?['username'] as String?;
                    final userId = m['user_id']?.toString() ?? '';
                    final username =
                        (rawUsername == null || rawUsername.isEmpty)
                        ? (userId.isEmpty
                              ? l10n.commonUser
                              : userId.substring(
                                  0,
                                  userId.length < 8 ? userId.length : 8,
                                ))
                        : rawUsername;
                    final initials = username.substring(0, 1).toUpperCase();
                    final role = m['role'] as String? ?? 'member';
                    final roleLabel = switch (role) {
                      'host' => l10n.groupsRoleHost,
                      'staff' => l10n.groupsRoleStaff,
                      _ => l10n.groupsRoleMember,
                    };
                    final tappable = _canAct(myRole, userId, role);
                    // The row itself is the navigation affordance — every
                    // member tile opens the member's public profile. The
                    // trailing ellipsis (admin rows only) opens the manage sheet.
                    return ListTile(
                      dense: true,
                      leading: ProfileAvatar(
                        size: AppSpacing.avatar,
                        initials: initials,
                        imageUrl: user?['avatar_url'] as String?,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color:
                                        palette?.foreground ??
                                        AppColors.white,
                                  ),
                            ),
                          ),
                          VBadge(label: roleLabel),
                        ],
                      ),
                      trailing: tappable
                          ? IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.more_horiz, size: 20),
                              tooltip: l10n.commonMoreOptions,
                              onPressed: () => _openActions(m),
                            )
                          : null,
                      onTap: () => context.push(RoutePaths.userProfile(userId)),
                    );
                  },
                ),
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
}
