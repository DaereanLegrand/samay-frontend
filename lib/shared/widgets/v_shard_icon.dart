import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';

/// Shard-currency diamond — DISCO-DESIGN-SYSTEM.md §5.6 (U-05).
///
/// `Icons.diamond` in `discoGold #FFC94D` by default (gold is the currency
/// color — 13.71:1 on black, far beyond the 3:1 non-text rule). Pass a
/// different [color] for the white-only mode (P2 fallback: white diamond).
/// Sizes: `xs 12` (inline in list subtitles) · `sm 16` (default) · `lg 24`
/// (balance cards).
class VShardIcon extends StatelessWidget {
  final double size;
  final Color color;

  const VShardIcon({
    super.key,
    this.size = AppIconSizes.sm,
    this.color = AppColors.currencyShards,
  });

  @override
  Widget build(BuildContext context) {
    // U-26 (1.4.1): the gold diamond is decorative in every usage — the
    // adjacent count text ("42 shards") carries the meaning. `ExcludeSemantics`
    // makes the intent explicit: never announce a redundant "shards" node.
    return ExcludeSemantics(
      child: Icon(Icons.diamond, color: color, size: size),
    );
  }
}
