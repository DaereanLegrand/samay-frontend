import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// Profile-header avatar — DESIGN.md §2.1/§4.2 (U-09).
///
/// The §5 profile-avatar treatment: circular, `surfaceAlt #111111` fill with
/// white initials (the doc's "initials white on surfaceAlt" handoff), and a
/// 1px `border #333333` ring — the §2.1 *avatar-ring* token (1.66:1, the
/// outline role; the initials carry the 21:1 text contrast, so the ring is
/// never the only signal — §7.2). Circles are the one non-sharp geometry the
/// doc allows (§4.2 exceptions: avatars are circles). The 1px inset keeps
/// the image/initials clear of the ring. When [imageUrl] is set, the photo
/// renders through `VNetworkImage` (§5.8 surfaces).
class ProfileAvatar extends StatelessWidget {
  /// Circle diameter. The profile header and the edit screen both use 96
  /// (radius 48 → diameter 96).
  final double size;

  /// Two-letter fallback when no photo exists.
  final String? initials;

  /// Remote avatar photo; when null the initials render.
  final String? imageUrl;

  const ProfileAvatar({
    super.key,
    this.size = 96,
    this.initials,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(1),
      child: ClipOval(
        child: SizedBox.expand(
          child: imageUrl == null
              ? Center(
                  child: Text(
                    initials ?? '',
                    style: TextStyle(
                      // Initials scale with the diameter (U-10): the
                      // profile-header 96px avatar keeps 24px; list-tile
                      // 40px avatars render 10px.
                      fontSize: size * 0.25,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : VNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
