import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';

/// Shared compact action tile for the Social sub-tab entry rows
/// (D-social-density, 2026-08-18): a white-only hairline tile used by BOTH
/// the Grupos tab (Crear grupo / Ranking) and the Amigos tab (Solicitudes /
/// Ranking), so the entry rows look identical everywhere. Height 40, radius
/// 10, hairline white border; the optional [badge] rides the tile corner
/// through the neutral `VCountBadge`.
class SocialActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badge;
  final VoidCallback onTap;

  const SocialActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  right: 2,
                  top: -6,
                  child: VCountBadge(count: badge!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared row of [SocialActionTile]s for both Social sub-tabs: two Expanded
/// tiles with an 8px gap, wrapped in the 12px page padding. The Grupos and
/// Amigos entry rows are byte-identical through this widget.
class SocialActionsRow extends StatelessWidget {
  final List<Widget> children;

  const SocialActionsRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}
