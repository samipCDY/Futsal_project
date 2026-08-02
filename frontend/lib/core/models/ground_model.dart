/// A futsal ground as shown to a customer browsing/booking.
class GroundModel {
  final String id;
  final String name;
  final String area;
  final double distanceKm;
  final int minutesAway;
  final double rating;
  final int reviewCount;
  final double pricePerHour;
  final String imageUrl;
  final String? badgeLabel;

  const GroundModel({
    required this.id,
    required this.name,
    required this.area,
    required this.distanceKm,
    required this.minutesAway,
    required this.rating,
    required this.reviewCount,
    required this.pricePerHour,
    required this.imageUrl,
    this.badgeLabel,
  });
}
