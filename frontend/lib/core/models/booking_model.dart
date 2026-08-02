enum BookingStatus { confirmed, pending, completed }

/// A customer's booking of a ground, shown in the Bookings tab.
class BookingModel {
  final String id;
  final String bookingRef;
  final String groundName;
  final BookingStatus status;
  final String dateLabel;
  final String timeLabel;
  final double price;
  final String? paymentMethod;
  final int? rating;

  const BookingModel({
    required this.id,
    required this.bookingRef,
    required this.groundName,
    required this.status,
    required this.dateLabel,
    required this.timeLabel,
    required this.price,
    this.paymentMethod,
    this.rating,
  });
}
