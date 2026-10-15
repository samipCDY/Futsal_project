import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/ground_model.dart';
import '../utils/time_format.dart';
import 'api_client.dart';

/// Grounds and bookings from the Django API.
class FutsalApi {
  /// Bumped whenever a booking is made or cancelled, so screens showing
  /// bookings know to reload.
  static final bookingsChanged = ValueNotifier<int>(0);

  static Future<List<GroundModel>> fetchGrounds() async {
    final data = await ApiClient.get('/grounds/') as List;
    return data.map((json) => GroundModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Bumped whenever a ground is saved or un-saved.
  static final favouritesChanged = ValueNotifier<int>(0);

  static Future<List<GroundModel>> fetchFavourites() async {
    final data = await ApiClient.get('/grounds/favourites/') as List;
    return data.map((json) => GroundModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  static Future<void> setFavourite(String groundId, bool favourite) async {
    final path = '/grounds/$groundId/favourite/';
    await (favourite ? ApiClient.post(path) : ApiClient.delete(path));
    favouritesChanged.value++;
  }

  static Future<List<SlotModel>> fetchSlots(String groundId, DateTime day) async {
    final data = await ApiClient.get('/grounds/$groundId/slots/', query: {'date': formatDateApi(day)});
    return (data['slots'] as List).map((json) => SlotModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Throws an ApiException with statusCode 409 if someone else just took
  /// the slot.
  static Future<BookingModel> createBooking({
    required String groundId,
    required DateTime day,
    required String startTime,
  }) async {
    final data = await ApiClient.post('/bookings/', {
      'ground': int.parse(groundId),
      'date': formatDateApi(day),
      'start_time': startTime,
      'payment_method': 'cash',
    });
    bookingsChanged.value++;
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<BookingModel>> fetchMyBookings() async {
    final data = await ApiClient.get('/bookings/') as List;
    return data.map((json) => BookingModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  static Future<void> cancelBooking(String bookingId) async {
    await ApiClient.post('/bookings/$bookingId/cancel/');
    bookingsChanged.value++;
  }
}
