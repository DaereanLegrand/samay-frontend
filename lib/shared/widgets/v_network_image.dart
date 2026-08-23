import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:samay/core/config/env_config.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/theme/samay_durations.dart';

/// Branded network image with disk caching, a loading placeholder, a safe
/// error fallback and a fade-in on load (findings PERF-02 / UI-02 / DEP-08 /
/// H-28). Future features should use this wrapper instead of the raw Flutter
/// network-image widget so every remote image gets caching, placeholders and
/// error states for free.
///
/// Loading placeholder uses the `surfaceAlt #111111` skeleton base and the
/// error surface uses `border #333333` (DESIGN.md §5.8) — no raw
/// greys.
class VNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final CacheManager? cacheManager;
  final Duration fadeInDuration;
  final Map<String, String>? httpHeaders;

  const VNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.cacheManager,
    this.fadeInDuration = SamayDurations.standard,
    this.httpHeaders,
  });

  /// Headers for Supabase storage image reads in this self-hosted stack: Kong
  /// enforces key-auth on every `/storage/v1/` route (`apikey` header), so a
  /// bare public URL is a 401. Returns `{'apikey': ...}` only when [apiKey] is
  /// non-empty AND [url] is a storage URL (covers public and signed-URL reads);
  /// null otherwise (non-storage hosts and keyless/test environments keep
  /// today's behavior exactly).
  static Map<String, String>? storageHeadersFor(String url, String apiKey) {
    if (apiKey.isEmpty || !url.contains('/storage/v1/')) {
      return null;
    }
    return {'apikey': apiKey};
  }

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: cacheManager,
      fadeInDuration: fadeInDuration,
      httpHeaders:
          httpHeaders ??
          VNetworkImage.storageHeadersFor(
            imageUrl,
            EnvConfig.supabaseAnonKeyRaw,
          ),
      placeholder: (_, _) => const _Surface(
        color: AppColors.surfaceAlt,
        icon: Icons.photo_outlined,
      ),
      errorWidget: (_, _, _) => const _Surface(
        color: AppColors.border,
        icon: Icons.broken_image_outlined,
      ),
    );

    final radius = borderRadius;
    if (radius == null) {
      return image;
    }
    return ClipRRect(borderRadius: radius, child: image);
  }
}

class _Surface extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _Surface({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Icon(icon, color: AppColors.muted, size: AppIconSizes.md),
      ),
    );
  }
}
