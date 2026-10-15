import 'package:flutter_test/flutter_test.dart';

import 'package:futsal_app/core/utils/validators.dart';

void main() {
  test('accepts real emails from any provider', () {
    for (final email in ['csamip53@gmail.com', 'ram.thapa@yahoo.com', 'a+futsal@outlook.co.uk', ' x@y.np ']) {
      expect(emailError(email), isNull, reason: email);
    }
  });

  test('rejects broken emails', () {
    for (final email in ['', 'samip', 'samip@', '@gmail.com', 'samip.gmail.com', 'samip@gmail', 'sam ip@gmail.com',
        'samip@@gmail.com', 'samip..c@gmail.com', 'samip@gmail.c']) {
      expect(emailError(email), isNotNull, reason: email);
    }
  });

  test('mobile number must be exactly 10 digits', () {
    expect(mobileError('9744340506'), isNull);
    expect(mobileError('974 434 0506'), isNull);
    expect(mobileError(''), 'Please enter your mobile number.');
    for (final mobile in ['974434050', '97443405061', '97443405o6', '+9779744340506']) {
      expect(mobileError(mobile), 'Mobile number must be exactly 10 digits.', reason: mobile);
    }
  });
}
