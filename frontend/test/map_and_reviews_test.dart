import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_app/core/models/ground_model.dart';
import 'package:futsal_app/core/models/review_model.dart';

GroundModel _ground({List<MaintenancePeriod> maintenance = const []}) => GroundModel(
      id: '1',
      name: 'Arena',
      area: 'Patan',
      address: '',
      morningPrice: 1000,
      dayPrice: 1200,
      eveningPrice: 1500,
      imageUrl: '',
      latitude: 27.67,
      longitude: 85.32,
      opensAt: '06:00:00',
      closesAt: '22:00:00',
      maintenance: maintenance,
    );

void main() {
  test('open status follows opening hours', () {
    final ground = _ground();
    expect(ground.openStatus(DateTime(2026, 10, 16, 18)), (true, 'Closes 10 PM'));
    expect(ground.openStatus(DateTime(2026, 10, 16, 5)), (false, 'Opens 6 AM'));
    expect(ground.openStatus(DateTime(2026, 10, 16, 23)), (false, 'Opens 6 AM tomorrow'));
  });

  test('maintenance closes the ground all day with the reason', () {
    final ground = _ground(maintenance: [
      MaintenancePeriod(id: '1', startsOn: DateTime(2026, 10, 16), endsOn: DateTime(2026, 10, 17), reason: 'New turf'),
    ]);
    expect(ground.closureOn(DateTime(2026, 10, 17, 9))?.reason, 'New turf');
    expect(ground.closureOn(DateTime(2026, 10, 18)), isNull);
    expect(ground.openStatus(DateTime(2026, 10, 16, 18)), (false, 'Closed for maintenance: New turf'));
    expect(ground.openStatus(DateTime(2026, 10, 15, 23)).$2, 'Closed tomorrow too');
  });

  test('ratings and reviews are read from the API', () {
    final ground = GroundModel.fromJson({
      'id': 1, 'name': 'Arena', 'area': 'Patan', 'latitude': '27.67', 'longitude': '85.32',
      'morning_price': '1000.00', 'day_price': '1000.00', 'evening_price': '1000.00',
      'rating': 4.5, 'review_count': 2,
    });
    expect((ground.rating, ground.reviewCount), (4.5, 2));

    final reviews = GroundReviews.fromJson({
      'rating': 4.5,
      'review_count': 2,
      'stars': {'5': 1, '4': 1, '3': 0, '2': 0, '1': 0},
      'my_review': null,
      'can_review': true,
      'reviews': [
        {'id': 7, 'rating': 5, 'comment': 'Great', 'customer_name': 'Hari Bahadur', 'customer_photo': '',
         'created_at': '2026-10-16T10:00:00Z', 'updated_at': '2026-10-16T10:00:00Z'},
      ],
    });
    expect(reviews.stars[5], 1);
    expect(reviews.canReview, isTrue);
    expect(reviews.reviews.single.initials, 'HB');
  });
}
