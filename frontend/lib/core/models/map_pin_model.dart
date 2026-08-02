import 'dart:ui';

/// A ground's marker position on the (placeholder, for now) map.
/// [position] is fractional (0..1 of the map viewport) so it's independent
/// of screen size — this is the piece that gets replaced by a real
/// lat/lng + google_maps_flutter Marker once the Google Maps API key is in.
class MapPinModel {
  final String groundId;
  final Offset position;
  final bool showPriceTag;

  const MapPinModel({
    required this.groundId,
    required this.position,
    this.showPriceTag = false,
  });
}
