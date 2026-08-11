import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/profile/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_refreshable.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  // U-26 (U-24 F3): an empty (non-null) username would RangeError on
  // substring — the '?' initial fallback.
  String _initials(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? '';
    return username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blockedAsync = ref.watch(blockedUsersProvider);
    final blocked = blockedAsync.valueOrNull;
    // R13 (F3): pull-to-refresh reloads the blocked list — the empty state
    // stays refreshable too (VRefreshable).
    Future<void> onRefresh() =>
        ref.read(blockedUsersProvider.notifier).refresh();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsBlockedTitle)),
      body: VStateView(
        loading: blockedAsync.isLoading,
        error: blockedAsync.error,
        errorMessage: blockedAsync.hasError
            ? blockedAsync.error!.toAppError().message
            : null,
        onRetry: onRefresh,
        empty: VRefreshable(
          onRefresh: onRefresh,
          child: VEmptyView(icon: Icons.block, title: l10n.friendsNoneBlocked),
        ),
        child: blocked == null || blocked.isEmpty
            ? null
            : RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: blocked.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = blocked[i];
                    return ListTile(
                      leading: ProfileAvatar(
                        size: AppSpacing.avatar,
                        initials: _initials(u),
                        imageUrl: u['avatar_url'] as String?,
                      ),
                      title: Text('@${u['username']}'),
                      trailing: TextButton(
                        onPressed: () async {
                          await ref
                              .read(friendsRepositoryProvider)
                              .unblockUser(u['id'] as String);
                          ref.invalidate(blockedUsersProvider);
                        },
                        child: Text(l10n.friendsUnblock),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
