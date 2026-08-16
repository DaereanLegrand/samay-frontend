import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Remote-side freshness for the groups surface (2026-08-17): group
/// invitations land without an app restart.
///
/// Lives for as long as the shell is mounted: subscribes to the current
/// user's `group_members` realtime stream and invalidates
/// [groupInvitesProvider] + [myGroupsProvider] on ANY row event that touches
/// them (insert/update/delete — the invitee's invites list updates without a
/// close/reopen). `pendingCountsProvider` derives from the invites provider,
/// so the shell badge follows automatically.
///
/// Every delivered event (any user_id) also invalidates the affected group's
/// [groupMembersProvider] — an ACTIVE member receives rows for ALL members of
/// their groups (RLS `group_members_read_same`), so a co-member accept/kick/
/// join refreshes the members tab of any open group-detail screen live, with
/// no pull-to-refresh (USER FIX 1, 2026-08-17).
///
/// Re-subscribes when the authenticated user changes. Failures are logged,
/// never silent (best-effort: pull-to-refresh remains the fallback).
class GroupMembershipsRealtimeListener extends ConsumerStatefulWidget {
  const GroupMembershipsRealtimeListener({super.key});

  @override
  ConsumerState<GroupMembershipsRealtimeListener> createState() =>
      _GroupMembershipsRealtimeListenerState();
}

class _GroupMembershipsRealtimeListenerState
    extends ConsumerState<GroupMembershipsRealtimeListener> {
  RealtimeChannel? _channel;
  String? _subscribedUid;

  @override
  void initState() {
    super.initState();
    // Late subscription: the auth state may not be resolved on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  Widget build(BuildContext context) {
    // Re-sync whenever the auth state changes (sign-in/sign-out/restore) —
    // a post-frame probe alone misses the late-resolving provider.
    ref.listen(authStateProvider, (_, _) => _sync());
    return const SizedBox.shrink();
  }

  void _sync() {
    final uid = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (uid == _subscribedUid) return;
    _unsubscribe();
    if (uid == null) {
      // Signed out — nothing to subscribe to.
      _subscribedUid = null;
      return;
    }
    _subscribedUid = uid;
    _subscribe(uid);
  }

  Future<void> _subscribe(String uid) async {
    try {
      final channel = await ref
          .read(realtimeServiceProvider)
          .subscribeToGroupMemberships((row) {
            // Any membership change in a group the viewer belongs to refreshes
            // that group's members tab live (co-member accepts/kicks/joins).
            final gid = row['group_id'];
            if (gid is String && gid.isNotEmpty) {
              ref.invalidate(groupMembersProvider(gid));
            }
            if (row['user_id'] != uid) return;
            ref.invalidate(groupInvitesProvider);
            ref.invalidate(myGroupsProvider);
          });
      if (!mounted || _subscribedUid != uid) {
        // The user changed while subscribing — drop the stale channel.
        await channel.unsubscribe();
        return;
      }
      _channel = channel;
    } catch (e, st) {
      AppLogger.instance.error(
        'group memberships realtime subscribe failed: $e',
        '$st',
      );
    }
  }

  void _unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
