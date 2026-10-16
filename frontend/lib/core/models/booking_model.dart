import '../utils/time_format.dart';

enum BookingStatus { confirmed, pending, completed, cancelled }

/// A customer's booking of a ground, shown in the Bookings tab.
class BookingModel {
  final String id;
  final String bookingRef;
  final String groundId;
  final String groundName;
  final double? groundLatitude;
  final double? groundLongitude;
  final BookingStatus status;
  final DateTime date;
  final String startTime; // "18:00:00"
  final String endTime;
  final double price;
  final String paymentMethod; // "cash", "esewa" or "khalti"
  final String? customerName; // only sent to the ground's owner
  final String? customerPhone;

  /// Cancelling before this gives the full price back; after it, half.
  final DateTime? freeCancelUntil;

  /// What cancelling now would give back; null once it can't be cancelled.
  final double? refundIfCancelledNow;
  final String cancelledBy; // "customer", "owner" or "" when not cancelled
  final String cancelReason;
  final double? refundAmount;
  final String paymentStatus; // "paid" once paid online, else "unpaid"
  final DateTime? paymentDueBy; // an unpaid eSewa/Khalti booking is released after this
  final String paymentTxnId;
  final String refundStatus; // "pending" = being sent back, "done" = sent, "" = none

  const BookingModel({
    required this.id,
    required this.bookingRef,
    required this.groundId,
    required this.groundName,
    this.groundLatitude,
    this.groundLongitude,
    required this.status,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
    this.freeCancelUntil,
    this.refundIfCancelledNow,
    this.cancelledBy = '',
    this.cancelReason = '',
    this.refundAmount,
    this.paymentStatus = 'unpaid',
    this.paymentDueBy,
    this.paymentTxnId = '',
    this.refundStatus = '',
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'].toString(),
        bookingRef: json['booking_ref'] as String,
        groundId: json['ground'].toString(),
        groundName: json['ground_name'] as String,
        groundLatitude: double.tryParse('${json['ground_latitude']}'),
        groundLongitude: double.tryParse('${json['ground_longitude']}'),
        status: BookingStatus.values.byName(json['status'] as String),
        date: DateTime.parse(json['date'] as String),
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        price: double.parse(json['price'].toString()),
        paymentMethod: json['payment_method'] as String,
        customerName: json['customer_name'] as String?,
        customerPhone: json['customer_phone'] as String?,
        freeCancelUntil: _parseTime(json['free_cancel_until']),
        refundIfCancelledNow: _parseMoney(json['refund_if_cancelled_now']),
        cancelledBy: json['cancelled_by'] as String? ?? '',
        cancelReason: json['cancel_reason'] as String? ?? '',
        refundAmount: _parseMoney(json['refund_amount']),
        paymentStatus: json['payment_status'] as String? ?? 'unpaid',
        paymentDueBy: _parseTime(json['payment_due_by']),
        paymentTxnId: json['payment_txn_id'] as String? ?? '',
        refundStatus: json['refund_status'] as String? ?? '',
      );

  static DateTime? _parseTime(Object? value) => value == null ? null : DateTime.parse(value as String).toLocal();

  static double? _parseMoney(Object? value) => value == null ? null : double.parse(value.toString());

  /// Whether cancelling now still refunds the full price.
  bool get isFreeToCancel => refundIfCancelledNow != null && refundIfCancelledNow == price;

  /// What the ground's owner earns from this booking.
  /// A cancelled booking only earns the part of an online payment that
  /// wasn't refunded; an unpaid (cash) one earns nothing.
  double get ownerKeeps {
    if (status != BookingStatus.cancelled) return price;
    if (!isPaid) return 0;
    return price - (refundAmount ?? price);
  }

  bool get isUpcoming => status == BookingStatus.confirmed || status == BookingStatus.pending;

  bool get isPayAtGround => paymentMethod == 'cash';

  bool get isPaid => paymentStatus == 'paid';

  /// An eSewa/Khalti booking holding its slot until it's paid.
  bool get isAwaitingPayment => !isPayAtGround && !isPaid && status == BookingStatus.pending;

  String get dateLabel => formatDateLong(date);

  String get timeLabel => formatTimeRange(startTime, endTime);

  String get paymentLabel => switch (paymentMethod) {
        'esewa' => 'eSewa',
        'khalti' => 'Khalti',
        _ => 'Cash',
      };
}
