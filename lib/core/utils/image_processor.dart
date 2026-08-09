import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show ImmutableBuffer, ImageByteFormat, ImageDescriptor;
import 'dart:io';

import 'package:samay/core/errors/app_error.dart';

/// Client-side image downscaling for uploads (finding PERF-03 / M-36).
///
/// Flutter's `dart:ui` codec decodes JPEG/PNG/WebP/BMP/WBMP (and HEIC where
/// the platform supports it) but can only re-encode to **PNG**
/// (`ui.ImageByteFormat` exposes no JPEG encoder — verified against the
/// Flutter 3.44.1 `dart:ui` source and API docs). The main win PERF-03 asks
/// for is the *resolution* cap, so [compress] re-encodes as a PNG at
/// `maxLongEdge = 1920` px: a 12 MP camera JPEG (5–15 MB) becomes a 1920px
/// PNG well under a megabyte for typical photos.
///
/// ## JPEG limitation (documented)
///
/// Juega's equivalent reaches ~90% bandwidth savings because it encodes JPEG
/// at quality 80 via the `image` package. Samay has no JPEG encoder on the
/// client without adding that dependency (out of scope for I-22 — the `image`
/// package is not in `pubspec.yaml`). PNG is lossless, so the output is
/// larger than an 80%-JPEG of the same pixels, but still dramatically smaller
/// than the full-resolution original. If JPEG quality compression is wanted,
/// add the `image` package (or a native codec) in a follow-up and swap the
/// re-encode step — everything else stays.
///
/// ## Threading tradeoff (verified empirically)
///
/// Decode + re-encode runs on the **main isolate**. An `Isolate.run` variant
/// was built and tested first (Juega's reference pattern), but the dart:ui
/// engine calls (`ImmutableBuffer` / `ImageDescriptor` / codec / `toByteData`)
/// fail inside spawned isolates in every environment verified — `flutter_tester`
/// **and** the macOS desktop embedder on Flutter 3.44.1 (see the I-22 daily
/// log, "isolate probe" section). Main-isolate processing therefore wins:
/// correct everywhere, at the cost of a UI-thread hitch during the resize
/// (hundreds of ms for a 12 MP photo). If a platform is found where the codec
/// works in a spawned isolate, reintroduce the worker path behind [compress]
/// — the single [_process] entry point makes that a local change.
class ImageProcessor {
  ImageProcessor._();

  /// Longest edge, in pixels, of any uploaded image (matches Juega's cap).
  static const int defaultMaxLongEdge = 1920;

  /// Files at or above this many bytes are worth full processing; anything
  /// below skips decode/re-encode entirely — only a cheap header validation
  /// runs, so small valid uploads never pay the cost and small junk still
  /// fails fast.
  static const int skipThresholdBytes = 512 * 1024;

  /// Whether [image]'s file size justifies processing — the size check
  /// callers use before scheduling an upload.
  static bool shouldResize(File image, {int minBytes = skipThresholdBytes}) {
    if (!image.existsSync()) return false;
    return image.lengthSync() >= minBytes;
  }

  /// Reads [image] and returns bytes ready for upload: downscaled to at most
  /// [maxLongEdge] px on the long edge (PNG) when the file is large enough to
  /// matter, or the original bytes unchanged when processing is unnecessary.
  ///
  /// Throws a [ValidationError]-shaped error for files the codec cannot
  /// decode (corrupt data or a non-image file).
  static Future<Uint8List> compress(
    File image, {
    int maxLongEdge = defaultMaxLongEdge,
  }) async {
    final bytes = await image.readAsBytes();
    return compressBytes(bytes, maxLongEdge: maxLongEdge);
  }

  /// Bytes-based variant of [compress] for callers that already hold the
  /// payload (e.g. [MediaService]).
  static Future<Uint8List> compressBytes(
    Uint8List bytes, {
    int maxLongEdge = defaultMaxLongEdge,
  }) async {
    if (bytes.length < skipThresholdBytes) {
      // Below the threshold: cheap header-only validation, then pass the
      // original through untouched.
      await _validateHeader(bytes);
      return bytes;
    }
    return _process(bytes, maxLongEdge);
  }

  static Future<void> _validateHeader(Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final ok = descriptor.width > 0 && descriptor.height > 0;
      descriptor.dispose();
      if (!ok) {
        throw ValidationError('imagen', 'Imagen no válida o archivo corrupto');
      }
    } on ValidationError {
      rethrow;
    } catch (_) {
      throw ValidationError('imagen', 'Imagen no válida o archivo corrupto');
    }
  }

  static Future<Uint8List> _process(Uint8List bytes, int maxLongEdge) async {
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
      if (longEdge <= maxLongEdge) {
        // Dimensions already within the cap — pass the original through.
        descriptor.dispose();
        return bytes;
      }

      final scale = maxLongEdge / longEdge;
      final targetWidth =
          (width * scale).round().clamp(1, maxLongEdge).toInt();
      final targetHeight =
          (height * scale).round().clamp(1, maxLongEdge).toInt();

      final codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();

      if (data == null) {
        throw StateError('PNG encode returned no bytes');
      }
      final processed = data.buffer.asUint8List();
      // Safety: never *grow* a payload — return the original when the
      // re-encode did not shrink it.
      return processed.length < bytes.length ? processed : bytes;
    } on ValidationError {
      rethrow;
    } catch (e) {
      throw ValidationError('imagen', 'Imagen no válida o archivo corrupto');
    }
  }
}
