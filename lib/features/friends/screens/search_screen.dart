import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/utils/debouncer.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/shared/constants/auth_constants.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  String _query = '';

  @override
  void dispose() {
    _debouncer.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    final config = ref.read(appConfigProvider).valueOrNull;
    final debounceMs =
        int.tryParse(config?['app.search_debounce_ms'] ?? '') ?? 300;
    _debouncer.delay = Duration(milliseconds: debounceMs);
    _debouncer.run(() {
      if (mounted) {
        setState(() {
          _query = InputSanitizer.sanitize(
            query,
            maxLength: InputSanitizer.searchQueryMaxLength,
          );
        });
      }
    });
  }

  // U-26 (U-24 F3): an empty (non-null) username would RangeError on
  // substring — the '?' initial fallback.
  String _initials(UserSearchResult user) {
    final username = user.username;
    return username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();
  }

  Future<void> _sendFriendRequest(UserSearchResult user) async {
    final userId = user.id;
    final l10n = AppLocalizations.of(context);
    try {
      final status = await ref
          .read(friendsRepositoryProvider)
          .sendFriendRequest(userId);
      if (!mounted) return;
      if (status == 'accepted') {
        // R15 (F5): mutual-accept — the addressee had already sent us a
        // request, so the friendship is instant; the dialog says so.
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
        ).showSnackBar(SnackBar(content: Text(l10n.friendsRequestSent)));
      }
      ref.invalidate(searchResultsProvider(_query));
    } catch (e, st) {
      AppLogger.instance.error('sendFriendRequest error: $e', '$st');
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  /// ISSUE 5: accepts an INBOUND pending request straight from the search
  /// row (the enriched result carries the friendship id) and refreshes every
  /// friendship surface, mirroring `_sendFriendRequest`'s error pattern.
  Future<void> _acceptFriendRequest(UserSearchResult user) async {
    final friendshipId = user.friendshipId!;
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(friendsRepositoryProvider)
          .acceptFriendRequest(friendshipId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileRequestAccepted)));
      ref.invalidate(searchResultsProvider(_query));
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(friendsListProvider);
    } catch (e, st) {
      AppLogger.instance.error('acceptFriendRequest error: $e', '$st');
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsSearchUsers)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              // R14 (F6): Juega autofocuses the search field — the keyboard
              // is up the moment the screen opens.
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.friendsSearchPlaceholder,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (query.length < usernameMinLength)
            // R14 (F6): mirror the invite screen's min-chars hint — a
            // sub-2-char query has no results to show, so the field says
            // why instead of rendering an empty surface.
            Expanded(
              child: Center(
                child: Text(
                  l10n.friendsMinCharsHint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            Expanded(
              child: ref
                  .watch(searchResultsProvider(query))
                  .when(
                    loading: () => const VLoadingView(),
                    error: (e, _) => ErrorView(
                      message: e.toAppError().message,
                      onRetry: () =>
                          ref.invalidate(searchResultsProvider(query)),
                    ),
                    data: (results) {
                      if (results.isEmpty) {
                        return VEmptyView(
                          icon: Icons.person_search,
                          title: l10n.friendsNoUsersFound,
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        itemCount: results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final u = results[i];
                          return VCard(
                            child: Material(
                              type: MaterialType.transparency,
                              child: ListTile(
                                leading: ProfileAvatar(
                                  size: AppSpacing.avatar,
                                  initials: _initials(u),
                                  imageUrl: u.avatarUrl,
                                ),
                                title: Text('@${u.username}'),
                                onTap: () => context.push(
                                  RoutePaths.userProfile(u.id),
                                ),
                                trailing: _buildButton(u),
                              ),
                            ),
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

  Widget _buildButton(UserSearchResult user) {
    final l10n = AppLocalizations.of(context);
    final status = user.friendshipStatus;
    if (status == 'accepted') {
      return TextButton(
        onPressed: null,
        child: Text(l10n.friendsStatusAccepted),
      );
    }
    if (status == 'pending') {
      // ISSUE 5: an INBOUND pending request accepts right from the row;
      // outbound (sent) — or a directionless legacy row — keeps the static
      // status badge.
      if (user.friendshipDirection == 'received') {
        return SizedBox(
          width: 104,
          child: VButton.outlined(
            label: l10n.commonAccept,
            gradient: AppGradients.mint,
            onPressed: () => _acceptFriendRequest(user),
          ),
        );
      }
      // LUXE v2: the pending readout is the row's mint accent (status badge).
      return VBadge.accent(
        label: l10n.friendsStatusPending,
        gradient: AppGradients.mint,
      );
    }
    if (status == 'blocked') {
      return TextButton(
        onPressed: null,
        child: Text(l10n.friendsStatusBlocked),
      );
    }
    return SizedBox(
      width: 104,
      child: VButton.outlined(
        label: l10n.friendsAddFriendButton,
        gradient: AppGradients.mint,
        onPressed: () => _sendFriendRequest(user),
      ),
    );
  }
}
