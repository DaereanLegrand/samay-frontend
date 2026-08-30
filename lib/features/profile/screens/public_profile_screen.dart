import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

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
      final profile = await ref
          .read(friendsRepositoryProvider)
          .getUserProfile(widget.userId);
      if (mounted) setState(() => _profile = profile?.toJson());
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
      final status = await ref
          .read(friendsRepositoryProvider)
          .sendFriendRequest(widget.userId);
      if (!mounted) return;
      if (status == 'accepted') {
        // R15 (F5): mutual-accept — the friendship is instant; the dialog
        // says so instead of the pending snackbar.
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
      // The new friend must appear in the list immediately (2026-08-14).
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
      return const Scaffold(body: VHeaderBar(child: VSkeletonProfile()));
    }

    final p = _profile;
    final username = p?['username'] as String?;
    final bio = p?['bio'] as String?;
    // U-26: the empty-string edge (U-24 F3 family) — a non-null '' would
    // RangeError on substring; '' falls back to the 'U' initial.
    final initials = (username == null || username.isEmpty)
        ? 'U'
        : username.substring(0, 1).toUpperCase();

    return Scaffold(
      body: VHeaderBar(
        actions: [
          // U-26 (4.1.2): the overflow menu is icon-only — the tooltip is
          // its accessibility name for screen readers.
          PopupMenuButton<String>(
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
              PopupMenuItem(value: 'report', child: Text(l10n.profileReport)),
            ],
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ProfileAvatar(
                initials: initials,
                imageUrl: p?['avatar_url'] as String?,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: VDisplayText(text: username ?? l10n.commonUser, size: 28),
            ),
            if (username != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '@$username',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedStrong,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                bio != null && bio.isNotEmpty ? bio : l10n.profileNoBio,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedStrong),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: _buildActionButton()),
                if (_friendshipStatus == 'accepted' &&
                    !_isBlocked &&
                    ref.isEnabled(AppFeatureFlag.chat)) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: VButton.emphasized(
                      label: l10n.profileMessage,
                      onPressed: _openChat,
                    ),
                  ),
                ],
                if (_friendshipStatus == 'pending' && _friendshipId != null)
                  const SizedBox(width: 8),
                if (_friendshipStatus == 'pending' && _friendshipId != null)
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
            ),
            const SizedBox(height: 16),
            // LUXE v2 (XL-08): the shared-groups header is the §3.3
            // sectionLabel overline voice, not a title.
            Text(
              l10n.profileSharedGroups.toUpperCase(),
              style: AppTypography.sectionLabel,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.profileNoSharedGroups,
                // §5.9 empty state: mutedStrong bodyMedium (U-09).
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedStrong),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Plugged chat entry (2026-08-13): resolves (or creates) the E2EE direct
  /// chat with this friend via `create_direct_chat` and opens the thread.
  Future<void> _openChat() async {
    try {
      final chatId = await ref
          .read(chatServiceProvider)
          .createDirectChat(widget.userId);
      if (!mounted) return;
      await context.push(RoutePaths.chat(chatId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
      }
    }
  }

  Widget _buildActionButton() {
    final l10n = AppLocalizations.of(context);
    if (_isBlocked) {
      // U-26 (U-23 F3): the status readouts (Bloqueado/Amigos/Solicitado)
      // are NOT actions — a no-op handler renders them enabled (2.1.1/
      // 4.1.2 violation); disabled drops them to `muted` per §5.1.
      return VButton.emphasized(
        label: l10n.friendsStatusBlocked,
        onPressed: null,
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
    }
  }

  /// R2: the report menu item opens the reason dialog, then submits a real
  /// report through [ModerationService.reportContent] ('user' target). No
  /// more "próximamente" snackbar — the moderation pipeline exists.
  Future<void> _reportUser() async {
    final l10n = AppLocalizations.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.profileReportTitle),
        children: [
          for (final reason in [
            l10n.profileReportReasonHarassment,
            l10n.profileReportReasonSpam,
            l10n.profileReportReasonInappropriate,
            l10n.profileReportReasonOther,
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, reason),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(reason),
              ),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    try {
      await ref
          .read(moderationServiceProvider)
          .reportContent('user', widget.userId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileReportSent)));
    } catch (e) {
      if (mounted) showAppError(context, e);
    }
  }

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
