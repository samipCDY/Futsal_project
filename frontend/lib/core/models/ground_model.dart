import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Whether an admin has checked the ground's ownership document.
enum GroundStatus { pending, approved, rejected }

/// The hourly rate depends on when a slot starts (same hours as the backend's
/// grounds/models.py): morning before 10 AM, day until 4 PM, then evening.
const dayStartsHour = 10;
const eveningStartsHour = 16;

/// Most photos an owner can add to a ground (backend: grounds.models.MAX_PHOTOS).
const maxGroundPhotos = 10;

/// A futsal ground as shown to a customer browsing/booking, or to its owner.
class GroundModel {
  final String id;
  final String name;
  final String area;
  final String address;
  final double morningPrice;
  final double dayPrice;
  final double eveningPrice;
  final String imageUrl; // the cover, same as photos.first

  /// Every photo of the ground, cover first.
  final List<String> photos;
  final String? badgeLabel;
  final double latitude;
  final double longitude;
  final bool isFavourite;
  final String opensAt; // "06:00:00"
  final String closesAt;
  final bool isActive;

  /// Average stars (1-5), or null before anyone has reviewed it.
  final double? rating;
  final int reviewCount;

  // Only filled in for the ground's owner.
  final GroundStatus status;
  final String reviewNote;
  final String ownershipDocument; // path in the private ground-documents bucket

  /// Current and coming closures, soonest first.
  final List<MaintenancePeriod> maintenance;

  const GroundModel({
    required this.id,
    required this.name,
    required this.area,
    required this.address,
    required this.morningPrice,
    required this.dayPrice,
    required this.eveningPrice,
    required this.imageUrl,
    this.photos = const [],
    this.badgeLabel,
    required this.latitude,
    required this.longitude,
    this.isFavourite = false,
    this.opensAt = '06:00:00',
    this.closesAt = '22:00:00',
    this.isActive = true,
    this.rating,
    this.reviewCount = 0,
    this.status = GroundStatus.approved,
    this.reviewNote = '',
    this.ownershipDocument = '',
    this.maintenance = const [],
  });

  /// From the Django API. Decimals arrive as strings (e.g. "1400.00").
  factory GroundModel.fromJson(Map<String, dynamic> json) {
    final badge = json['badge_label'] as String? ?? '';
    return GroundModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      area: json['area'] as String,
      address: json['address'] as String? ?? '',
      morningPrice: double.parse(json['morning_price'].toString()),
      dayPrice: double.parse(json['day_price'].toString()),
      eveningPrice: double.parse(json['evening_price'].toString()),
      imageUrl: json['image_url'] as String? ?? '',
      photos: [
        for (final photo in json['photos'] as List? ?? []) photo as String,
        // Saved before galleries: just the one photo.
        if ((json['photos'] as List? ?? []).isEmpty && (json['image_url'] as String? ?? '').isNotEmpty)
          json['image_url'] as String,
      ],
      badgeLabel: badge.isEmpty ? null : badge,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      isFavourite: json['is_favourite'] as bool? ?? false,
      opensAt: json['opens_at'] as String? ?? '06:00:00',
      closesAt: json['closes_at'] as String? ?? '22:00:00',
      isActive: json['is_active'] as bool? ?? true,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
      status: GroundStatus.values.asNameMap()[json['status']] ?? GroundStatus.approved,
      reviewNote: json['review_note'] as String? ?? '',
      ownershipDocument: json['ownership_document'] as String? ?? '',
      maintenance: [
        for (final period in json['maintenance'] as List? ?? [])
          MaintenancePeriod.fromJson(period as Map<String, dynamic>),
      ],
    );
  }

  GroundModel copyWith({bool? isFavourite}) => GroundModel(
        id: id,
        name: name,
        area: area,
        address: address,
        morningPrice: morningPrice,
        dayPrice: dayPrice,
        eveningPrice: eveningPrice,
        imageUrl: imageUrl,
        photos: photos,
        badgeLabel: badgeLabel,
        latitude: latitude,
        longitude: longitude,
        isFavourite: isFavourite ?? this.isFavourite,
        opensAt: opensAt,
        closesAt: closesAt,
        isActive: isActive,
        rating: rating,
        reviewCount: reviewCount,
        status: status,
        reviewNote: reviewNote,
        ownershipDocument: ownershipDocument,
        maintenance: maintenance,
      );

  LatLng get location => LatLng(latitude, longitude);

  /// The cheapest hourly rate, for "Starting from" labels.
  double get priceFrom => math.min(morningPrice, math.min(dayPrice, eveningPrice));

  /// The most expensive rate (peak), or null when every rate is the same.
  double? get peakPrice {
    final top = math.max(morningPrice, math.max(dayPrice, eveningPrice));
    return top == priceFrom ? null : top;
  }

  /// Customers see it only when it's approved and not hidden.
  bool get isLive => isActive && status == GroundStatus.approved;

  /// The maintenance closing the ground on [day], or null.
  MaintenancePeriod? closureOn(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    for (final period in maintenance) {
      if (!date.isBefore(period.startsOn) && !date.isAfter(period.endsOn)) return period;
    }
    return null;
  }

  /// Whether it's open at [now] and when that changes, e.g.
  /// (true, 'Closes 10 PM') or (false, 'Opens 6 AM').
  /// Closed all day for maintenance gives (false, the reason).
  (bool, String) openStatus(DateTime now) {
    final closure = closureOn(now);
    if (closure != null) return (false, 'Closed for maintenance: ${closure.reason}');
    final opens = _hourOf(opensAt);
    final closes = _hourOf(closesAt);
    final hour = now.hour + now.minute / 60;
    if (hour >= opens && hour < closes) return (true, 'Closes ${_clock(closes)}');
    if (hour < opens) return (false, 'Opens ${_clock(opens)}');
    final tomorrow = now.add(const Duration(days: 1));
    return (false, closureOn(tomorrow) == null ? 'Opens ${_clock(opens)} tomorrow' : 'Closed tomorrow too');
  }

  static double _hourOf(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) + int.parse(parts[1]) / 60;
  }

  static String _clock(double hour) {
    final h = hour.floor();
    final m = ((hour - h) * 60).round();
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'} ${h < 12 ? 'AM' : 'PM'}';
  }
}

/// Days a ground is closed, e.g. to replace the turf.
class MaintenancePeriod {
  final String id;
  final DateTime startsOn;
  final DateTime endsOn; // last closed day
  final String reason;

  const MaintenancePeriod({required this.id, required this.startsOn, required this.endsOn, required this.reason});

  factory MaintenancePeriod.fromJson(Map<String, dynamic> json) => MaintenancePeriod(
        id: json['id'].toString(),
        startsOn: DateTime.parse(json['starts_on'] as String),
        endsOn: DateTime.parse(json['ends_on'] as String),
        reason: json['reason'] as String,
      );

  bool get isOneDay => startsOn == endsOn;
}

/// One day's slots at a ground, or why it's closed that day.
class DaySlots {
  final List<SlotModel> slots;
  final String? closedReason;

  const DaySlots({required this.slots, this.closedReason});
}

/// One bookable hour at a ground on a given day.
class SlotModel {
  final String startTime; // "18:00"
  final String endTime;
  final bool available;
  final double price;

  const SlotModel({required this.startTime, required this.endTime, required this.available, required this.price});

  factory SlotModel.fromJson(Map<String, dynamic> json) => SlotModel(
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        available: json['available'] as bool,
        price: double.parse(json['price'].toString()),
      );
}
