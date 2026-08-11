import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/features/groups/widgets/member_actions_sheet.dart';
import 'package:samay/features/profile/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';

class GroupMembersScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupMembersScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends ConsumerState<GroupMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final members = await ref
          .read(groupsRepositoryProvider)
          .getGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() => _members = members.map((m) => m.toJson()).toList());
    } catch (e, st) {
      AppLogger.instance.error('GroupMembersScreen._load error: $e', st.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// R17 (F9 ADAPTED): rows are admin-gated — the current user's own
  /// membership row carries their role; `promotor`/`co_promotor` can act on
  /// everyone except themselves and the owner.
  bool _canAct(String myRole, String targetUserId, String targetRole) =>
      (myRole == 'promotor' || myRole == 'co_promotor') &&
      targetUserId != ref.read(authServiceProvider).auth.currentUser?.id &&
      targetRole != 'promotor';

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
        : _members
            .where((m) => m['user_id'] == myId)
            .firstOrNull;
    final myRole = myRow?['role'] as String? ?? 'member';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupsMembersTitle)),
      body: _loading
          ? const VLoadingView()
          : _members.isEmpty
              ? VEmptyView(
                  icon: Icons.people_outline,
                  title: l10n.groupsNoMembers,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = _members[index];
                    final user = m['users'] as Map<String, dynamic>?;
                    final rawUsername = user?['username'] as String?;
                    final userId = m['user_id']?.toString() ?? '';
                    final username = (rawUsername == null || rawUsername.isEmpty)
                        ? (userId.isEmpty
                            ? l10n.commonUser
                            : userId.substring(0, userId.length < 8 ? userId.length : 8))
                        : rawUsername;
                    final initials = username.substring(0, 1).toUpperCase();
                    final role = m['role'] as String? ?? 'member';
                    final tappable = _canAct(myRole, userId, role);
                    return ListTile(
                      dense: true,
                      leading: ProfileAvatar(
                        size: AppSpacing.avatar,
                        initials: initials,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(username, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          VBadge(label: role),
                        ],
                      ),
                      trailing: tappable
                          ? const Icon(Icons.more_horiz, size: 20)
                          : null,
                      onTap: tappable ? () => _openActions(m) : null,
                    );
                  },
                ),
    );
  }
}
