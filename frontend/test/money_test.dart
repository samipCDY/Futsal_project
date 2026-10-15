import 'package:flutter_test/flutter_test.dart';

import 'package:futsal_app/core/utils/money.dart';

void main() {
  test('formats rupees with Nepali digit grouping', () {
    expect(formatRupees(0), 'Rs 0');
    expect(formatRupees(950), 'Rs 950');
    expect(formatRupees(1400), 'Rs 1,400');
    expect(formatRupees(42000), 'Rs 42,000');
    expect(formatRupees(125000), 'Rs 1,25,000');
    expect(formatRupees(12345678), 'Rs 1,23,45,678');
    expect(formatRupees(1499.6), 'Rs 1,500');
  });
}
