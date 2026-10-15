import 'package:latlong2/latlong.dart';

/// A futsal ground as shown to a customer browsing/booking.
class GroundModel {
  final String id;
  final String name;
  final String area;
  final String address;
  final double pricePerHour;
  final String imageUrl;
  final String? badgeLabel;
  final double latitude;
  final double longitude;
  final bool isFavourite;

  const GroundModel({
    required this.id,
    required this.name,
    required this.area,
    required this.address,
    required this.pricePerHour,
    required this.imageUrl,
    this.badgeLabel,
    required this.latitude,
    required this.longitude,
    this.isFavourite = false,
  });

  /// From the Django API. Decimals arrive as strings (e.g. "1400.00").
  factory GroundModel.fromJson(Map<String, dynamic> json) {
    final badge = json['badge_label'] as String? ?? '';
    return GroundModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      area: json['area'] as String,
      address: json['address'] as String? ?? '',
      pricePerHour: double.parse(json['price_per_hour'].toString()),
      imageUrl: json['image_url'] as String? ?? '',
      badgeLabel: badge.isEmpty ? null : badge,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      isFavourite: json['is_favourite'] as bool? ?? false,
    );
  }

  GroundModel copyWith({bool? isFavourite}) => GroundModel(
        id: id,
        name: name,
        area: area,
        address: address,
        pricePerHour: pricePerHour,
        imageUrl: imageUrl,
        badgeLabel: badgeLabel,
        latitude: latitude,
        longitude: longitude,
        isFavourite: isFavourite ?? this.isFavourite,
      );

  LatLng get location => LatLng(latitude, longitude);
}

/// One bookable hour at a ground on a given day.
class SlotModel {
  final String startTime; // "18:00"
  final String endTime;
  final bool available;

  const SlotModel({required this.startTime, required this.endTime, required this.available});

  factory SlotModel.fromJson(Map<String, dynamic> json) => SlotModel(
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        available: json['available'] as bool,
      );
}
