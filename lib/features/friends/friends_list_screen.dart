import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/friends/friends_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';

class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.friendsSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ref.watch(friendsListProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toAppError().message,
                onRetry: () => ref.invalidate(friendsListProvider),
              ),
              data: (friends) {
                final q = _searchController.text.toLowerCase();
                final filtered = friends
                    .where((f) =>
                        q.isEmpty ||
                        (f['username'] as String? ?? '').toLowerCase().contains(q))
                    .toList();
                if (filtered.isEmpty && friends.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.friendsNoneYet,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(l10n.friendsSearchPrompt,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return Center(child: Text(l10n.friendsNoResults));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          (u['username'] as String? ?? '?').substring(0, 1).toUpperCase(),
                        ),
                      ),
                      title: Text('@${u['username']}'),
                      subtitle: Text('@${u['username']}'),
                      trailing: const Icon(Icons.circle, size: 8, color: Colors.green),
                      onTap: () => context.push(RoutePaths.userProfile(u['id'] as String)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
