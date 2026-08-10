import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';

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
              loading: () => const VLoadingView(),
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
                  return VEmptyView(
                    icon: Icons.person_search,
                    title: l10n.friendsNoneYet,
                    description: l10n.friendsSearchPrompt,
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
