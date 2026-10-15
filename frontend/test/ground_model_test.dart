import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_app/core/models/ground_model.dart';

Map<String, dynamic> _json({String morning = '1000.00', String day = '1200.00', String evening = '1500.00',
        String? status}) =>
    {
      'id': 1, 'name': 'Arena', 'area': 'Patan', 'latitude': '27.67', 'longitude': '85.32',
      'morning_price': morning, 'day_price': day, 'evening_price': evening,
      if (status != null) 'status': status,
    };

void main() {
  test('cheapest rate is "from", highest is the peak', () {
    final ground = GroundModel.fromJson(_json());
    expect(ground.priceFrom, 1000);
    expect(ground.peakPrice, 1500);
    expect(GroundModel.fromJson(_json(morning: '900.00', day: '900.00', evening: '900.00')).peakPrice, isNull);
  });

  test('only approved, shown grounds are live', () {
    expect(GroundModel.fromJson(_json()).isLive, isTrue); // customer API sends no status
    expect(GroundModel.fromJson(_json(status: 'pending')).isLive, isFalse);
    expect(GroundModel.fromJson(_json(status: 'rejected')).status, GroundStatus.rejected);
  });
}
