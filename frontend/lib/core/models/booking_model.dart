import '../utils/time_format.dart';

enum BookingStatus { confirmed, pending, completed, cancelled }

/// A customer's booking of a ground, shown in the Bookings tab.
class BookingModel {
  final String id;
  final String bookingRef;
  final String groundId;
  final String groundName;
  final BookingStatus status;
  final DateTime date;
  final String startTime; // "18:00:00"
  final String endTime;
  final double price;
  final String paymentMethod; // "cash", "esewa" or "khalti"
  final String? customerName; // only sent to the ground's owner
  final String? customerPhone;

  const BookingModel({
    required this.id,
    required this.bookingRef,
    required this.groundId,
    required this.groundName,
    required this.status,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'].toString(),
        bookingRef: json['booking_ref'] as String,
        groundId: json['ground'].toString(),
        groundName: json['ground_name'] as String,
        status: BookingStatus.values.byName(json['status'] as String),
        date: DateTime.parse(json['date'] as String),
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        price: double.parse(json['price'].toString()),
        paymentMethod: json['payment_method'] as String,
        customerName: json['customer_name'] as String?,
        customerPhone: json['customer_phone'] as String?,
      );

  bool get isUpcoming => status == BookingStatus.confirmed || status == BookingStatus.pending;

  bool get isPayAtGround => paymentMethod == 'cash';

  String get dateLabel => formatDateLong(date);

  String get timeLabel => formatTimeRange(startTime, endTime);

  String get paymentLabel => switch (paymentMethod) {
        'esewa' => 'eSewa',
        'khalti' => 'Khalti',
        _ => 'Cash',
      };
}
