import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:samay/core/config/env_config.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Branded network image with disk caching, a loading placeholder, a safe
/// error fallback and a fade-in on load. Future features should use this
/// wrapper instead of the raw Flutter
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
  /// bare public URL is a 401. Returns `{'apikey':...}` only when [apiKey] is
  /// non-empty AND [url] is a storage URL (covers public and signed-URL reads);
  /// null otherwise (non-storage hosts and keyless/test environments keep
  /// today's behavior exactly).
  static Map<String, String>? storageHeadersFor(String url, String apiKey) {
    if (apiKey.isEmpty || !url.contains('/storage/v1/')) {
      return null;
    }
    return {'apikey': apiKey};
  }

  /// Resolves a Supabase storage object URL to THIS build's configured
  /// Supabase origin.
  ///
  /// Storage URLs are persisted absolutely in the database, so a row seeded
  /// or uploaded against one host (e.g. `http://127.0.0.1:54386/...`) breaks
  /// on any client that reaches the stack through a different address (a
  /// device on the LAN, a tunnel, a simulator). Rewriting the scheme/host/port
  /// to [EnvConfig.supabaseUrlRaw] keeps the path + query (public or signed)
  /// and makes avatars host-agnostic. Non-storage URLs, and builds without a
  /// configured URL, are returned unchanged.
  static String resolveStorageUrl(String url) {
    final base = EnvConfig.supabaseUrlRaw.trim();
    if (base.isEmpty || !url.contains('/storage/v1/')) return url;
    final uri = Uri.tryParse(url);
    final baseUri = Uri.tryParse(base);
    if (uri == null || baseUri == null || baseUri.host.isEmpty) return url;
    final authority = baseUri.hasPort
        ? '${baseUri.host}:${baseUri.port}'
        : baseUri.host;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '${baseUri.scheme}://$authority${uri.path}$query';
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final resolvedUrl = resolveStorageUrl(imageUrl);
    final image = CachedNetworkImage(
      imageUrl: resolvedUrl,
      width: width,
      height: height,
      memCacheWidth: width == null ? null : (width! * dpr).round(),
      memCacheHeight: height == null ? null : (height! * dpr).round(),
      fit: fit,
      cacheManager: cacheManager,
      fadeInDuration: fadeInDuration,
      httpHeaders:
          httpHeaders ??
          VNetworkImage.storageHeadersFor(
            resolvedUrl,
            EnvConfig.supabaseAnonKeyRaw,
          ),
      placeholder: (_, _) => _Surface(
        color: context.palette.surfaceAlt,
        icon: Icons.photo_outlined,
      ),
      errorWidget: (_, _, _) => _Surface(
        color: context.palette.border,
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
        child: Icon(icon, color: context.palette.mutedForeground, size: AppIconSizes.md),
      ),
    );
  }
}
