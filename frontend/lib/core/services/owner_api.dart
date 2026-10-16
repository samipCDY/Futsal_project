import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/event_model.dart';
import '../models/ground_model.dart';
import '../utils/time_format.dart';
import 'api_client.dart';

/// The ground owner's side of the Django API.
class OwnerApi {
  /// Bumped whenever an owner adds or edits a ground, so the Dashboard and
  /// Grounds tab reload.
  static final groundsChanged = ValueNotifier<int>(0);

  static Future<OwnerSummary> fetchSummary() async =>
      OwnerSummary.fromJson(await ApiClient.get('/owner/summary/') as Map<String, dynamic>);

  static Future<List<GroundModel>> fetchMyGrounds() async {
    final data = await ApiClient.get('/owner/grounds/') as List;
    return data.map((json) => GroundModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// [details] uses the API's field names, e.g. {'name': ..., 'day_price': ...}.
  static Future<GroundModel> saveGround(Map<String, dynamic> details, {String? groundId}) async {
    final data = groundId == null
        ? await ApiClient.post('/owner/grounds/', details)
        : await ApiClient.patch('/owner/grounds/$groundId/', details);
    groundsChanged.value++;
    return GroundModel.fromJson(data as Map<String, dynamic>);
  }

  /// Closes a ground from [first] to [last] (inclusive). Everyone booked on
  /// those days is cancelled with a full refund. Returns how many.
  static Future<int> closeGround(String groundId, DateTime first, DateTime last, String reason) async {
    final data = await ApiClient.post('/owner/grounds/$groundId/maintenance/', {
      'starts_on': formatDateApi(first),
      'ends_on': formatDateApi(last),
      'reason': reason,
    }) as Map<String, dynamic>;
    groundsChanged.value++;
    return data['cancelled_bookings'] as int;
  }

  /// Ends a closure early. Bookings cancelled for it stay cancelled.
  static Future<void> reopenGround(String maintenanceId) async {
    await ApiClient.delete('/owner/maintenance/$maintenanceId/');
    groundsChanged.value++;
  }

  /// Bumped whenever the owner adds, edits, publishes or deletes an event.
  static final eventsChanged = ValueNotifier<int>(0);

  /// The owner's own events, drafts included.
  static Future<List<EventModel>> fetchMyEvents() async {
    final data = await ApiClient.get('/owner/events/') as List;
    return data.map((json) => EventModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// [details] uses the API's field names, e.g. {'title': ..., 'starts_at': ...}.
  static Future<EventModel> saveEvent(Map<String, dynamic> details, {String? eventId}) async {
    final data = eventId == null
        ? await ApiClient.post('/owner/events/', details)
        : await ApiClient.patch('/owner/events/$eventId/', details);
    eventsChanged.value++;
    return EventModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteEvent(String eventId) async {
    await ApiClient.delete('/owner/events/$eventId/');
    eventsChanged.value++;
  }

  /// Bookings at the owner's grounds on [day], optionally at one ground only.
  static Future<List<BookingModel>> fetchBookings(DateTime day, {String? groundId}) async {
    final data = await ApiClient.get('/bookings/', query: {
      'date': formatDateApi(day),
      if (groundId != null) 'ground': groundId,
    }) as List;
    final bookings = data.map((json) => BookingModel.fromJson(json as Map<String, dynamic>)).toList();
    return bookings..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}

class OwnerSummary {
  final int todayBookings;
  final int weekBookings;
  final double weekEarnings;
  final int activeGrounds;
  final int totalGrounds;
  final int pendingGrounds;
  final int rejectedGrounds;
  final List<BookingModel> upcoming;

  const OwnerSummary({
    required this.todayBookings,
    required this.weekBookings,
    required this.weekEarnings,
    required this.activeGrounds,
    required this.totalGrounds,
    required this.pendingGrounds,
    required this.rejectedGrounds,
    required this.upcoming,
  });

  factory OwnerSummary.fromJson(Map<String, dynamic> json) => OwnerSummary(
        todayBookings: json['today_bookings'] as int,
        weekBookings: json['week_bookings'] as int,
        weekEarnings: double.parse(json['week_earnings'] as String),
        activeGrounds: json['active_grounds'] as int,
        totalGrounds: json['total_grounds'] as int,
        pendingGrounds: json['pending_grounds'] as int? ?? 0,
        rejectedGrounds: json['rejected_grounds'] as int? ?? 0,
        upcoming: (json['upcoming'] as List)
            .map((booking) => BookingModel.fromJson(booking as Map<String, dynamic>))
            .toList(),
      );
}
