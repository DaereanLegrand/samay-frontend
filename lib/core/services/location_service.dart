import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Vector tile endpoint used by every Samay map (event location picker,
/// discovery reference point). Vector (`.mvt`) protomaps tiles.
const String kQallariyTileUrl =
    'https://tiles.qallariy.lat/20260603/{z}/{x}/{y}.mvt';

/// A plain lat/lng pair (keeps geolocator types out of the UI layer).
class SamayLocation {
  final double latitude;
  final double longitude;

  const SamayLocation(this.latitude, this.longitude);
}

/// Device geolocation wrapper over `geolocator`.
///
/// On Android the default forces the platform LocationManager implementation
/// instead of the Fused provider: Fused runs a resolvable `checkLocationSettings`
/// before every request and pops the OS "turn on Location Accuracy" dialog each
/// time (Baseflow/flutter-geolocator#1210). Ported from the reference app.
LocationSettings mapLocationSettings({required LocationAccuracy accuracy}) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(accuracy: accuracy, forceLocationManager: true);
  }
  return LocationSettings(accuracy: accuracy);
}

class LocationService {
  const LocationService();

  /// Ensures the foreground location permission (requests once when merely
  /// denied). Returns false when denied or permanently denied.
  Future<bool> ensurePermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// The current device location, or null when the service is off, the
  /// permission is not granted, or the fix fails.
  Future<SamayLocation?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      if (!await ensurePermission()) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: mapLocationSettings(accuracy: LocationAccuracy.high),
      );
      return SamayLocation(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}
