import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  /// Central Kathmandu, used before (or instead of) the device's location.
  static const fallback = LatLng(27.7172, 85.3240);

  static const _distance = Distance();

  /// The device's current position, or null when location is switched off or
  /// the user said no. Asks for permission the first time.
  static Future<LatLng?> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  static double kmBetween(LatLng a, LatLng b) => _distance.as(LengthUnit.Kilometer, a, b);
}
