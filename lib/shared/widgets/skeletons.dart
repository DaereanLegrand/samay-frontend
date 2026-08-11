import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/shared/widgets/v_shimmer.dart';

/// Skeleton screen primitives (DISCO-DESIGN-SYSTEM.md §5.8/§6.3, owned by
/// U-22 — U-06's `VShimmer`/`VShimmerBox` are the primitives this composes).
///
/// Every skeleton is a **const-constructible** `VShimmer` composition of
/// `surfaceAlt #111111` blocks with sharp corners (§4.2) and hairline
/// `#1A1A1A` separators/borders matching the real screens' rows and cards.
/// No color — gray only (§5.8). `VShimmer` gates the sweep on
/// `MediaQuery.disableAnimationsOf` (§7.5): under reduced motion the blocks
/// render static with zero tickers.
///
/// The avatar skeleton is a **circle** (the one deliberate shape exception —
/// the real `ProfileAvatar` is circular, so a square block would read as a
/// layout bug; §4.2's "sharp corners" governs blocks, and the doc's §5.8
/// "blocks, sharp corners" line lists no ban on a circular avatar mimic).
class VSkeletonList extends StatelessWidget {
  /// Number of skeleton rows.
  final int rows;

  /// Horizontal padding of the rows (defaults to the screens' page padding).
  final EdgeInsetsGeometry padding;

  const VSkeletonList({
    super.key,
    this.rows = 6,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenHorizontal,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return VShimmer(
      // Scroll-safe: the placeholder is taller than small viewports, so the
      // rows live in a non-scrollable SingleChildScrollView — full layout
      // (deterministic row counts), overflow clipped, no RenderFlex errors
      // (U-19's zero-overflow rule applies to loading states too).
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.hairline,
                ),
              Padding(
                padding: padding,
                child: const Row(
                  children: [
                    _AvatarBlock(),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VShimmerBox(width: 160, height: 16),
                          SizedBox(height: AppSpacing.sm),
                          VShimmerBox(width: 96, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// N×N shimmer card grid (e.g. a future grid/hub layout).
class VSkeletonGrid extends StatelessWidget {
  /// Number of card rows.
  final int rows;

  /// Number of cards per row.
  final int columns;

  /// Outer padding of the grid.
  final EdgeInsetsGeometry padding;

  const VSkeletonGrid({
    super.key,
    this.rows = 2,
    this.columns = 2,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return VShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows; r++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: r == rows - 1 ? 0 : AppSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < columns; c++) ...[
                        if (c > 0) const SizedBox(width: AppSpacing.md),
                        const Expanded(child: _SkeletonCard()),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile-shaped skeleton: avatar circle + name/handle/body lines.
class VSkeletonProfile extends StatelessWidget {
  /// Diameter of the avatar circle (defaults to the hero size).
  final double avatarSize;

  const VSkeletonProfile({super.key, this.avatarSize = AppSpacing.avatarLarge});

  @override
  Widget build(BuildContext context) {
    return VShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AvatarBlock(size: avatarSize),
              const SizedBox(height: AppSpacing.lg),
              const VShimmerBox(width: 180, height: 20),
              const SizedBox(height: AppSpacing.sm),
              const VShimmerBox(width: 120, height: 14),
              const SizedBox(height: AppSpacing.xl),
              const VShimmerBox(width: double.infinity, height: 12),
              const SizedBox(height: AppSpacing.sm),
              const VShimmerBox(width: double.infinity, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cover + title/meta lines — the event-detail/feed-card shape.
class VSkeletonDetail extends StatelessWidget {
  /// Number of cover cards.
  final int rows;

  /// Horizontal padding (defaults to the screens' page padding).
  final EdgeInsetsGeometry padding;

  const VSkeletonDetail({
    super.key,
    this.rows = 4,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenHorizontal,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return VShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: _DetailCard(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One avatar row of [VSkeletonList] / [VSkeletonProfile]: a circular
/// `surfaceAlt` block sized like the real `ProfileAvatar` (the circle is the
/// one deliberate §5.8 shape exception — see the library doc).
class _AvatarBlock extends StatelessWidget {
  final double size;

  const _AvatarBlock({this.size = AppSpacing.avatar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// One grid card of [VSkeletonGrid]: `surface` fill + hairline border (the
/// §5.3 `VCard` geometry) with a cover block and two text lines.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.fromBorderSide(BorderSide(color: AppColors.hairline)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VShimmerBox(width: double.infinity, height: 96),
          Padding(
            padding: EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VShimmerBox(width: 120, height: 16),
                SizedBox(height: AppSpacing.sm),
                VShimmerBox(width: 80, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One feed/event-card of [VSkeletonDetail]: the §5.3 `VCard` geometry with
/// a 140px cover block (the `_EventCard` cover height) and three text lines.
class _DetailCard extends StatelessWidget {
  const _DetailCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VShimmerBox(width: double.infinity, height: 140),
          Padding(
            padding: EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VShimmerBox(width: 200, height: 18),
                SizedBox(height: AppSpacing.xs),
                VShimmerBox(width: 140, height: 13),
                SizedBox(height: AppSpacing.xs),
                VShimmerBox(width: 100, height: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
