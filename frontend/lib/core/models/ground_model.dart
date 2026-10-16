import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Whether an admin has checked the ground's ownership document.
enum GroundStatus { pending, approved, rejected }

/// The hourly rate depends on when a slot starts (same hours as the backend's
/// grounds/models.py): morning before 10 AM, day until 4 PM, then evening.
const dayStartsHour = 10;
const eveningStartsHour = 16;

/// A futsal ground as shown to a customer browsing/booking, or to its owner.
class GroundModel {
  final String id;
  final String name;
  final String area;
  final String address;
  final double morningPrice;
  final double dayPrice;
  final double eveningPrice;
  final String imageUrl;
  final String? badgeLabel;
  final double latitude;
  final double longitude;
  final bool isFavourite;
  final String opensAt; // "06:00:00"
  final String closesAt;
  final bool isActive;

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
    this.badgeLabel,
    required this.latitude,
    required this.longitude,
    this.isFavourite = false,
    this.opensAt = '06:00:00',
    this.closesAt = '22:00:00',
    this.isActive = true,
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
      badgeLabel: badge.isEmpty ? null : badge,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      isFavourite: json['is_favourite'] as bool? ?? false,
      opensAt: json['opens_at'] as String? ?? '06:00:00',
      closesAt: json['closes_at'] as String? ?? '22:00:00',
      isActive: json['is_active'] as bool? ?? true,
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
        badgeLabel: badgeLabel,
        latitude: latitude,
        longitude: longitude,
        isFavourite: isFavourite ?? this.isFavourite,
        opensAt: opensAt,
        closesAt: closesAt,
        isActive: isActive,
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
