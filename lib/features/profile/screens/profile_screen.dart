import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/page_insets.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/profile/providers/profile_providers.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final profileFuture = ref.read(myProfileProvider.notifier).refresh();
    final groupsFuture = ref.read(myGroupsProvider.notifier).refresh();
    try {
      await Future.wait([profileFuture, groupsFuture]);
    } catch (_) {
      // Failures surface through each provider's AsyncError state; the
      // RefreshIndicator must still settle.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(myProfileProvider);
    final groupsAsync = ref.watch(myGroupsProvider);
    final l10n = AppLocalizations.of(context);

    final showLoading =
        (profileAsync.isLoading && !profileAsync.hasValue) ||
        (groupsAsync.isLoading && !groupsAsync.hasValue);

    final error = !profileAsync.hasValue && profileAsync.hasError
        ? profileAsync.error!
        : !groupsAsync.hasValue && groupsAsync.hasError
        ? groupsAsync.error!
        : null;

    final profile = profileAsync.valueOrNull;
    final groups = groupsAsync.valueOrNull ?? const <Map<String, dynamic>>[];

    final displayName =
        profile?['username']?.toString() ??
        authState.valueOrNull?.user?['email'] ??
        l10n.commonUser;
    final initials = displayName
        .substring(0, displayName.length < 2 ? displayName.length : 2)
        .toUpperCase();

    return Scaffold(
      // Always-transparent pinned header (shared mechanism) with the profile
      // body scrolling beneath it. Pull-to-refresh wraps the whole scroll view.
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            VHeaderSliver(
              title: l10n.profileTitle,
              actions: [
                // The gear is icon-only — the tooltip is its accessibility
                // name for screen readers.
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: l10n.profileSettingsTitle,
                  onPressed: () => context.push(RoutePaths.settings),
                ),
              ],
            ),
            if (showLoading)
              // First load shows the shared spinner.
              const SliverToBoxAdapter(child: VLoadingView())
            else if (error != null)
              SliverToBoxAdapter(
                child: ErrorView(
                  message: error.toAppError().message,
                  onRetry: () => _refresh(ref),
                ),
              )
            else
              ..._profileSlivers(
                context,
                l10n,
                profile,
                groups,
                displayName,
                initials,
              ),
          ],
        ),
      ),
    );
  }

  /// The profile body as slivers so the group list stays lazy for a user with
  /// many groups.
  List<Widget> _profileSlivers(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>> groups,
    String displayName,
    String initials,
  ) {
    final bio = profile?['bio'] as String?;
    final horizontal = AppSpacing.screenHorizontal;
    return [
      // Cover hero: a flat `surfaceAlt` band with the avatar centered. The
      // avatar is the edit affordance (it pushes the shaped editor).
      SliverToBoxAdapter(
        child: _CoverHero(
          initials: initials,
          imageUrl: profile?['avatar_url'] as String?,
          tooltip: l10n.profileEditTitle,
          onTap: () => context.push(RoutePaths.profileEdit),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, AppSpacing.lg, horizontal, 0),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: InkWell(
                  onTap: () => context.push(RoutePaths.profileEdit),
                  child: Text(
                    displayName,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: context.palette.foreground),
                  ),
                ),
              ),
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _GroupsCountStrip(
                groupsCount: groups.length,
                groupsLabel: l10n.profileMyGroups,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.profileMyGroups.toUpperCase(),
                style: AppTypography.sectionLabel,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        sliver: groups.isEmpty
            ? SliverToBoxAdapter(
                child: VEmptyView(
                  icon: Icons.group_outlined,
                  title: l10n.profileNoGroupsYet,
                  description: l10n.profileNoGroupsHint,
                ),
              )
            : SliverList.builder(
                itemCount: groups.length,
                itemBuilder: (context, i) => _GroupTile(
                  name: groups[i]['name'] as String? ?? '',
                  showDivider: i > 0,
                ),
              ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(height: AppSpacing.xl + pageBottomInset(context)),
      ),
    ];
  }
}

/// Flat monochrome cover band with the avatar centered on it.
class _CoverHero extends StatelessWidget {
  const _CoverHero({
    required this.initials,
    required this.imageUrl,
    required this.tooltip,
    required this.onTap,
  });

  final String initials;
  final String? imageUrl;
  final String tooltip;
  final VoidCallback onTap;

  static const double _height = 180;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        border: Border(bottom: BorderSide(color: context.palette.hairline)),
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: ProfileAvatar(initials: initials, imageUrl: imageUrl),
        ),
      ),
    );
  }
}

/// The groups total as a single centered stat with hairline rules.
class _GroupsCountStrip extends StatelessWidget {
  const _GroupsCountStrip({
    required this.groupsCount,
    required this.groupsLabel,
  });

  final int groupsCount;
  final String groupsLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: context.palette.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: _StatCell(value: '$groupsCount', label: groupsLabel),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall.copyWith(
            color: context.palette.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// One profile-groups row: icon and name, hairline-separated.
class _GroupTile extends StatelessWidget {
  final String name;
  final bool showDivider;

  const _GroupTile({
    required this.name,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDivider) Divider(height: 1, color: context.palette.hairline),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.listRowVertical,
          ),
          child: Row(
            children: [
              Icon(
                Icons.group,
                size: AppIconSizes.md,
                color: context.palette.mutedForeground,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
