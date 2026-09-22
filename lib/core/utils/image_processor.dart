import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat, ImmutableBuffer, ImageDescriptor;

import 'package:image/image.dart' as img;
import 'package:samay/core/errors/app_error.dart';

/// Client-side image downscaling + JPEG re-encode for uploads (finding
///
/// Every upload stored on Supabase Storage is a **quality-80 JPEG** capped at
/// `maxLongEdge = 1920` px, produced on the client so nothing bigger ever
/// leaves the device:
///
/// - **Decode** runs through Flutter's `dart:ui` codec (decodes JPEG/PNG/
///   WebP/BMP/WBMP and HEIC where the platform supports it).
/// - **Downscale** happens on the decode (1920px long-edge cap, so a 12 MP
///   camera photo arrives well under a megabyte).
/// - **Encode** uses the pure-Dart `image` package ([img.encodeJpg]) at
///   quality 80 — `dart:ui` exposes no JPEG encoder (`ui.ImageByteFormat` has
///   only raw/PNG), which is exactly the gap this dependency fills.
///
/// Unlike the previous PNG-only pipeline, JPEG is lossy at quality 80: for
/// photos the size saving vs PNG is ~4–8× for the same pixels. The lossy pass
/// also pays off on the E2EE minigame image path, where the JPEG plaintext is
/// what gets AES-256-GCM encrypted, stored, downloaded and decrypted per
/// viewer — a smaller plaintext means a smaller ciphertext and less work on
/// the decrypt + decode path.
///
/// Transparency (PNG alpha) is composited onto white by the JPEG encoder —
/// fine for photos; a fully transparent PNG becomes a white image.
///
/// ## Threading tradeoff (verified empirically)
///
/// Decode + re-encode runs on the **main isolate**. An `Isolate.run` variant
/// fails because the dart:ui
/// engine calls (`ImmutableBuffer` / `ImageDescriptor` / codec / `toByteData`)
/// do not work inside spawned isolates on the verified platforms:
/// `flutter_tester` **and** the macOS desktop embedder on Flutter 3.44.1.
/// Main-isolate processing therefore wins:
/// correct everywhere, at the cost of a UI-thread hitch during the resize
/// (hundreds of ms for a 12 MP photo). If a platform is found where the codec
/// works in a spawned isolate, reintroduce the worker path behind the entry
/// points below — the single [_encodeJpeg] funnel makes that a local change.
class ImageProcessor {
  ImageProcessor._();

  /// Longest edge, in pixels, of any uploaded image (matches Juega's cap).
  static const int defaultMaxLongEdge = 1920;

  /// JPEG encode quality for the re-encode step (Juega's reference value).
  static const int jpegQuality = 80;

  /// Reads [bytes] and returns a **quality-80 JPEG** downscaled to at most
  /// [maxLongEdge] px on the long edge. Every upload runs through this, so the
  /// stored object is always a JPEG regardless of the source format or size.
  ///
  /// Throws a [ValidationError]-shaped error for files the codec cannot
  /// decode (corrupt data or a non-image file).
  static Future<Uint8List> compressBytes(
    Uint8List bytes, {
    int maxLongEdge = defaultMaxLongEdge,
  }) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;

      if (width <= 0 || height <= 0) {
        descriptor.dispose();
        throw ValidationError('imagen', 'Imagen no válida o archivo corrupto');
      }

      final longEdge = math.max(width, height);
      final scale = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1.0;
      final targetWidth = (width * scale).round().clamp(1, maxLongEdge);
      final targetHeight = (height * scale).round().clamp(1, maxLongEdge);

      final codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final frameImage = frame.image;
      final rgba = await frameImage.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      frameImage.dispose();
      codec.dispose();
      descriptor.dispose();

      if (rgba == null) {
        throw StateError('RGBA read returned no bytes');
      }
      return img.encodeJpg(
        img.Image.fromBytes(
          width: targetWidth,
          height: targetHeight,
          bytes: rgba.buffer,
          numChannels: 4,
        ),
        quality: jpegQuality,
      );
    } on ValidationError {
      rethrow;
    } catch (e) {
      throw ValidationError('imagen', 'Imagen no válida o archivo corrupto');
    }
  }
}
