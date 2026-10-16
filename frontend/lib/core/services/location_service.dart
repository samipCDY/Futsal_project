import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  /// Central Kathmandu, used before (or instead of) the device's location.
  static const fallback = LatLng(27.7172, 85.3240);

  /// The device's current position, or null when location is switched off or
  /// the user said no. Asks for permission the first time.
  static Future<LatLng?> current() async {
    if (!await _allowed()) return null;
    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  /// The device's position as it moves (every ~20 m), for the live blue dot.
  /// Empty when location is off or not allowed.
  static Stream<LatLng> watch() async* {
    if (!await _allowed()) return;
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }

  static Future<bool> _allowed() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied && permission != LocationPermission.deniedForever;
  }

  /// The town and district at [point], e.g. "Bharatpur, Chitwan", using
  /// the phone's own address lookup (free, no key). Null when there's no
  /// internet or no answer.
  static Future<String?> placeName(LatLng point) async {
    try {
      final places = await geo.Geocoding().placemarkFromCoordinates(point.latitude, point.longitude);
      if (places.isEmpty) return null;
      final place = places.first;
      String? clean(String? value) {
        final text = (value ?? '').replaceAll(RegExp(r'\s+(District|Municipality|Metropolitan City)$'), '').trim();
        return text.isEmpty ? null : text;
      }

      final town = clean(place.subLocality) ?? clean(place.locality) ?? clean(place.name);
      final region = clean(place.subAdministrativeArea) ?? clean(place.locality) ?? clean(place.administrativeArea);
      final parts = <String>[
        if (town != null) town,
        if (region != null && region != town) region,
      ];
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      // No network, no geocoder on this phone, or not supported (web).
      return null;
    }
  }

  static double kmBetween(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude) / 1000;
}
