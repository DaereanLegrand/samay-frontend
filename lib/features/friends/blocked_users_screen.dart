import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/features/friends/friends_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsBlockedTitle)),
      body: ref.watch(blockedUsersProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toAppError().message,
          onRetry: () => ref.invalidate(blockedUsersProvider),
        ),
        data: (blocked) {
          if (blocked.isEmpty) {
            return Center(
              child: Text(l10n.friendsNoneBlocked,
                  style: Theme.of(context).textTheme.bodyMedium),
            );
          }
          return ListView.builder(
            itemCount: blocked.length,
            itemBuilder: (_, i) {
              final u = blocked[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    (u['username'] as String? ?? '?').substring(0, 1).toUpperCase(),
                  ),
                ),
                title: Text('@${u['username']}'),
                subtitle: Text('@${u['username']}'),
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
          );
        },
      ),
    );
  }
}
