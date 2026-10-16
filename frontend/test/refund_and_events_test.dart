import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_app/core/models/booking_model.dart';
import 'package:futsal_app/core/models/event_model.dart';
import 'package:futsal_app/core/models/ground_model.dart';
import 'package:futsal_app/core/utils/time_format.dart';

Map<String, dynamic> _booking({String status = 'confirmed', String? refundNow, String? refund, String by = ''}) => {
      'id': 1, 'booking_ref': 'FF-ABCDEFGH', 'ground': 2, 'ground_name': 'Arena', 'status': status,
      'date': '2026-10-20', 'start_time': '18:00:00', 'end_time': '19:00:00', 'price': '1500.00',
      'payment_method': 'cash', 'free_cancel_until': '2026-10-16T12:00:00Z',
      'refund_if_cancelled_now': refundNow, 'refund_amount': refund, 'cancelled_by': by, 'cancel_reason': '',
    };

void main() {
  test('cancelling is free only while the full price would come back', () {
    expect(BookingModel.fromJson(_booking(refundNow: '1500.00')).isFreeToCancel, isTrue);
    expect(BookingModel.fromJson(_booking(refundNow: '750.00')).isFreeToCancel, isFalse);
  });

  test('owner keeps the part of a late online cancellation that is not refunded', () {
    expect(BookingModel.fromJson(_booking()).ownerKeeps, 1500);
    final paid = {'payment_method': 'esewa', 'payment_status': 'paid'};
    final late = BookingModel.fromJson({..._booking(status: 'cancelled', refund: '750.00', by: 'customer'), ...paid});
    expect(late.ownerKeeps, 750);
    final byOwner = BookingModel.fromJson({..._booking(status: 'cancelled', refund: '1500.00', by: 'owner'), ...paid});
    expect(byOwner.ownerKeeps, 0);
    final cash = BookingModel.fromJson(_booking(status: 'cancelled', refund: '0.00', by: 'customer'));
    expect(cash.ownerKeeps, 0);
  });

  test('ground closures and events parse', () {
    final ground = GroundModel.fromJson({
      'id': 1, 'name': 'Arena', 'area': 'Patan', 'latitude': '27.67', 'longitude': '85.32',
      'morning_price': '1000.00', 'day_price': '1000.00', 'evening_price': '1500.00',
      'maintenance': [
        {'id': 3, 'starts_on': '2026-10-20', 'ends_on': '2026-10-20', 'reason': 'New turf'},
      ],
    });
    expect(ground.maintenance.single.reason, 'New turf');
    expect(ground.maintenance.single.isOneDay, isTrue);

    final event = EventModel.fromJson({
      'id': 5, 'ground': 1, 'ground_name': 'Arena', 'ground_area': 'Patan', 'title': 'Cup',
      'description': '', 'starts_at': '2026-10-25T10:00:00Z', 'ends_at': null, 'image_url': '',
      'is_published': false, 'is_expired': true, 'is_mine': true,
    });
    expect((event.isPublished, event.isExpired, event.isMine, event.endsAt), (false, true, true, null));
  });

  test('time labels', () {
    expect(formatDateTime(DateTime(2026, 10, 17, 18, 30)), 'Sat 17 Oct, 6:30 PM');
    final now = DateTime(2026, 10, 17, 12);
    expect(formatAgo(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(formatAgo(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
    expect(formatAgo(DateTime(2026, 10, 2), now: now), '2 Oct');
  });
}
