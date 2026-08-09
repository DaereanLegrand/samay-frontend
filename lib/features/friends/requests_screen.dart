import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/features/friends/friends_providers.dart';
import 'package:samay/features/groups/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _acceptFriend(String id) async {
    await ref.read(friendsRepositoryProvider).acceptFriendRequest(id);
    ref.invalidate(friendRequestsProvider);
  }

  Future<void> _declineFriend(String id) async {
    await ref.read(friendsRepositoryProvider).declineFriendRequest(id);
    ref.invalidate(friendRequestsProvider);
  }

  Future<void> _acceptInvite(String membershipId) async {
    await ref.read(groupsRepositoryProvider).acceptInvite(membershipId);
    ref.invalidate(groupInvitesProvider);
  }

  Future<void> _declineInvite(String membershipId) async {
    await ref.read(groupsRepositoryProvider).declineInvite(membershipId);
    ref.invalidate(groupInvitesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friendsRequestsTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.friendsTabReceived),
            Tab(text: l10n.friendsTabSent),
            Tab(text: l10n.friendsTabInvites),
          ],
        ),
      ),
      body: ref.watch(friendRequestsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toAppError().message,
          onRetry: () => ref.invalidate(friendRequestsProvider),
        ),
        data: (data) => ref.watch(groupInvitesProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            message: e.toAppError().message,
            onRetry: () => ref.invalidate(groupInvitesProvider),
          ),
          data: (invites) {
            final received =
                data.requests.where((r) => r['type'] == 'received').toList();
            final sent = data.requests.where((r) => r['type'] == 'sent').toList();
            return TabBarView(
              controller: _tabController,
              children: [
                _buildRequests(received, data.names, isReceived: true),
                _buildRequests(sent, data.names, isReceived: false),
                _buildInvites(invites),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRequests(
    List<Map<String, dynamic>> items,
    Map<String, String> names, {
    required bool isReceived,
  }) {
    final l10n = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          isReceived ? l10n.friendsNoReceived : l10n.friendsNoSent,
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final r = items[i];
        final name = names[r['user_id'] as String] ?? l10n.commonUser;
        return ListTile(
          title: Text(name),
          subtitle: Text(
            isReceived ? l10n.friendsSentYouRequest : l10n.friendsRequestSent,
          ),
          trailing: isReceived
              ? _ActionPair(
                  onAccept: () => _acceptFriend(r['friendship_id'] as String),
                  onDecline: () => _declineFriend(r['friendship_id'] as String),
                )
              : TextButton(
                  onPressed: () => _declineFriend(r['friendship_id'] as String),
                  child: Text(l10n.commonCancel),
                ),
        );
      },
    );
  }

  Widget _buildInvites(List<Map<String, dynamic>> invites) {
    final l10n = AppLocalizations.of(context);
    if (invites.isEmpty) {
      return Center(child: Text(l10n.friendsNoInvites));
    }
    return ListView.builder(
      itemCount: invites.length,
      itemBuilder: (_, i) {
        final invite = invites[i];
        final groupName = (invite['groups'] as Map<String, dynamic>?)?['name']
                as String? ??
            l10n.commonGroup;
        return ListTile(
          title: Text(groupName),
          subtitle: Text(invite['role'] as String? ?? 'member'),
          trailing: _ActionPair(
            onAccept: () => _acceptInvite(invite['id'] as String),
            onDecline: () => _declineInvite(invite['id'] as String),
          ),
        );
      },
    );
  }
}

/// Accept/decline TextButton pair (PERF-08: the repeated trailing action row
/// of the requests and invites lists is one const sub-widget).
class _ActionPair extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _ActionPair({required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(onPressed: onAccept, child: Text(l10n.commonAccept)),
        TextButton(onPressed: onDecline, child: Text(l10n.commonReject)),
      ],
    );
  }
}
