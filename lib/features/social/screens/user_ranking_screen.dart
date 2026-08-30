import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/social/providers/social_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

/// The global USER ranking (C-social, 2026-08-18): every non-deleted user
/// ordered by `personal_shards` DESC (via `public.get_user_ranking`, the
/// SECURITY DEFINER RPC that can read the column-REVOKEd shard balance).
///
/// Censor rule: a user's name renders ONLY when `ranking.anonymize_names`
/// (app_config, read via [appConfigProvider]) is OFF or their profile is
/// public (`profile_public = true`, returned by the RPC); otherwise the
/// localized placeholder (`socialCensoredName`).
///
/// White-only: names are plain white text (no violet `VDisplayText`), the
/// podium keeps only the semantic gold/silver/bronze rank numerals.
class UserRankingScreen extends ConsumerWidget {
  const UserRankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final anonymize =
        ref.watch(appConfigProvider).valueOrNull?['ranking.anonymize_names'] ==
        'true';
    final rankingAsync = ref.watch(userRankingProvider);
    final entries = rankingAsync.valueOrNull;
    return Scaffold(
      body: VHeaderBar(
        title: l10n.socialRankingTitle,
        child: entries == null && rankingAsync.isLoading
            ? const VSkeletonList(rows: 8)
            : VStateView(
                error: rankingAsync.error,
                errorMessage: rankingAsync.hasError
                    ? rankingAsync.error!.toAppError().message
                    : null,
                onRetry: () => ref.invalidate(userRankingProvider),
                empty: VEmptyView(
                  icon: Icons.leaderboard_outlined,
                  title: l10n.socialRankingEmpty,
                ),
                child: entries == null || entries.isEmpty
                    ? null
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(userRankingProvider.notifier).refresh(),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final entry = entries[i];
                            final rank = i + 1;
                            final name = _displayName(entry, anonymize, l10n);
                            final initials = name.isEmpty
                                ? null
                                : name.substring(0, 1);
                            return ListTile(
                              dense: true,
                              leading: SizedBox(
                                width: 32,
                                child: Text(
                                  '#$rank',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: _rankColor(rank),
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              title: Text(name),
                              subtitle: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const VShardIcon(size: 12),
                                  const SizedBox(width: 4),
                                  Text('${entry.personalShards}'),
                                ],
                              ),
                              trailing: ProfileAvatar(
                                size: AppSpacing.avatar,
                                initials: initials,
                                imageUrl: entry.avatarUrl,
                              ),
                              onTap: () => context.push(
                                RoutePaths.userProfile(entry.userId),
                              ),
                            );
                          },
                        ),
                      ),
              ),
      ),
    );
  }

  /// The censor rule: the real username only when anonymization is OFF or
  /// the profile is public; otherwise the neutral placeholder.
  String _displayName(
    UserRankingEntry entry,
    bool anonymize,
    AppLocalizations l10n,
  ) {
    if (anonymize && !entry.profilePublic) return l10n.socialCensoredName;
    return entry.username.isEmpty ? l10n.socialCensoredName : entry.username;
  }

  /// Semantic podium numerals (gold/silver/bronze) — these are the RANK
  /// colors the product asked to KEEP; everything else stays white.
  Color? _rankColor(int rank) {
    return switch (rank) {
      1 => AppColors.discoGold,
      2 => AppColors.discoSilver,
      3 => AppColors.discoBronze,
      _ => AppColors.white,
    };
  }
}
