/// "Rs 1,25,000" — Nepali grouping: last three digits, then pairs.
String formatRupees(double amount) {
  final digits = amount.round().abs().toString();
  final buffer = StringBuffer();
  final head = digits.length > 3 ? digits.substring(0, digits.length - 3) : '';
  for (var i = 0; i < head.length; i++) {
    buffer.write(head[i]);
    if ((head.length - i - 1).isEven && i < head.length - 1) buffer.write(',');
  }
  if (head.isNotEmpty) buffer.write(',');
  buffer.write(digits.length > 3 ? digits.substring(digits.length - 3) : digits);
  return 'Rs ${amount < 0 ? '-' : ''}$buffer';
}
