import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// The admin member-actions bottom sheet.
///
/// Opens a glass sheet (a liquid-radius `VGlass` slab with the violet family
/// ring + glow inside the modal's black chrome) with role-fitting options for
/// the target member:
///
/// * `member` → promote to staff, kick.
/// * `staff` → demote to member, kick.
/// * `host` (owner) → no options (callers do not open the sheet).
///
/// Kick is confirmed through a dialog first (danger reads better in a
/// dialog). Every action resolves through the existing `GroupsRepository`
/// member RPCs (`kickMember` / `setMemberRole`); failures surface as a
/// transient snackbar. After a successful action [onChanged] is called
/// so the caller reloads its member data.
Future<void> showMemberActionsSheet(
  BuildContext context, {
  required WidgetRef ref,
  required String groupId,
  required Map<String, dynamic> member,
  VoidCallback? onChanged,
}) {
  final l10n = AppLocalizations.of(context);
  final user = member['users'] as Map<String, dynamic>?;
  final username =
      user?['username'] as String? ?? '${member['user_id']}'.substring(0, 8);
  final avatarUrl = user?['avatar_url'] as String?;
  final userId = member['user_id'] as String;
  final role = member['role'] as String? ?? 'member';

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.background,
    // Sharp: the sheet itself carries no radius — the glass slab inside
    // owns the liquid corners.
    shape: const RoundedRectangleBorder(),
    builder: (sheetContext) => SafeArea(
      child: Container(
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.hairline),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: ProfileAvatar(
                  size: AppSpacing.avatar,
                  initials: username.substring(0, 1).toUpperCase(),
                  imageUrl: avatarUrl,
                ),
                title: Text(username),
                subtitle: Text(
                  role.toUpperCase(),
                  style: AppTypography.labelMedium.copyWith(
                    color: context.palette.mutedForeground,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            if (role == 'member')
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  leading: const Icon(Icons.arrow_upward, size: 20),
                  title: Text(l10n.groupsPromoteStaff),
                  onTap: () => _runRoleChange(
                    sheetContext,
                    ref: ref,
                    groupId: groupId,
                    userId: userId,
                    role: 'staff',
                    onChanged: onChanged,
                  ),
                ),
              )
            else
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  leading: const Icon(Icons.arrow_downward, size: 20),
                  title: Text(l10n.groupsDemoteMember),
                  onTap: () => _runRoleChange(
                    sheetContext,
                    ref: ref,
                    groupId: groupId,
                    userId: userId,
                    role: 'member',
                    onChanged: onChanged,
                  ),
                ),
              ),
            const Divider(height: 1),
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: const Icon(
                  Icons.person_remove_outlined,
                  size: 20,
                  color: AppColors.error,
                ),
                title: Text(
                  l10n.groupsKickMember,
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () => _kickMember(
                  sheetContext,
                  ref,
                  groupId,
                  userId,
                  username,
                  onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _runRoleChange(
  BuildContext sheetContext, {
  required WidgetRef ref,
  required String groupId,
  required String userId,
  required String role,
  VoidCallback? onChanged,
}) async {
  try {
    await ref
        .read(groupsRepositoryProvider)
        .setMemberRole(groupId, userId, role);
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    onChanged?.call();
  } catch (e, st) {
    AppLogger.instance.error('setMemberRole error: $e', '$st');
    if (sheetContext.mounted) showErrorSnackBar(sheetContext, e);
  }
}

Future<void> _kickMember(
  BuildContext sheetContext,
  WidgetRef ref,
  String groupId,
  String userId,
  String username,
  VoidCallback? onChanged,
) async {
  final l10n = AppLocalizations.of(sheetContext);
  final confirmed = await showDialog<bool>(
    context: sheetContext,
    builder: (_) => AlertDialog(
      title: Text(l10n.groupsKickConfirmTitle(username)),
      content: Text(l10n.groupsKickConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(sheetContext, false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(sheetContext, true),
          child: Text(
            l10n.groupsKick,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !sheetContext.mounted) return;
  try {
    await ref.read(groupsRepositoryProvider).kickMember(groupId, userId);
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    onChanged?.call();
  } catch (e, st) {
    AppLogger.instance.error('kickMember error: $e', '$st');
    if (sheetContext.mounted) showErrorSnackBar(sheetContext, e);
  }
}
