import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/event_model.dart';
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

  static Future<DaySlots> fetchSlots(String groundId, DateTime day) async {
    final data = await ApiClient.get('/grounds/$groundId/slots/', query: {'date': formatDateApi(day)});
    return DaySlots(
      slots: (data['slots'] as List).map((json) => SlotModel.fromJson(json as Map<String, dynamic>)).toList(),
      closedReason: data['closed_reason'] as String?,
    );
  }

  /// Throws an ApiException with statusCode 409 if someone else just took
  /// the slot. For eSewa/Khalti, also returns how to open the payment page;
  /// the slot is held until paid (15 minutes).
  static Future<(BookingModel, PaymentStart?)> createBooking({
    required String groundId,
    required DateTime day,
    required String startTime,
    String paymentMethod = 'cash',
  }) async {
    final data = await ApiClient.post('/bookings/', {
      'ground': int.parse(groundId),
      'date': formatDateApi(day),
      'start_time': startTime,
      'payment_method': paymentMethod,
    }) as Map<String, dynamic>;
    bookingsChanged.value++;
    final payment = data['payment'];
    return (BookingModel.fromJson(data), payment == null ? null : PaymentStart.fromJson(payment as Map<String, dynamic>));
  }

  /// Which ways to pay are offered, e.g. {'cash', 'esewa'}.
  static Future<Set<String>> fetchPaymentMethods() async {
    final data = await ApiClient.get('/payments/methods/') as Map<String, dynamic>;
    return {for (final entry in data.entries) if (entry.value == true) entry.key};
  }

  /// A new payment attempt for a booking still waiting for payment.
  static Future<PaymentStart> payBooking(String bookingId) async {
    final data = await ApiClient.post('/bookings/$bookingId/pay/') as Map<String, dynamic>;
    return PaymentStart.fromJson(data['payment'] as Map<String, dynamic>);
  }

  /// Asks the server to check with eSewa/Khalti. Throws an ApiException if
  /// the payment wasn't completed.
  static Future<BookingModel> verifyPayment(String bookingId) async {
    final data = await ApiClient.post('/bookings/$bookingId/verify-payment/');
    bookingsChanged.value++;
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<BookingModel>> fetchMyBookings() async {
    final data = await ApiClient.get('/bookings/') as List;
    return data.map((json) => BookingModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Returns the cancelled booking, with how much is refunded. [reason] is
  /// only used when the ground's owner cancels; the customer sees it.
  static Future<BookingModel> cancelBooking(String bookingId, {String? reason}) async {
    final data = await ApiClient.post('/bookings/$bookingId/cancel/', {if (reason != null) 'reason': reason});
    bookingsChanged.value++;
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  /// Published events: coming ones first, then recently ended ones.
  static Future<List<EventModel>> fetchEvents({String? groundId}) async {
    final data = await ApiClient.get('/events/', query: {if (groundId != null) 'ground': groundId}) as List;
    return data.map((json) => EventModel.fromJson(json as Map<String, dynamic>)).toList();
  }
}

/// How to open eSewa's or Khalti's payment page for one attempt.
class PaymentStart {
  final String gateway; // "esewa" or "khalti"
  final String formUrl; // eSewa: POST [fields] here
  final Map<String, String> fields;
  final String paymentUrl; // Khalti: open this page
  /// The gateway sends the customer back to an address starting with this.
  final String returnUrlPrefix;

  const PaymentStart({
    required this.gateway,
    this.formUrl = '',
    this.fields = const {},
    this.paymentUrl = '',
    required this.returnUrlPrefix,
  });

  factory PaymentStart.fromJson(Map<String, dynamic> json) => PaymentStart(
        gateway: json['gateway'] as String,
        formUrl: json['form_url'] as String? ?? '',
        fields: {for (final entry in (json['fields'] as Map? ?? {}).entries) '${entry.key}': '${entry.value}'},
        paymentUrl: json['payment_url'] as String? ?? '',
        returnUrlPrefix: json['return_url_prefix'] as String,
      );
}
