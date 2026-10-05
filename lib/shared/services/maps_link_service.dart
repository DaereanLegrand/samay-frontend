import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Resolves a pasted Google Maps link or "lat,lng" pair to a point.
///
/// Coordinate parsing happens offline first; only when it fails do we follow
/// redirects (short links) with auto-redirect disabled and a bounded hop count.
/// Ported from the reference app.
class MapsLinkService {
  MapsLinkService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const int _maxHops = 5;
  static const Duration _timeout = Duration(seconds: 8);

  static final RegExp _plainPair =
      RegExp(r'^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$');
  static final RegExp _atPair =
      RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
  static final RegExp _qPair =
      RegExp(r'[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
  static final RegExp _llPair =
      RegExp(r'[?&]ll=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');

  /// Never throws — returns null for malformed input or unreachable links.
  Future<LatLng?> resolve(String input) async {
    final direct = parseCoordinates(input);
    if (direct != null) return direct;

    Uri uri;
    try {
      uri = Uri.parse(input.trim());
    } catch (_) {
      return null;
    }
    if (!uri.hasScheme) return null;

    for (var hop = 0; hop < _maxHops; hop++) {
      http.Response response;
      try {
        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers['User-Agent'] = 'Samay/1.0';
        final streamed = await _client.send(request).timeout(_timeout);
        response = await http.Response.fromStream(streamed).timeout(_timeout);
      } catch (_) {
        return null;
      }

      final fromBody = parseCoordinates(response.body);
      if (fromBody != null) return fromBody;

      final location = response.headers['location'];
      if (location == null || location.isEmpty) return null;

      Uri next;
      try {
        next = uri.resolve(location);
      } catch (_) {
        return null;
      }
      final fromLocation = parseCoordinates(next.toString());
      if (fromLocation != null) return fromLocation;

      uri = next;
    }
    return null;
  }

  @visibleForTesting
  LatLng? parseCoordinates(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final plain = _plainPair.firstMatch(text);
    if (plain != null) return _latLng(plain.group(1), plain.group(2));

    final at = _atPair.firstMatch(text);
    if (at != null) return _latLng(at.group(1), at.group(2));

    final q = _qPair.firstMatch(text);
    if (q != null) return _latLng(q.group(1), q.group(2));

    final ll = _llPair.firstMatch(text);
    if (ll != null) return _latLng(ll.group(1), ll.group(2));

    return null;
  }

  LatLng? _latLng(String? lat, String? lng) {
    final latitude = lat == null ? null : double.tryParse(lat);
    final longitude = lng == null ? null : double.tryParse(lng);
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;
    return LatLng(latitude, longitude);
  }
}
