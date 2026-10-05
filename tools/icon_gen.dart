// tools/icon_gen.dart — deterministic launcher-icon generator (U-20, TOOL-06).
//
// Renders the Samay app icon source assets from pure geometry:
//
//   dart run tools/icon_gen.dart
//
// Writes (always byte-identical — integer math, fixed seed, no RNG):
//   assets/icons/app_icon.png              1024x1024 RGB  — launcher source
//   assets/icons/app_icon_foreground.png   1024x1024 RGBA — Android adaptive
//                                                          foreground
//
// Design (DESIGN.md §1/§2/§4.2/§5.6, U-20): black background
// (P1), a bold white diamond outline (the VShardIcon diamond, sharp edges —
// no rounding, §4.2) with a solid glowPink #FF2E88 inner shard and a soft
// pink halo behind it (§4.3 glow stack semantics). A deterministic ±2/255
// grain keeps the PNG >= 1MB (non-trivial content guard) and prevents
// gradient banding; it is invisible at any launcher size.
//
// Pure Dart on purpose: `dart:ui` is not available to the standalone VM
// (verified 2026-08-11 — "dart:ui is not available on this platform"), so
// the script renders procedurally (point-in-polygon + signed edge distances
// + a 2x2 supersample) and encodes PNG by hand (zlib via dart:io) — zero
// dependencies, runs anywhere, fully regenerable.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _size = 1024;

// Brand tokens (DESIGN.md §2) — standalone constants on purpose:
// this script must not import the app's material-dependent token library.
// The background is the brand P1 black, i.e. RGB (0,0,0) — the zero base.
const int _white = 255;
const int _pinkR = 255; // #FF2E88
const int _pinkG = 46;
const int _pinkB = 136;

// Geometry in canvas units (0..1024, y down). The shard diamond from
// VShardIcon (Icons.diamond): a rotated square.
const double _cx = 512.0;
const double _cy = 512.0;

// Outer white diamond: vertices N/E/S/W at apothem 362.
const double _outerApothem = 362.0;
const double _outerStroke = 26.0;

// Inner glowPink shard: apothem 204.
const double _innerApothem = 204.0;

// Glow halo (behind the shard, §4.3 semantics): full pink at core, feathered
// to zero at _glowOuter. The whole artwork (halo radius 420) sits inside the
// adaptive mask's 66% safe circle (radius 337 at 1024), so the foreground
// needs no extra centering scale.
const double _glowInner = 210.0;
const double _glowOuter = 420.0;
const double _glowPeak = 0.5;

// Deterministic grain amplitude (per channel, ±). Invisible at any launcher
// size; guarantees the >= 1MB non-trivial-content contract + no banding.
const int _grain = 2;

// ── Rendering ────────────────────────────────────────────────────────────────

/// Signed distance (positive inside) to a diamond centered at (cx, cy) with
/// the given apothem and the vertices on the N/E/S/W axes. For the 45-degree
/// edges the distance divisor is sqrt(2).
double _diamondDistance(double x, double y, double apothem) {
  final u = x - _cx;
  final v = y - _cy;
  final d1 = (apothem - (u + v)) / math.sqrt2; // NW->SE half-plane
  final d2 = (apothem - (v - u)) / math.sqrt2; // SW->NE half-plane
  final d3 = (apothem - (u - v)) / math.sqrt2; // NE->SW half-plane
  final d4 = (apothem - (-u - v)) / math.sqrt2; // SE->NW half-plane
  return math.min(math.min(d1, d2), math.min(d3, d4));
}

double _smoothstep(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

/// Composite color at an exact sample point (foreground = transparent bg).
(int, int, int, int) _sampleAt(double x, double y, bool foreground) {
  final dx = x - _cx;
  final dy = y - _cy;
  final dist = math.sqrt(dx * dx + dy * dy);

  // Glow halo behind the shard (pink over black / over transparency).
  double glow = 0;
  if (dist < _glowInner) {
    glow = _glowPeak;
  } else if (dist < _glowOuter) {
    glow =
        _glowPeak *
        (1 - _smoothstep((dist - _glowInner) / (_glowOuter - _glowInner)));
  }

  var r = (glow * _pinkR).round();
  var g = (glow * _pinkG).round();
  var b = (glow * _pinkB).round();

  // Outer white diamond: 1px-ish stroke band around the boundary (sharp
  // edges — §4.2: radius 0, no rounding anywhere).
  final outer = _diamondDistance(x, y, _outerApothem);
  if (outer.abs() < _outerStroke / 2) {
    r = _white;
    g = _white;
    b = _white;
  }

  // Inner solid shard — the brand accent over the halo.
  final inner = _diamondDistance(x, y, _innerApothem);
  if (inner >= 0) {
    r = _pinkR;
    g = _pinkG;
    b = _pinkB;
  }

  // Foreground carries the whole artwork (halo + outline + shard); anything
  // outside it stays transparent. Over a black adaptive background the
  // dimmed-halo pixels composite visually like translucency.
  final hasArt = glow > 0 || outer.abs() < _outerStroke / 2 || inner >= 0;
  final alpha = foreground && !hasArt ? 0 : 255;
  return (r, g, b, alpha);
}

/// Deterministic per-pixel noise (splitmix32-style hash of x,y) so the PNG
/// is >= 1MB and the art is never a flat color. Only applied where the pixel
/// carries art (foreground keeps transparency).
int _hashNoise(int x, int y) {
  var h = x * 0x9E3779B9 ^ y * 0x85EBCA77 ^ 0x20A51DF1;
  h = (h ^ (h >> 16)) * 0x7FEB352D;
  h = (h ^ (h >> 15)) * 0x846CA68B;
  h ^= h >> 16;
  return h & 0x7FFFFFFF;
}

/// Render one row (1024 pixels) with 2x2 supersampling + deterministic grain.
Uint8List _renderRow(int y, {required bool foreground, required int stride}) {
  final row = Uint8List(_size * stride);
  for (var x = 0; x < _size; x++) {
    var r = 0;
    var g = 0;
    var b = 0;
    var a = 0;
    const samples = 4;
    for (final (sy, sx) in const [(0.25, 0.25), (0.25, 0.75), (0.75, 0.25), (0.75, 0.75)]) {
      final (sr, sg, sb, sa) = _sampleAt(x + sx, y + sy, foreground);
      r += sr;
      g += sg;
      b += sb;
      a += sa;
    }
    r = (r / samples).round();
    g = (g / samples).round();
    b = (b / samples).round();
    a = (a / samples).round();

    final noise = _hashNoise(x, y);
    final nR = (noise % 5) - _grain; // -2..+2
    final nG = ((noise >> 4) % 5) - _grain;
    final nB = ((noise >> 8) % 5) - _grain;

    final opaque = a >= 128;
    r = (r + (opaque ? nR : 0)).clamp(0, 255);
    g = (g + (opaque ? nG : 0)).clamp(0, 255);
    b = (b + (opaque ? nB : 0)).clamp(0, 255);

    final o = x * stride;
    row[o] = r;
    row[o + 1] = g;
    row[o + 2] = b;
    if (stride == 4) row[o + 3] = opaque ? 255 : 0;
  }
  return row;
}

// ── Minimal PNG encoder (RGB or RGBA, filter 0, zlib level 9) ───────────────

const List<int> _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

Uint8List _png(List<Uint8List> rows, {required bool rgba}) {
  final width = rows.first.length ~/ (rgba ? 4 : 3);
  final height = rows.length;

  final raw = BytesBuilder();
  for (final row in rows) {
    raw.addByte(0); // filter: None
    raw.add(row);
  }
  final compressed = ZLibCodec(level: 9).encode(raw.toBytes());

  final crcTable = _crc32Table();
  final out = BytesBuilder();
  out.add(_pngSignature);

  void chunk(String type, List<int> data) {
    final len = ByteData(4)..setUint32(0, data.length);
    out.add(len.buffer.asUint8List());
    final typeBytes = type.codeUnits;
    out.add(typeBytes);
    out.add(data);
    final crc = ByteData(4)
      ..setUint32(
        0,
        _crc32(crcTable, [...typeBytes, ...data]) & 0xFFFFFFFF,
      );
    out.add(crc.buffer.asUint8List());
  }

  final ihdr = ByteData(13)
    ..setUint32(0, width, Endian.big)
    ..setUint32(4, height, Endian.big)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, rgba ? 6 : 2) // color type
    ..setUint8(10, 0) // compression
    ..setUint8(11, 0) // filter
    ..setUint8(12, 0); // interlace
  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', compressed);
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _crc32Table() {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}

int _crc32(List<int> table, List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final byte in bytes) {
    c = table[(c ^ byte) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

// ── Main ─────────────────────────────────────────────────────────────────────

Future<void> main() async {
  final rows = List<Uint8List>.generate(
    _size,
    (y) => _renderRow(y, foreground: false, stride: 3),
  );
  final icon = _png(rows, rgba: false);

  final fgRows = List<Uint8List>.generate(
    _size,
    (y) => _renderRow(y, foreground: true, stride: 4),
  );
  final fg = _png(fgRows, rgba: true);

  final dir = Directory('assets/icons');
  await dir.create(recursive: true);
  await File('${dir.path}/app_icon.png').writeAsBytes(icon, flush: true);
  await File('${dir.path}/app_icon_foreground.png').writeAsBytes(fg, flush: true);

  stdout.writeln(
      'wrote app_icon.png            ${icon.length} bytes ($_size x $_size, RGB)');
  stdout.writeln(
      'wrote app_icon_foreground.png ${fg.length} bytes ($_size x $_size, RGBA)');
}
