import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/profile/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/glass/glass.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_aurora.dart';
import 'package:samay/shared/widgets/v_refreshable.dart';
import 'package:samay/shared/widgets/v_status_dot.dart';

class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  final _searchController = TextEditingController();

  /// LUXE v2 mint ambient (ORCHESTRATION-LUXE: friends = mint family; the
  /// family's 3 anchor blobs keep the 2–3 blob geometry single-family).
  static const List<AppGradient> _aurora = [
    AppGradients.mint,
    AppGradients.mint,
    AppGradients.mint,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // U-26 (U-24 F3): an empty (non-null) username would RangeError on
  // substring — the '?' initial fallback.
  String _initials(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? '';
    return username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsTitle)),
      body: VAurora(
        gradients: _aurora,
        opacity: 0.08,
        child: Column(
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
              child: ref
                  .watch(friendsListProvider)
                  .when(
                    loading: () => const VLoadingView(),
                    error: (e, _) => ErrorView(
                      message: e.toAppError().message,
                      onRetry: () => ref.invalidate(friendsListProvider),
                    ),
                    data: (friends) {
                      // R13 (F3): pull-to-refresh on the list AND the empty
                      // states — the whole surface reloads the provider.
                      Future<void> onRefresh() =>
                          ref.read(friendsListProvider.notifier).refresh();
                      final q = _searchController.text.toLowerCase();
                      final filtered = friends
                          .where(
                            (f) =>
                                q.isEmpty ||
                                (f['username'] as String? ?? '')
                                    .toLowerCase()
                                    .contains(q),
                          )
                          .toList();
                      if (filtered.isEmpty && friends.isEmpty) {
                        return VRefreshable(
                          onRefresh: onRefresh,
                          child: VEmptyView(
                            icon: Icons.person_search,
                            title: l10n.friendsNoneYet,
                            description: l10n.friendsSearchPrompt,
                          ),
                        );
                      }
                      if (filtered.isEmpty) {
                        return VRefreshable(
                          onRefresh: onRefresh,
                          child: VEmptyView(
                            icon: Icons.search_off,
                            title: l10n.friendsNoResults,
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: onRefresh,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) {
                            final u = filtered[i];
                            return VGlassCard(
                              gradient: AppGradients.mint,
                              glowAlpha: 0.10,
                              child: ListTile(
                                leading: ProfileAvatar(
                                  size: AppSpacing.avatar,
                                  initials: _initials(u),
                                  imageUrl: u['avatar_url'] as String?,
                                ),
                                title: Text('@${u['username']}'),
                                // §5.5 presence dot + §6.3 α pulse (U-18's
                                // `VStatusDot` — the pulse is gated by reduced
                                // motion; the dot itself stays the 8px
                                // statusOnline circle U-10 restyled). Cyan is
                                // semantic (presence), not a screen accent.
                                trailing: const VStatusDot(),
                                onTap: () => context.push(
                                  RoutePaths.userProfile(u['id'] as String),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
