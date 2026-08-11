import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/features/profile/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _friendshipStatus;
  String? _friendshipId;
  bool _isIncoming = false;
  bool _isBlocked = false;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile =
          await ref.read(friendsRepositoryProvider).getUserProfile(widget.userId);
      if (mounted) setState(() => _profile = profile?.toJson());
    } catch (e, st) {
      AppLogger.instance.error('loadPublicProfile error: $e', '$st');
    }

    try {
      final detail = await ref
          .read(friendsRepositoryProvider)
          .getFriendshipDetail(widget.userId);
      if (mounted) {
        final currentUserId =
            ref.read(authServiceProvider).auth.currentUser?.id;
        setState(() {
          _friendshipStatus = detail?['status'] as String?;
          _friendshipId = detail?['id'] as String?;
          _isIncoming = detail != null && detail['requester_id'] != currentUserId;
        });
      }
    } catch (e, st) {
      AppLogger.instance.error('loadFriendshipDetail error: $e', '$st');
    }

    try {
      final blocked = await ref
          .read(friendsRepositoryProvider)
          .getBlockStatus(widget.userId);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (e, st) {
      AppLogger.instance.error('loadBlockStatus error: $e', '$st');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendRequest() async {
    if (_sending) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      final status =
          await ref.read(friendsRepositoryProvider).sendFriendRequest(widget.userId);
      if (!mounted) return;
      if (status == 'accepted') {
        // R15 (F5): mutual-accept — the friendship is instant; the dialog
        // says so instead of the pending snackbar.
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l10n.friendsMutualAcceptedTitle),
            content: Text(l10n.friendsMutualAcceptedBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileFriendRequestSent)),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toAppError().message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _acceptRequest() async {
    if (_friendshipId == null || _sending) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(friendsRepositoryProvider)
          .acceptFriendRequest(_friendshipId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileRequestAccepted)),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileAcceptError)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profileTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final p = _profile;
    final username = p?['username'] as String?;
    final bio = p?['bio'] as String?;
    final initials = (username ?? 'U').substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(username != null ? '@$username' : l10n.profileTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (_) => [
              if (_isBlocked)
                PopupMenuItem(value: 'unblock', child: Text(l10n.friendsUnblock))
              else
                PopupMenuItem(value: 'block', child: Text(l10n.profileBlock)),
              PopupMenuItem(value: 'report', child: Text(l10n.profileReport)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ProfileAvatar(initials: initials),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              username ?? l10n.commonUser,
              // §3.2 fancy moment (U-09): mirrors the own-profile header —
              // Playfair italic 28 with the glow-soft stack.
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          if (username != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                '@$username',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.mutedStrong),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Text(
              bio != null && bio.isNotEmpty ? bio : l10n.profileNoBio,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedStrong),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildActionButton()),
              if (_friendshipStatus == 'pending' && _friendshipId != null)
                const SizedBox(width: 8),
              if (_friendshipStatus == 'pending' && _friendshipId != null)
                Expanded(
                  child: VButton(
                    label: _isIncoming ? l10n.commonReject : l10n.profileCancelRequest,
                    onPressed: () async {
                      await ref
                          .read(friendsRepositoryProvider)
                          .declineFriendRequest(_friendshipId!);
                      _load();
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.profileSharedGroups,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.profileNoSharedGroups,
              // §5.9 empty state: mutedStrong bodyMedium (U-09).
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedStrong),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final l10n = AppLocalizations.of(context);
    if (_isBlocked) {
      return VButton.emphasized(label: l10n.friendsStatusBlocked, onPressed: () {});
    }
    if (_friendshipStatus == 'accepted') {
      return VButton.emphasized(label: l10n.friendsStatusAccepted, onPressed: () {});
    }
    if (_friendshipStatus == 'pending' && _friendshipId != null) {
      if (_isIncoming) {
        return VButton.emphasized(
          label: _sending ? l10n.profileAccepting : l10n.profileAcceptRequest,
          onPressed: _acceptRequest,
        );
      } else {
        return VButton.emphasized(
          label: l10n.friendsStatusPending,
          onPressed: () {},
        );
      }
    }
    return VButton.glowAccent(
      filled: true,
      label: _sending ? l10n.profileSending : l10n.profileAddFriend,
      onPressed: _sendRequest,
    );
  }

  void _handleMenuAction(String action) {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'block':
        _blockUser();
      case 'unblock':
        _unblockUser();
      case 'report':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileReportComingSoon)),
        );
    }
  }

  Future<void> _blockUser() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(friendsRepositoryProvider).blockUser(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUserBlocked)),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileBlockError)),
        );
      }
    }
  }

  Future<void> _unblockUser() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(friendsRepositoryProvider).unblockUser(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUserUnblocked)),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUnblockError)),
        );
      }
    }
  }
}
