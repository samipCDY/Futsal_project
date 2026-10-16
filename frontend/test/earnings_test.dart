import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_app/core/services/owner_api.dart';

EarningsChart _chart(String total, String previous) => EarningsChart.fromJson({
      'period': 'month',
      'bars': [
        {'start': '2026-09-01', 'earnings': '1000.00', 'games': 1},
        {'start': '2026-10-01', 'earnings': '2000.00', 'games': 2},
      ],
      'total': total,
      'previous_total': previous,
    });

void main() {
  test('earnings parse in order', () {
    final chart = _chart('3000.00', '2000.00');
    expect(chart.bars.map((b) => (b.start.month, b.earnings, b.games)), [(9, 1000.0, 1), (10, 2000.0, 2)]);
  });

  test('change against the previous periods', () {
    expect(_chart('3000.00', '2000.00').changePercent, 50);
    expect(_chart('1000.00', '2000.00').changePercent, -50);
    expect(_chart('1000.00', '0.00').changePercent, isNull); // nothing to compare with
  });
}
