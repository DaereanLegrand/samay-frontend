import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/report_sheet.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

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
  bool _blockedMe = false;
  bool _isMuted = false;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ref
          .read(friendsRepositoryProvider)
          .getUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _profile = profile?.toJson();
          _isBlocked = profile?.toJson()['blocked_by_me'] == true;
          _blockedMe = profile?.toJson()['blocked_me'] == true;
        });
      }
    } catch (e, st) {
      AppLogger.instance.error('loadPublicProfile error: $e', '$st');
    }

    try {
      final detail = await ref
          .read(friendsRepositoryProvider)
          .getFriendshipDetail(widget.userId);
      if (mounted) {
        final currentUserId = ref
            .read(authServiceProvider)
            .auth
            .currentUser
            ?.id;
        setState(() {
          _friendshipStatus = detail?['status'] as String?;
          _friendshipId = detail?['id'] as String?;
          _isIncoming =
              detail != null && detail['requester_id'] != currentUserId;
        });
      }
    } catch (e, st) {
      AppLogger.instance.error('loadFriendshipDetail error: $e', '$st');
    }

    try {
      final muted = await ref.read(friendshipServiceProvider).getMutedUsers();
      final isMuted = muted.any((row) => row['id'] == widget.userId);
      if (mounted) setState(() => _isMuted = isMuted);
    } catch (e, st) {
      AppLogger.instance.error('loadMuteStatus error: $e', '$st');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendRequest() async {
    if (_sending) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      final status = await ref
          .read(friendsRepositoryProvider)
          .sendFriendRequest(widget.userId);
      if (!mounted) return;
      if (status == 'accepted') {
        // Mutual-accept: the friendship is instant; the dialog says so
        // instead of the pending snackbar.
        ref.invalidate(friendsListProvider);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileFriendRequestSent)));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
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
      // The new friend must appear in the list immediately.
      ref.invalidate(friendsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileRequestAccepted)));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileAcceptError)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: VHeaderBar(child: VLoadingView()));
    }

    final p = _profile;
    final username = p?['username'] as String?;
    final bio = p?['bio'] as String?;
    // The empty-string edge — a non-null '' would RangeError on substring;
    // '' falls back to the 'U' initial.
    final initials = (username == null || username.isEmpty)
        ? 'U'
        : username.substring(0, 1).toUpperCase();

    return Scaffold(
      body: VHeaderBar(
        title: username ?? l10n.commonUser,
        actions: [
          // The overflow menu is icon-only — the tooltip is its accessibility
          // name for screen readers. The blocked side sees no interactions.
          if (!_blockedMe) PopupMenuButton<String>(
            tooltip: l10n.commonMoreOptions,
            onSelected: _handleMenuAction,
            itemBuilder: (_) => [
              if (_isBlocked)
                PopupMenuItem(
                  value: 'unblock',
                  child: Text(l10n.friendsUnblock),
                )
              else
                PopupMenuItem(value: 'block', child: Text(l10n.profileBlock)),
              if (_isMuted)
                PopupMenuItem(value: 'unmute', child: Text(l10n.profileUnmute))
              else
                PopupMenuItem(value: 'mute', child: Text(l10n.profileMute)),
              PopupMenuItem(value: 'report', child: Text(l10n.profileReport)),
              if (p?['avatar_url'] != null)
                PopupMenuItem(
                  value: 'report_avatar',
                  child: Text(l10n.reportAvatar),
                ),
            ],
          ),
        ],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Cover hero: a flat band with the avatar centered, then the
            // identity + bio beneath it.
            _ProfileHero(
              initials: initials,
              imageUrl: p?['avatar_url'] as String?,
              displayName: username ?? l10n.commonUser,
              handle: username,
              bio: bio,
              noBio: l10n.profileNoBio,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.xl,
                AppSpacing.screenHorizontal,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildActionButton()),
                      if (_friendshipStatus == 'accepted' &&
                          !_isBlocked &&
                          ref.isEnabled(AppFeatureFlag.chat)) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: VButton(
                            label: l10n.profileMessage,
                            onPressed: _openChat,
                          ),
                        ),
                      ],
                      if (_friendshipStatus == 'pending' &&
                          _friendshipId != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: VButton(
                            label: _isIncoming
                                ? l10n.commonReject
                                : l10n.profileCancelRequest,
                            onPressed: () async {
                              await ref
                                  .read(friendsRepositoryProvider)
                                  .declineFriendRequest(_friendshipId!);
                              _load();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.profileSharedGroups.toUpperCase(),
                    style: AppTypography.sectionLabel,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.profileNoSharedGroups,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resolves (or creates) the E2EE direct chat with this friend via
  /// `create_direct_chat` and opens the thread.
  Future<void> _openChat() async {
    try {
      final chatId = await ref
          .read(chatServiceProvider)
          .createDirectChat(widget.userId);
      if (!mounted) return;
      await context.push(RoutePaths.chat(chatId));
    } catch (e) {
      if (!mounted) return;
      final blocked = e is ConflictError && e.code == 'blocked';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked
                ? AppLocalizations.of(context).profileChatUnavailable
                : e.toAppError().message,
          ),
        ),
      );
    }
  }

  Widget _buildActionButton() {
    final l10n = AppLocalizations.of(context);
    if (_blockedMe) {
      // Shadow block: the blocked side gets a minimal profile and no actions.
      return const SizedBox.shrink();
    }
    if (_isBlocked) {
      // The blocker sees the full profile plus the unblock prompt.
      return VButton.emphasized(
        label: l10n.profileBlockedUnblockPrompt,
        onPressed: () => _handleMenuAction('unblock'),
      );
    }
    if (_friendshipStatus == 'accepted') {
      return VButton.emphasized(
        label: l10n.friendsStatusAccepted,
        onPressed: null,
      );
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
          onPressed: null,
        );
      }
    }
    return VButton.dark(
      label: _sending ? l10n.profileSending : l10n.profileAddFriend,
      onPressed: _sendRequest,
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'block':
        _blockUser();
      case 'unblock':
        _unblockUser();
      case 'report':
        _reportUser();
      case 'report_avatar':
        showReportSheet(
          context,
          ref,
          targetType: 'avatar',
          targetId: widget.userId,
          title: AppLocalizations.of(context).reportAvatar,
        );
      case 'mute':
        _setMuted(true);
      case 'unmute':
        _setMuted(false);
    }
  }

  Future<void> _setMuted(bool muted) async {
    final l10n = AppLocalizations.of(context);
    try {
      final service = ref.read(friendshipServiceProvider);
      if (muted) {
        await service.muteUser(widget.userId);
      } else {
        await service.unmuteUser(widget.userId);
      }
      if (muted) ref.invalidate(mutedUsersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(muted ? l10n.profileUserMuted : l10n.friendsUnmute),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileMuteError)));
    }
  }

  /// Reports the user profile through the shared category sheet.
  Future<void> _reportUser() => showReportSheet(
    context,
    ref,
    targetType: 'user',
    targetId: widget.userId,
    title: AppLocalizations.of(context).profileReportTitle,
  );

  Future<void> _blockUser() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(friendsRepositoryProvider).blockUser(widget.userId);
      // Blocking removes the friendship — the list must drop them.
      ref.invalidate(friendsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileUserBlocked)));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileBlockError)));
      }
    }
  }

  Future<void> _unblockUser() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(friendsRepositoryProvider).unblockUser(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileUserUnblocked)));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileUnblockError)));
      }
    }
  }
}

/// Flat monochrome cover band with the avatar centered, followed by the
/// display name, handle and bio.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.initials,
    required this.imageUrl,
    required this.displayName,
    required this.handle,
    required this.bio,
    required this.noBio,
  });

  final String initials;
  final String? imageUrl;
  final String displayName;
  final String? handle;
  final String? bio;
  final String noBio;

  static const double _coverHeight = 180;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: _coverHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.palette.surfaceAlt,
            border: Border(bottom: BorderSide(color: context.palette.hairline)),
          ),
          child: ProfileAvatar(initials: initials, imageUrl: imageUrl),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            0,
          ),
          child: Column(
            children: [
              VDisplayText(text: displayName, size: 28),
              if (handle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '@$handle',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                bio != null && bio!.isNotEmpty ? bio! : noBio,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.palette.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
